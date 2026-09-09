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

-- All settings below are now PERSISTED between sessions in the
-- BuffDaddyDB SavedVariable (see BuffDaddy.toc). The plain values here
-- are just fallback defaults used the very first time the addon ever
-- loads (before BuffDaddyDB exists) - BuffDaddy.LoadSettings() (below)
-- overwrites all of these from BuffDaddyDB at ADDON_LOADED, and
-- BuffDaddy.SaveSettings() writes the current values back into
-- BuffDaddyDB any time one of them changes (see BuffDaddy_Minimap.lua)
-- and again at logout as a safety net.

-- Which optional buffs are turned on. Keyed by definition "name".
-- Missing/false = off.
BuffDaddy.OptionalEnabled = {}

-- Per-player ticks for "targeted" optional buffs (Inner Fire, Enlighten,
-- Thorns). Shape:
--   BuffDaddy.OptionalTargets[defName][playerName] = true/false
BuffDaddy.OptionalTargets = {}

-- Output window behavior settings.
BuffDaddy.WindowClickthrough = false
BuffDaddy.ShowPrintButton = false
BuffDaddy.ShowDebugButton = false

-- "Detailed output" toggle. When on, the raid chat "Missing:" lines list
-- the actual missing player names (in their class color) instead of just
-- a count.
BuffDaddy.DetailedOutput = false

-- "Check expiring" toggle. When OFF (default), remaining buff duration is
-- ignored completely - a buff only counts as found/missing, nothing about
-- running out. When ON, buffs with less than
-- BuffDaddy.RUNNING_OUT_THRESHOLD left count towards the window's
-- "Buffs below D min" line. If Detailed output is ALSO on, expiring
-- players get folded into the matching "Missing:" line instead of a
-- separate spammy list.
BuffDaddy.CheckExpiring = false

-- "Expand" toggle. The per-buff missing/expiring player list (window
-- line 4+) is ALWAYS built every check - this is just the quick show/hide
-- for it, so you can collapse/reveal the list without it costing anything
-- to rebuild.
BuffDaddy.PlayerListExpanded = false

-- List of BuffDaddy.* field names that are simple values (boolean/number)
-- and get copied to/from BuffDaddyDB as-is. OptionalEnabled and
-- OptionalTargets are handled separately below since they're tables -
-- once loaded, BuffDaddy.OptionalEnabled/OptionalTargets point at the
-- SAME table as BuffDaddyDB.OptionalEnabled/OptionalTargets, so every
-- change to them (ticking an optional buff, ticking a targeted player)
-- is already "saved" the instant it happens - no extra save call needed
-- for those two.
local SAVED_VALUE_FIELDS = {
    "WindowClickthrough", "ShowPrintButton", "ShowDebugButton",
    "DetailedOutput", "CheckExpiring", "PlayerListExpanded",
    "AUTO_REFRESH_INTERVAL", "RUNNING_OUT_THRESHOLD",
}

-- Called from the ADDON_LOADED handler below. Creates BuffDaddyDB the
-- very first time (using whatever defaults are set above), otherwise
-- copies every saved value out of BuffDaddyDB into BuffDaddy.* so the
-- rest of the addon just keeps reading/writing BuffDaddy.* like before.
function BuffDaddy.LoadSettings()
    if not BuffDaddyDB then
        BuffDaddyDB = {}
    end

    for i = 1, table.getn(SAVED_VALUE_FIELDS) do
        local field = SAVED_VALUE_FIELDS[i]
        if BuffDaddyDB[field] == nil then
            BuffDaddyDB[field] = BuffDaddy[field]
        end
        BuffDaddy[field] = BuffDaddyDB[field]
    end

    if not BuffDaddyDB.OptionalEnabled then
        BuffDaddyDB.OptionalEnabled = {}
    end
    BuffDaddy.OptionalEnabled = BuffDaddyDB.OptionalEnabled

    if not BuffDaddyDB.OptionalTargets then
        BuffDaddyDB.OptionalTargets = {}
    end
    BuffDaddy.OptionalTargets = BuffDaddyDB.OptionalTargets
end

-- Copies the current BuffDaddy.* simple values back into BuffDaddyDB.
-- Call this any time one of the SAVED_VALUE_FIELDS above changes (see the
-- dropdown/button toggle functions in BuffDaddy_Minimap.lua) so a crash
-- or /reload doesn't lose it - also called once at PLAYER_LOGOUT as a
-- safety net.
function BuffDaddy.SaveSettings()
    if not BuffDaddyDB then return end
    for i = 1, table.getn(SAVED_VALUE_FIELDS) do
        local field = SAVED_VALUE_FIELDS[i]
        BuffDaddyDB[field] = BuffDaddy[field]
    end
end

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
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "BuffDaddy" then
        -- Load every saved setting from BuffDaddyDB into BuffDaddy.* before
        -- anything else runs (see BuffDaddy.LoadSettings above).
        BuffDaddy.LoadSettings()
    elseif event == "PLAYER_LOGIN" then
        -- Apply the loaded window/button settings to the actual frames now
        -- that BuffDaddy.xml's OnLoad scripts have already run.
        BuffDaddy.Output.SetClickthrough(BuffDaddy.WindowClickthrough)
        BuffDaddy.Output.SetPrintButtonShown(BuffDaddy.ShowPrintButton)
        BuffDaddy.Output.SetDebugButtonShown(BuffDaddy.ShowDebugButton)

        -- Silent auto-refresh: updates the small window only, never chat/whispers.
        BuffDaddy.Check.RunCheck(false)
        BuffDaddy.RestartAutoRefresh()
    elseif event == "PLAYER_LOGOUT" then
        -- Safety net in case a toggle's own save call was somehow missed.
        BuffDaddy.SaveSettings()
    end
end)
