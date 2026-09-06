--[[
    BuffDaddy_Check.lua

    The actual buff-checking logic. Reads BuffDaddy_Definitions, walks the
    roster from BuffDaddy_Roster, and produces a "results" table that
    BuffDaddy_Output.lua turns into the window text / raid chat / whispers.

    Depends on: BuffDaddy.lua, BuffDaddy_Definitions.lua, BuffDaddy_Roster.lua

    *** NEEDS IN-GAME VERIFICATION ***
    BuffDaddy.Check.GetUnitAuraList() below assumes ClassicAPI's
    C_UnitAuras.GetUnitAuras(unit, "HELPFUL") returns an array of tables
    shaped like:
        { name = "...", duration = 123, expirationTime = 456, index = 1 }
    This matches how similar modern Blizzard APIs are shaped, but
    ClassicAPI's exact return format hasn't been confirmed in-game yet.
    If buffs aren't being detected, THIS is the first place to check -
    see the "Known risk areas" section in README.md.
]]

-- Maps appliesTo = "selfX" definitions to the class token they mean.
local SELF_CLASS_MAP = {
    selfMage = "MAGE",
    selfHunter = "HUNTER",
    selfWarlock = "WARLOCK",
    selfPriest = "PRIEST",
    selfShaman = "SHAMAN",
}

-- Returns true if auraName exactly matches one of the names in nameList.
local function NameMatches(auraName, nameList)
    if not auraName then return false end
    for i = 1, table.getn(nameList) do
        if auraName == nameList[i] then
            return true
        end
    end
    return false
end

-- Reads the tooltip text of a specific aura and checks whether requiredText
-- appears in it. Whitespace (double spaces, stray newlines, etc.) is
-- collapsed first so formatting quirks don't break the match.
function BuffDaddy.Check.AuraTooltipContains(unit, auraIndex, requiredText)
    BuffDaddy.ScanTooltip:ClearLines()
    BuffDaddy.ScanTooltip:SetUnitAura(unit, auraIndex, "HELPFUL")

    local combined = ""
    for i = 1, 12 do
        local line = getglobal("BuffDaddyScanTooltipTextLeft" .. i)
        if line then
            local text = line:GetText()
            if text then
                combined = combined .. " " .. text
            end
        end
    end

    combined = string.gsub(combined, "%s+", " ")
    combined = string.gsub(combined, "^%s+", "")
    combined = string.gsub(combined, "%s+$", "")

    return string.find(combined, requiredText, 1, true) ~= nil
end

-- Returns an array of helpful (buff) auras on a unit.
-- Each entry: { name, duration, expirationTime, index }
function BuffDaddy.Check.GetUnitAuraList(unit)
    local auras = {}
    if not UnitExists(unit) then return auras end

    local ok, data = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL")
    if ok and type(data) == "table" then
        for i = 1, table.getn(data) do
            local aura = data[i]
            if aura and aura.name then
                table.insert(auras, {
                    name = aura.name,
                    duration = aura.duration,
                    expirationTime = aura.expirationTime,
                    index = aura.index or i,
                })
            end
        end
    end

    return auras
end

-- Checks whether unit has a buff matching def.
-- Returns found (bool), remaining (seconds left, or nil if not found or
-- the buff has no expiration / is permanent).
function BuffDaddy.Check.UnitHasBuff(unit, def)
    local auras = BuffDaddy.Check.GetUnitAuraList(unit)

    for i = 1, table.getn(auras) do
        local aura = auras[i]
        if NameMatches(aura.name, def.buffNames) then
            local passesTooltip = true
            if def.tooltipCheck then
                passesTooltip = BuffDaddy.Check.AuraTooltipContains(unit, aura.index, def.tooltipCheck)
            end

            if passesTooltip then
                local remaining = nil
                if aura.duration and aura.duration > 0 and aura.expirationTime then
                    remaining = aura.expirationTime - GetTime()
                end
                return true, remaining
            end
        end
    end

    return false, nil
end

