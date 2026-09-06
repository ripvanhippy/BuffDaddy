--[[
    BuffDaddy_Roster.lua

    Figures out who to check: yourself if solo, your party if grouped,
    your raid if in a raid. Skips offline players and skipped classes
    (currently just Paladin) entirely - they are treated as if they
    don't exist for this addon.

    Depends on: BuffDaddy.lua (namespace), BuffDaddy_Definitions.lua
                (BuffDaddy_SkippedClasses, BuffDaddy_ManaUserClasses)
]]

-- Returns:
--   roster         - array of {unit=unitToken, name=name, class=classToken, isManaUser=bool}
--   presentClasses - table keyed by classToken = true, for every class that
--                    has at least one online, non-skipped member in roster
function BuffDaddy.Roster.GetRoster()
    local roster = {}
    local presentClasses = {}
    local units = {}

    local raidCount = GetNumRaidMembers()
    local partyCount = GetNumPartyMembers()

    if raidCount and raidCount > 0 then
        for i = 1, raidCount do
            table.insert(units, "raid" .. i)
        end
    elseif partyCount and partyCount > 0 then
        table.insert(units, "player")
        for i = 1, partyCount do
            table.insert(units, "party" .. i)
        end
    else
        table.insert(units, "player")
    end

    for i = 1, table.getn(units) do
        local unit = units[i]

        if UnitExists(unit) then
            local isConnected = true
            if UnitIsConnected then
                isConnected = UnitIsConnected(unit)
            end

            if isConnected then
                local name = UnitName(unit)
                local _, classToken = UnitClass(unit)

                if classToken and not BuffDaddy_SkippedClasses[classToken] then
                    local isManaUser = BuffDaddy_ManaUserClasses[classToken] == true

                    table.insert(roster, {
                        unit = unit,
                        name = name,
                        class = classToken,
                        isManaUser = isManaUser,
                    })

                    presentClasses[classToken] = true
                end
            end
        end
    end

    return roster, presentClasses
end
