--[[
    BuffDaddy.lua

    Creates the shared BuffDaddy namespace table and sub-tables that the
    other files hang their functions on. Also holds addon-wide constants
    and starts the 10-second auto-refresh ticker.

    Load order:
        1. BuffDaddy_Definitions.lua  (must load before this file)
        2. BuffDaddy.lua              (this file)
        3. BuffDaddy_Roster.lua
        4. BuffDaddy_Check.lua
        5. BuffDaddy_Output.lua
        6. BuffDaddy_Minimap.lua
        7. BuffDaddy.xml
]]

BuffDaddy = {}

-- How many seconds of remaining duration counts as "running out".
-- Adjustable in-game via the minimap dropdown -> "Buffs-below threshold".
BuffDaddy.RUNNING_OUT_THRESHOLD = 480 -- 8 minutes

-- How often (in seconds) the small window silently auto-refreshes.
-- Adjustable in-game via the minimap dropdown -> "Update interval".
-- 0 (or nil) means auto-refresh is turned off ("Never").
BuffDaddy.AUTO_REFRESH_INTERVAL = 10

-- Session-only (never saved to disk) list of which optional buffs are
-- turned on. Keyed by definition "name". Missing/false = off.
-- Always starts empty (= everything off) on login, by design.
BuffDaddy.OptionalEnabled = {}

-- Session-only (never saved to disk) per-player ticks for "targeted"
-- optional buffs (Inner Fire, Enlighten, Thorns). Shape:
--   BuffDaddy.OptionalTargets[defName][playerName] = true/false
-- Always starts empty on login, by design.
BuffDaddy.OptionalTargets = {}

-- Session-only (never saved to disk) output window behavior settings, all
-- off by default each login. Set from the minimap dropdown.
BuffDaddy.WindowClickthrough = false
BuffDaddy.ShowPrintButton = false
BuffDaddy.ShowDebugButton = false

-- Session-only (never saved to disk) "Detailed output" toggle. When on,
-- the raid chat "Missing:" lines list the actual missing player names
-- (in their class color) instead of just a count. Off by default each
-- login. Set from the minimap dropdown.
BuffDaddy.DetailedOutput = false

-- Session-only (never saved to disk) "Check expiring" toggle. When OFF
-- (default), remaining buff duration is ignored completely - a buff only
-- counts as found/missing, nothing about running out. When ON, buffs
-- with less than BuffDaddy.RUNNING_OUT_THRESHOLD left count towards the
-- window's "Buffs below D min" line. If Detailed output is ALSO on,
-- expiring players get folded into the matching "Missing:" line instead
-- of a separate spammy list. Set from the minimap dropdown.
BuffDaddy.CheckExpiring = false

-- Session-only (never saved to disk) "Expand" toggle, off by default each
-- login. The per-buff missing/expiring player list (window line 4+) is
-- ALWAYS built every check now - this is just the quick show/hide for it,
-- so you can collapse/reveal the list without it costing anything to
-- rebuild. Set from the minimap dropdown or the Expand button (next to
-- Update/Print).
BuffDaddy.PlayerListExpanded = false

-- Sub-namespaces filled in by the other files. Declared here so a load
-- order mistake fails loudly (nil function error) instead of doing nothing.
BuffDaddy.Roster = {}
BuffDaddy.Check = {}
BuffDaddy.Output = {}
BuffDaddy.Minimap = {}

-- Hidden tooltip used to read an aura's tooltip text for disambiguation
-- (e.g. telling the Shadow Protection spell apart from the potion buff of
-- the same name). Created once here so every other file can reuse it.
BuffDaddy.ScanTooltip = CreateFrame("GameTooltip", "BuffDaddyScanTooltip", nil, "GameTooltipTemplate")
BuffDaddy.ScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- (Re)starts the auto-refresh ticker using the current
-- BuffDaddy.AUTO_REFRESH_INTERVAL. Call this any time that value changes
-- (e.g. picked from the minimap dropdown). Safe to call repeatedly.
function BuffDaddy.RestartAutoRefresh()
    if BuffDaddy.AutoRefreshTicker then
        if BuffDaddy.AutoRefreshTicker.Cancel then
            BuffDaddy.AutoRefreshTicker:Cancel()
        end
        BuffDaddy.AutoRefreshTicker = nil
    end

    if BuffDaddy.AUTO_REFRESH_INTERVAL and BuffDaddy.AUTO_REFRESH_INTERVAL > 0 then
        BuffDaddy.AutoRefreshTicker = C_Timer.NewTicker(BuffDaddy.AUTO_REFRESH_INTERVAL, function()
            BuffDaddy.Check.RunCheck(false)
        end)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    -- Silent auto-refresh: updates the small window only, never chat/whispers.
    BuffDaddy.Check.RunCheck(false)
    BuffDaddy.RestartAutoRefresh()
end)