-- Builds the list of roster players a given (non-groupCheck) definition applies to.
local function GetTargetPlayers(def, roster)
    local targets = {}

    if def.appliesTo == "everyone" then
        for i = 1, table.getn(roster) do
            table.insert(targets, roster[i])
        end
    elseif def.appliesTo == "manaUsers" then
        for i = 1, table.getn(roster) do
            if roster[i].isManaUser then
                table.insert(targets, roster[i])
            end
        end
    elseif SELF_CLASS_MAP[def.appliesTo] then
        local wantClass = SELF_CLASS_MAP[def.appliesTo]
        for i = 1, table.getn(roster) do
            if roster[i].class == wantClass then
                table.insert(targets, roster[i])
            end
        end
    elseif def.appliesTo == "selectedTargets" then
        -- Only players individually ticked in the minimap submenu for this
        -- def (see BuffDaddy_Minimap.lua / BuffDaddy.OptionalTargets).
        local ticked = BuffDaddy.OptionalTargets[def.name]
        if ticked then
            for i = 1, table.getn(roster) do
                if ticked[roster[i].name] == true then
                    table.insert(targets, roster[i])
                end
            end
        end
    end
    -- "druids" (groupCheck defs) is handled separately - see HandleGroupCheck.

    return targets
end

-- Handles a normal (non-groupCheck) buff definition.
local function HandleNormalBuff(def, roster, results)
    local targets = GetTargetPlayers(def, roster)
    if table.getn(targets) == 0 then return end

    local missingCount = 0
    local missingNames = {}
    -- Separate list feeding ONLY the window's optional "Display players"
    -- list. Always collected (missing + expiring), regardless of the
    -- raid-chat Detailed output toggle.
    local windowEntries = {}

    for i = 1, table.getn(targets) do
        local player = targets[i]
        results.totalExpected = results.totalExpected + 1
        if def.personal then
            results.selfExpected = results.selfExpected + 1
        else
            results.raidExpected = results.raidExpected + 1
        end

        local found, remaining = BuffDaddy.Check.UnitHasBuff(player.unit, def)

        if found then
            results.totalFound = results.totalFound + 1
            if def.personal then
                results.selfFound = results.selfFound + 1
            else
                results.raidFound = results.raidFound + 1
            end
            -- remaining >= 0 guard: a stale/bad expirationTime (e.g. after
            -- someone ports and the aura briefly reports a huge negative
            -- "remaining" like -9000) must never count as expiring - only
            -- a genuinely positive value under the threshold does.
            if BuffDaddy.CheckExpiring and remaining and remaining >= 0 and remaining < BuffDaddy.RUNNING_OUT_THRESHOLD then
                results.runningOutCount = results.runningOutCount + 1
                if not def.personal and BuffDaddy.DetailedOutput then
                    table.insert(missingNames, {name = player.name, class = player.class, expiring = true})
                end
                table.insert(windowEntries, {
                    name = player.name,
                    class = player.class,
                    expiring = true,
                    remainingMinutes = math.ceil(remaining / 60),
                })
            end
        else
            results.playersMissing[player.name] = true

            if def.personal then
                table.insert(results.personalMissing, {
                    playerName = player.name,
                    defName = def.name,
                    class = player.class,
                })
            else
                missingCount = missingCount + 1
                table.insert(missingNames, {name = player.name, class = player.class})
            end
            table.insert(windowEntries, {name = player.name, class = player.class, expiring = false})
        end
    end

    if not def.personal and table.getn(missingNames) > 0 then
        table.insert(results.missingBuffs, {
            defName = def.name,
            class = def.needsClass,
            count = missingCount,
            names = missingNames,
        })
    end

    if table.getn(windowEntries) > 0 then
        -- Self buffs (selfMage etc.) have no needsClass - derive the color
        -- class from appliesTo via SELF_CLASS_MAP instead.
        local windowClass = def.needsClass or SELF_CLASS_MAP[def.appliesTo]
        local windowGroup = {
            defName = def.name,
            class = windowClass,
            entries = windowEntries,
        }
        if def.personal then
            table.insert(results.windowSelfBuffs, windowGroup)
        else
            table.insert(results.windowRaidBuffs, windowGroup)
        end
    end
end

