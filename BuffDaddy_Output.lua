--[[
    BuffDaddy_Output.lua

    Turns a "results" table (built by BuffDaddy_Check.lua) into:
      - the small window's 3 lines
      - the colored raid chat report
      - the whispers to people missing personal buffs

    Depends on: BuffDaddy.lua, BuffDaddy_Definitions.lua (for class names),
                BuffDaddy.xml (the window's FontStrings must already exist)
]]

-- Color code helpers. WoW chat renders these |cAARRGGBB...|r codes even in
-- messages sent to RAID/PARTY/WHISPER channels.
local C_BLACK  = "|cFF000000"
local C_WHITE  = "|cFFFFFFFF"
local C_LBLUE  = "|cFF66CCFF"
local C_GREEN  = "|cFF00FF00"
local C_RED    = "|cFFFF0000"
local C_YELLOW = "|cFFFFFF00"
local C_ORANGE = "|cFFFF8000"
local C_GREY   = "|cFF808080"
local C_WSP    = "|cFFFF80FF" -- standard WoW whisper chat color
local R        = "|r"

-- Colors used for the letter-by-letter "BUFFCHECK" rainbow effect.
-- Deliberately avoids dark blue, dark purple, deep red, and dark pink,
-- since those are hard to read in chat.
local RAINBOW_COLORS = {
    "|cFFFF5555", -- red
    "|cFFFFA500", -- orange
    "|cFFFFFF00", -- yellow
    "|cFF55FF55", -- green
    "|cFF00FFFF", -- cyan
    "|cFF5599FF", -- blue
    "|cFFFF66FF", -- pink
}

-- Colors each letter of text in a cycling rainbow pattern.
local function RainbowText(text)
    local result = ""
    local colorIndex = 1
    local numColors = table.getn(RAINBOW_COLORS)

    for i = 1, string.len(text) do
        local ch = string.sub(text, i, i)
        result = result .. RAINBOW_COLORS[colorIndex] .. ch .. R
        colorIndex = colorIndex + 1
        if colorIndex > numColors then
            colorIndex = 1
        end
    end

    return result
end

local function ClassColor(classToken)
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
        local c = RAID_CLASS_COLORS[classToken]
        return string.format("|cFF%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
    end
    return C_WHITE
end

-- Nicely-capitalized class display name, e.g. "MAGE" -> "Mage".
local function ClassDisplayName(classToken)
    if not classToken then return "" end
    return string.upper(string.sub(classToken, 1, 1)) .. string.lower(string.sub(classToken, 2))
end

-- ===== "Display players" window list (per-buff missing/expiring names) =====

-- How many player names go on one indented row under a buff's header line.
local PLAYER_LIST_NAMES_PER_LINE = 3

-- One player's name in their class color, with a grey " (X min)" suffix
-- appended if they're an expiring (not missing) entry.
local function BuildPlayerEntryText(entry)
    local text = ClassColor(entry.class) .. entry.name .. R
    if entry.expiring then
        text = text .. C_GREY .. " (" .. entry.remainingMinutes .. " min)" .. R
    end
    return text
end

-- One buff's block: a class-colored "buffname" header line, followed by
-- its missing/expiring player names, each row prefixed with a white
-- "--" marker, 3 names per line.
local function BuildPlayerGroupText(group)
    local text = ClassColor(group.class) .. '"' .. group.defName .. '"' .. R

    local entries = group.entries
    local i = 1
    while i <= table.getn(entries) do
        local row = C_WHITE .. "--" .. R .. " "
        local count = 0
        local j = i
        while j <= table.getn(entries) and count < PLAYER_LIST_NAMES_PER_LINE do
            if count > 0 then
                row = row .. ", "
            end
            row = row .. BuildPlayerEntryText(entries[j])
            j = j + 1
            count = count + 1
        end
        text = text .. "\n" .. row
        i = i + PLAYER_LIST_NAMES_PER_LINE
    end

    return text
end

-- Builds the full "Display players" text block (every missing/expiring
-- raid buff, then every missing/expiring self buff), or nil if there's
-- nothing to show. Used to fill BuffDaddyWindowPlayerList.
function BuffDaddy.Output.BuildPlayerListText(results)
    local hasContent = table.getn(results.windowRaidBuffs) > 0 or table.getn(results.windowSelfBuffs) > 0
    if not hasContent then return nil end

    local text = nil
    local function AppendBlock(block)
        if text then
            text = text .. "\n" .. block
        else
            text = block
        end
    end

    for i = 1, table.getn(results.windowRaidBuffs) do
        AppendBlock(BuildPlayerGroupText(results.windowRaidBuffs[i]))
    end
    for i = 1, table.getn(results.windowSelfBuffs) do
        AppendBlock(BuildPlayerGroupText(results.windowSelfBuffs[i]))
    end

    return text
end

-- Counts the number of visual lines in a player-list text block (number of
-- "\n" plus one), used to figure out how tall the window needs to be.
local function CountTextLines(text)
    if not text then return 0 end
    local _, breakCount = string.gsub(text, "\n", "\n")
    return breakCount + 1
end

-- Extra window size (beyond the base size captured at OnLoad, see
-- BuffDaddy.xml) needed to fit the player list. Approximate, since this
-- client's Lua can't measure real text width/height - tuned by eye against
-- GameFontNormal at the window's normal scale.
local PLAYER_LIST_LINE_HEIGHT = 12
local PLAYER_LIST_TOP_GAP = 16
local PLAYER_LIST_WIDTH_BONUS = 70

-- How far down (in pixels) the text lines shift, and how much extra
-- window height is added, when the quick-access buttons are shown. Must
-- match the button row's height + gap in BuffDaddy.xml (20px buttons +
-- a couple px gap).
local BUTTON_ROW_SHIFT = 22

-- Grows or shrinks BuffDaddyWindow to fit the player list (or back down to
-- its normal size when the list is hidden/empty). BuffDaddy.WindowBaseWidth
-- / WindowBaseHeight are captured once, in BuffDaddyWindow's OnLoad, from
-- whatever size is set in BuffDaddy.xml - so any manual resize done there
-- is preserved as the "collapsed" size this always returns to.
function BuffDaddy.Output.ResizeWindow(listText)
    if not BuffDaddyWindow then return end

    local baseWidth = BuffDaddy.WindowBaseWidth or BuffDaddyWindow:GetWidth()
    local baseHeight = BuffDaddy.WindowBaseHeight or BuffDaddyWindow:GetHeight()

    -- When the quick-access buttons are shown, the text lines are shifted
    -- down (see ApplyLineLayout below) to sit below the button row instead
    -- of underneath it - add the same amount of extra height here so
    -- nothing gets cut off at the bottom.
    if BuffDaddy.ShowPrintButton then
        baseHeight = baseHeight + BUTTON_ROW_SHIFT
    end

    if listText then
        local lineCount = CountTextLines(listText)
        BuffDaddyWindow:SetWidth(baseWidth + PLAYER_LIST_WIDTH_BONUS)
        BuffDaddyWindow:SetHeight(baseHeight + PLAYER_LIST_TOP_GAP + (lineCount * PLAYER_LIST_LINE_HEIGHT))
    else
        BuffDaddyWindow:SetWidth(baseWidth)
        BuffDaddyWindow:SetHeight(baseHeight)
    end
end

-- Y-offsets each text line normally sits at (buttons hidden), matching
-- BuffDaddy.xml's defaults. Kept here so ApplyLineLayout can shift them
-- down by the same BUTTON_ROW_SHIFT amount used above, instead of the two
-- places drifting out of sync.
local NORMAL_LINE_OFFSETS = {
    Line1 = -5,
    Line2 = -17,
    Line3 = -29,
    PlayerList = -41,
}

-- Moves the window's text lines (Line1/2/3 + player list) between their
-- normal top-left position and a position shifted down by BUTTON_ROW_SHIFT,
-- so the Expand/Update/Print buttons (top-left, see BuffDaddy.xml) don't
-- sit on top of the text when shown. Called from
-- BuffDaddy.Output.SetPrintButtonShown whenever that toggle changes.
local function ApplyLineLayout(buttonsShown)
    if not BuffDaddyWindowLine1 then return end

    local shift = 0
    if buttonsShown then
        shift = -BUTTON_ROW_SHIFT
    end

    BuffDaddyWindowLine1:ClearAllPoints()
    BuffDaddyWindowLine1:SetPoint("TOPLEFT", BuffDaddyWindow, "TOPLEFT", 5, NORMAL_LINE_OFFSETS.Line1 + shift)

    BuffDaddyWindowLine2:ClearAllPoints()
    BuffDaddyWindowLine2:SetPoint("TOPLEFT", BuffDaddyWindow, "TOPLEFT", 5, NORMAL_LINE_OFFSETS.Line2 + shift)

    BuffDaddyWindowLine3:ClearAllPoints()
    BuffDaddyWindowLine3:SetPoint("TOPLEFT", BuffDaddyWindow, "TOPLEFT", 5, NORMAL_LINE_OFFSETS.Line3 + shift)

    if BuffDaddyWindowPlayerList then
        BuffDaddyWindowPlayerList:ClearAllPoints()
        BuffDaddyWindowPlayerList:SetPoint("TOPLEFT", BuffDaddyWindow, "TOPLEFT", 5, NORMAL_LINE_OFFSETS.PlayerList + shift)
    end
end

-- Line 1: Groupbuffs found/expected (green if none missing, red if any).
-- Line 2: Selfbuffs found/expected (same coloring rule).
-- Line 3: how many found buffs are below the running-out threshold
-- (green if 0, red if at least 1).
function BuffDaddy.Output.UpdateWindow(results)
    if not BuffDaddyWindowLine1 then return end

    local thresholdMinutes = BuffDaddy.RUNNING_OUT_THRESHOLD / 60

    local raidColor = C_GREEN
    if results.raidFound < results.raidExpected then
        raidColor = C_RED
    end

    local selfColor = C_GREEN
    if results.selfFound < results.selfExpected then
        selfColor = C_RED
    end

    local belowColor = C_GREEN
    if results.runningOutCount > 0 then
        belowColor = C_RED
    end

    BuffDaddyWindowLine1:SetText(raidColor .. "Groupbuffs " .. results.raidFound .. "/" .. results.raidExpected .. R)
    BuffDaddyWindowLine2:SetText(selfColor .. "Selfbuffs " .. results.selfFound .. "/" .. results.selfExpected .. R)
    BuffDaddyWindowLine3:SetText(belowColor .. "Buffs below " .. thresholdMinutes .. " min " .. results.runningOutCount .. R)

    -- Line 4+: optional "Display players" list. The list itself is always
    -- built (see BuffDaddy_Check.lua) - this Expand toggle only controls
    -- whether it's actually shown in the window.
    local listText = nil
    if BuffDaddy.PlayerListExpanded then
        listText = BuffDaddy.Output.BuildPlayerListText(results)
    end

    if BuffDaddyWindowPlayerList then
        if listText then
            BuffDaddyWindowPlayerList:SetText(listText)
            BuffDaddyWindowPlayerList:Show()
        else
            BuffDaddyWindowPlayerList:SetText("")
            BuffDaddyWindowPlayerList:Hide()
        end
    end

    BuffDaddy.Output.ResizeWindow(listText)
end

-- Called from the minimap dropdown's "Clickthrough output window" toggle.
-- When on, the window ignores mouse clicks entirely so they pass through
-- to whatever is behind it (it also can't be dragged while this is on).
function BuffDaddy.Output.SetClickthrough(state)
    if not BuffDaddyWindow then return end
    BuffDaddyWindow:EnableMouse(not state)
end

-- Called from the minimap dropdown's "Show quick access buttons" toggle.
-- Also shows/hides the Update button (sits just right of Expand) and the
-- Print button (sits just right of Update) - all three are controlled by
-- the same toggle. Also shifts the text lines down (or back up) so they
-- don't sit underneath the button row - see ApplyLineLayout above - and
-- re-runs a silent check so the window resizes immediately.
function BuffDaddy.Output.SetPrintButtonShown(state)
    if not BuffDaddyPrintButton then return end
    if state then
        BuffDaddyPrintButton:Show()
        if BuffDaddyUpdateButton then BuffDaddyUpdateButton:Show() end
        if BuffDaddyExpandButton then BuffDaddyExpandButton:Show() end
    else
        BuffDaddyPrintButton:Hide()
        if BuffDaddyUpdateButton then BuffDaddyUpdateButton:Hide() end
        if BuffDaddyExpandButton then BuffDaddyExpandButton:Hide() end
    end

    ApplyLineLayout(state)
    BuffDaddy.Check.RunCheck(false)
end

-- Called from the minimap dropdown's "Debug button" toggle. Independent of
-- the Expand/Update/Print trio - the Debug button lives ABOVE the window
-- (see BuffDaddy.xml) so it never overlaps the text lines and doesn't
-- need ApplyLineLayout.
function BuffDaddy.Output.SetDebugButtonShown(state)
    if not BuffDaddyDebugButton then return end
    if state then
        BuffDaddyDebugButton:Show()
    else
        BuffDaddyDebugButton:Hide()
    end
end

-- Used by BuffDaddyWindow's OnMouseDown/OnMouseUp scripts (see BuffDaddy.xml).
-- Dragging is skipped entirely while BuffDaddy.WindowLocked is true.
function BuffDaddy.Output.OnWindowMouseDown()
    -- Clickthrough (when on) already stops the window from receiving mouse
    -- events at all, so there's nothing extra to check here for a "lock" -
    -- if the mouse got this event, dragging is allowed.
    BuffDaddyWindow:StartMoving()
end

function BuffDaddy.Output.OnWindowMouseUp()
    BuffDaddyWindow:StopMovingOrSizing()
end

-- Small delay between successive SendChatMessage calls. Vanilla can
-- silently drop a chat line if several are sent back-to-back in the same
-- frame/tick (this is why the rainbow BUFFCHECK line was sometimes
-- missing while the "Missing:" lines still came through in a group) -
-- staggering them a fraction of a second apart fixes it.
local CHAT_LINE_DELAY = 0.2

-- Picks which channel to send the raid report / whispers-adjacent messages
-- to. debugMode forces nil (local print only) regardless of group/raid
-- status - used by the Debug button so nothing goes out to real players.
local function GetReportChannel(debugMode)
    if debugMode then
        return nil
    end
    if GetNumRaidMembers() > 0 then
        return "RAID"
    elseif GetNumPartyMembers() > 0 then
        return "PARTY"
    end
    return nil -- solo: nobody to send to, print locally instead
end

local function SendReportLine(text, channel)
    if channel then
        SendChatMessage(text, channel)
    else
        DEFAULT_CHAT_FRAME:AddMessage(text)
    end
end

-- Sends a list of lines one at a time, CHAT_LINE_DELAY seconds apart,
-- instead of firing them all in the same instant.
-- Line 1 now also gets a CHAT_LINE_DELAY head start (not sent instantly at
-- 0s) so it isn't fired on the exact same game tick as whatever triggered
-- the check (button click / keybind) - that same-tick collision is a second,
-- separate way vanilla can silently eat a chat line, on top of two
-- SendChatMessage calls landing in the same tick as each other.
local function SendLinesStaggered(lines, channel)
    for i = 1, table.getn(lines) do
        local line = lines[i]
        C_Timer.After(i * CHAT_LINE_DELAY, function()
            SendReportLine(line, channel)
        end)
    end
end

-- Line 1: the BUFFCHECK summary line.
-- x/y Groupbuffs (green if equal, red if not), a/b Selfbuffs (same rule).
-- The " | c Buffs below D min" segment is only appended when
-- "Output: display expiring Buffs too" is on - otherwise runningOutCount
-- is always 0 and showing it would look like a real (empty) result.
local function BuildSummaryLine(results, thresholdMinutes)
    local prefix = C_BLACK .. ">>> " .. R

    local raidColor = C_GREEN
    if results.raidFound < results.raidExpected then
        raidColor = C_RED
    end

    local selfColor = C_GREEN
    if results.selfFound < results.selfExpected then
        selfColor = C_RED
    end

    local line = prefix .. C_LBLUE .. "BUFFCHECK" .. R .. C_WHITE .. " - " .. R ..
        raidColor .. results.raidFound .. "/" .. results.raidExpected .. R ..
        C_WHITE .. " Groupbuffs | " .. R ..
        selfColor .. results.selfFound .. "/" .. results.selfExpected .. R ..
        C_WHITE .. " Selfbuffs" .. R

    if BuffDaddy.CheckExpiring then
        local belowColor = C_RED
        if results.runningOutCount == 0 then
            belowColor = C_GREEN
        end
        line = line .. C_WHITE .. " | " .. R ..
            belowColor .. results.runningOutCount .. R ..
            C_WHITE .. " Buffs below " .. thresholdMinutes .. " min" .. R
    end

    return line
end

-- Builds the tail end of a missing-buff line: either "on N Players" (the
-- normal, compact form) or - when Detailed output is turned on - a list
-- of the actual missing player names, each in their own class color,
-- capped at 5 names with a red "(and more...!)" if there are more.
local function BuildMissingTail(mb)
    if not BuffDaddy.DetailedOutput or not mb.names or table.getn(mb.names) == 0 then
        return C_WHITE .. " on " .. mb.count .. " Players" .. R
    end

    local tail = C_WHITE .. ": " .. R
    local shown = 0

    for i = 1, table.getn(mb.names) do
        if shown >= 5 then
            tail = tail .. C_RED .. " (and more...!)" .. R
            break
        end

        local entry = mb.names[i]
        if shown > 0 then
            tail = tail .. C_WHITE .. ", " .. R
        end
        tail = tail .. ClassColor(entry.class) .. entry.name .. R
        if entry.expiring then
            tail = tail .. C_WHITE .. " (expiring)" .. R
        end
        shown = shown + 1
    end

    return tail
end

-- One line per missing (non-personal) raid buff.
local function BuildMissingLine(mb)
    local prefix = C_BLACK .. ">>> " .. R

    return prefix .. C_WHITE .. "Missing" .. R ..
        C_WHITE .. ' "' .. R ..
        C_GREY .. mb.defName .. R ..
        C_WHITE .. '" from ' .. R ..
        C_WHITE .. ClassDisplayName(mb.class) .. R ..
        BuildMissingTail(mb)
end

-- Single summary line shown once if any self (personal) buffs are missing -
-- the per-player detail already went out as whispers, this just flags it
-- in the raid chat report.
local function BuildSelfBuffMissingLine()
    local prefix = C_BLACK .. ">>> " .. R

    return prefix .. C_ORANGE .. "Missing" .. R ..
        C_WHITE .. " Selfbuffs have gotten " .. R ..
        C_WSP .. "wsp" .. R
end

function BuffDaddy.Output.SendRaidReport(results, debugMode)
    local channel = GetReportChannel(debugMode)
    local thresholdMinutes = BuffDaddy.RUNNING_OUT_THRESHOLD / 60

    local lines = {}
    table.insert(lines, BuildSummaryLine(results, thresholdMinutes))

    for i = 1, table.getn(results.missingBuffs) do
        table.insert(lines, BuildMissingLine(results.missingBuffs[i]))
    end

    if table.getn(results.personalMissing) > 0 then
        table.insert(lines, BuildSelfBuffMissingLine())
    end

    SendLinesStaggered(lines, channel)
end

function BuffDaddy.Output.SendWhispers(results, debugMode)
    for i = 1, table.getn(results.personalMissing) do
        local pm = results.personalMissing[i]
        local msg = C_BLACK .. ">>> " .. R ..
            C_WHITE .. "You are " .. R ..
            C_RED .. "missing" .. R ..
            C_WHITE .. " your " .. R ..
            ClassColor(pm.class) .. pm.defName .. R ..
            C_WHITE .. "!" .. R
        local recipient = pm.playerName

        if debugMode then
            -- Debug mode never whispers a real player - print what WOULD
            -- have been whispered, to your own chat window instead.
            local debugMsg = C_BLACK .. ">>> " .. R ..
                C_WSP .. "[Debug whisper -> " .. recipient .. "] " .. R .. msg
            C_Timer.After(i * CHAT_LINE_DELAY, function()
                DEFAULT_CHAT_FRAME:AddMessage(debugMsg)
            end)
        else
            C_Timer.After(i * CHAT_LINE_DELAY, function()
                SendChatMessage(msg, "WHISPER", nil, recipient)
            end)
        end
    end
end