-- Handles Emerald Blessing-style "one person covers everyone" definitions.
-- Rules (per spec):
--   - Only counted/checked at all if def.needsClass (Druid) is present.
--   - If ANY Druid has the buff: everyone online counts as found (satisfied).
--   - If NO Druid has it: every online roster member counts as missing 1,
--     plus a special "Raid is missing Emerald Blessing!" line is triggered.
local function HandleGroupCheck(def, roster, results, presentClasses)
    if not presentClasses[def.needsClass] then return end

    local anyoneHasIt = false
    local sourceRemaining = nil

    for i = 1, table.getn(roster) do
        local player = roster[i]
        if player.class == def.needsClass then
            local found, remaining = BuffDaddy.Check.UnitHasBuff(player.unit, def)
            if found then
                anyoneHasIt = true
                sourceRemaining = remaining
                break
            end
        end
    end

    local onlineCount = table.getn(roster)
    results.totalExpected = results.totalExpected + onlineCount
    results.raidExpected = results.raidExpected + onlineCount

    if anyoneHasIt then
        results.totalFound = results.totalFound + onlineCount
        results.raidFound = results.raidFound + onlineCount
        -- Same remaining >= 0 guard as HandleNormalBuff - see comment there.
        if BuffDaddy.CheckExpiring and sourceRemaining and sourceRemaining >= 0 and sourceRemaining < BuffDaddy.RUNNING_OUT_THRESHOLD then
            results.runningOutCount = results.runningOutCount + onlineCount

            -- Everyone online is "covered" by the same Druid's buff, so if
            -- it's running out, list everyone as expiring together.
            local remainingMinutes = math.ceil(sourceRemaining / 60)
            local windowEntries = {}
            for i = 1, table.getn(roster) do
                table.insert(windowEntries, {
                    name = roster[i].name,
                    class = roster[i].class,
                    expiring = true,
                    remainingMinutes = remainingMinutes,
                })
            end
            table.insert(results.windowRaidBuffs, {
                defName = def.name,
                class = def.needsClass,
                entries = windowEntries,
            })
        end
    else
        local missingNames = {}
        local windowEntries = {}
        for i = 1, table.getn(roster) do
            results.playersMissing[roster[i].name] = true
            table.insert(missingNames, {name = roster[i].name, class = roster[i].class})
            table.insert(windowEntries, {name = roster[i].name, class = roster[i].class, expiring = false})
        end

        table.insert(results.missingBuffs, {
            defName = def.name,
            class = def.needsClass,
            count = onlineCount,
            names = missingNames,
        })

        table.insert(results.windowRaidBuffs, {
            defName = def.name,
            class = def.needsClass,
            entries = windowEntries,
        })

        results.emeraldBlessingRaidMissing = true
    end
end

-- Runs a full check. If announce is true, also sends the raid chat report
-- and whispers. Always updates the small window. If debug is also true,
-- the raid report AND whispers are printed to your own chat window only -
-- nothing goes out to RAID/PARTY/WHISPER. Used by the Debug button.
function BuffDaddy.Check.RunCheck(announce, debug)
    local roster, presentClasses = BuffDaddy.Roster.GetRoster()

    local results = {
        totalExpected = 0,
        totalFound = 0,
        raidExpected = 0,
        raidFound = 0,
        selfExpected = 0,
        selfFound = 0,
        playersMissing = {},
        missingBuffs = {},
        personalMissing = {},
        runningOutCount = 0,
        emeraldBlessingRaidMissing = false,
        -- Per-buff missing/expiring player lists for the optional window
        -- "Display players" list. Independent of Detailed output (that
        -- only affects raid chat). windowRaidBuffs = non-personal buffs,
        -- windowSelfBuffs = personal buffs. Each entry:
        --   { defName = ..., class = ..., entries = { {name, class, expiring, remainingMinutes}, ... } }
        windowRaidBuffs = {},
        windowSelfBuffs = {},
    }

    for i = 1, table.getn(BuffDaddy_Definitions) do
        local def = BuffDaddy_Definitions[i]
        local isEnabled
        if def.targeted then
            -- "Targeted" defs (Inner Fire, Enlighten, Thorns) have no simple
            -- on/off switch - they're effectively "on" whenever at least one
            -- player is ticked in their submenu. An empty tick list just
            -- means GetTargetPlayers() returns nothing and the def is a no-op.
            isEnabled = true
        else
            isEnabled = (not def.optional) or (BuffDaddy.OptionalEnabled[def.name] == true)
        end

        if isEnabled and (not def.needsClass or presentClasses[def.needsClass]) then
            if def.groupCheck then
                HandleGroupCheck(def, roster, results, presentClasses)
            else
                HandleNormalBuff(def, roster, results)
            end
        end
    end

    local missingPlayerCount = 0
    for _ in pairs(results.playersMissing) do
        missingPlayerCount = missingPlayerCount + 1
    end
    results.missingPlayerCount = missingPlayerCount

    BuffDaddy.Output.UpdateWindow(results)

    if announce then
        BuffDaddy.Output.SendRaidReport(results, debug)
        BuffDaddy.Output.SendWhispers(results, debug)
    end

    return results
end
