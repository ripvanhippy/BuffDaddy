--[[
    BuffDaddy_Minimap.lua

    The minimap button and its dropdown menu.
      Left-click               -> show/hide the small output window
      Shift-left-click         -> instant silent check (updates window only)
      Alt-left-click           -> instant check + raid chat report + whispers
      Right-click              -> opens the options dropdown

    Hovering the minimap button shows a tooltip explaining the click
    behaviors above (see OnEnter/OnLeave).

    The dropdown starts with window/behavior options, grouped by prefix -
    "Window: ..." entries first (clickthrough, playername display toggle
    +expand, quick access buttons, autoupdate interval), then "Output: ..."
    entries (detailed playernames, expiring buffs too, expiring threshold),
    then a divider,
    then the list of optional buffs - Priest entries first, then Druid
    entries, each colored in its class color. Most optional buffs are
    simple on/off ticks. "Targeted" buffs (Inner Fire, Enlighten, Thorns)
    instead open a second dropdown level where you tick individual
    raid/group members by name - only those ticked people get checked.

    Depends on: BuffDaddy.lua, BuffDaddy_Check.lua, BuffDaddy_Roster.lua,
                BuffDaddy_Output.lua, BuffDaddy.xml (BuffDaddyMinimapButton,
                BuffDaddyDropDown, and BuffDaddyWindow must exist)
]]

-- Sentinel values (distinct from any real buff def name) used to tell the
-- level-2 submenu builder which special submenu to draw.
local INTERVAL_MENU_VALUE = "__BUFFDADDY_INTERVAL__"
local THRESHOLD_MENU_VALUE = "__BUFFDADDY_THRESHOLD__"

local INTERVAL_OPTIONS = {
    {label = "1 sec", value = 1},
    {label = "2 sec", value = 2},
    {label = "5 sec", value = 5},
    {label = "10 sec", value = 10},
    {label = "Never", value = 0},
}

local THRESHOLD_OPTIONS_MINUTES = {5, 8, 10, 12, 15}

function BuffDaddy.Minimap.OnClick(button)
    if button == "LeftButton" then
        if IsAltKeyDown() then
            BuffDaddy.Check.RunCheck(true)
        elseif IsShiftKeyDown() then
            BuffDaddy.Check.RunCheck(false)
        else
            BuffDaddy.Minimap.ToggleWindow()
        end
    elseif button == "RightButton" then
        BuffDaddy.Minimap.ToggleDropdown()
    end
end

function BuffDaddy.Minimap.ToggleWindow()
    if not BuffDaddyWindow then return end
    if BuffDaddyWindow:IsShown() then
        BuffDaddyWindow:Hide()
    else
        BuffDaddyWindow:Show()
    end
end

-- Called by the Expand button (see BuffDaddy.xml) and mirrored by the
-- "Expand" dropdown toggle. Quick show/hide for the window's "Display
-- players" list, independent of the master switch - re-runs a silent
-- check right away so the window updates immediately.
function BuffDaddy.Minimap.ToggleExpand()
    BuffDaddy.PlayerListExpanded = not BuffDaddy.PlayerListExpanded
    BuffDaddy.Check.RunCheck(false)
end

function BuffDaddy.Minimap.ToggleDropdown()
    if BuffDaddyDropDown:IsShown() then
        BuffDaddyDropDown:Hide()
    else
        ToggleDropDownMenu(1, nil, BuffDaddyDropDown, "BuffDaddyMinimapButton", 0, 0)
    end
end

-- Tooltip explaining the click behaviors, shown on minimap button hover.
function BuffDaddy.Minimap.OnEnter()
    GameTooltip:SetOwner(BuffDaddyMinimapButton, "ANCHOR_LEFT")
    GameTooltip:AddLine("BuffDaddy")
    GameTooltip:AddLine("Left-click: show/hide the output window", 1, 1, 1)
    GameTooltip:AddLine("Right-click: open options", 1, 1, 1)
    GameTooltip:AddLine("Shift-left-click: check + update window", 1, 1, 1)
    GameTooltip:AddLine("Alt-left-click: check, update window, and print", 1, 1, 1)
    GameTooltip:Show()
end

function BuffDaddy.Minimap.OnLeave()
    GameTooltip:Hide()
end

-- Forces the "Inner Fire / Enlighten / Thorns" (and interval/threshold)
-- submenu to always open to the LEFT of the main dropdown instead of
-- Blizzard's default (which tries the right side first). Runs once at
-- load time - DropDownList1/2 are shared global frames created by the
-- game's core UI, so they already exist by the time addons load.
if DropDownList1 and DropDownList2 then
    DropDownList2:HookScript("OnShow", function()
        DropDownList2:ClearAllPoints()
        DropDownList2:SetPoint("TOPRIGHT", DropDownList1, "TOPLEFT", 0, 0)
    end)
end

-- Returns a "|cffRRGGBB" color escape code for a class token, or "" if the
-- class table / token isn't available (falls back to normal white text).
local function ClassColorCode(classToken)
    if RAID_CLASS_COLORS and classToken and RAID_CLASS_COLORS[classToken] then
        local c = RAID_CLASS_COLORS[classToken]
        return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
    end
    return ""
end

-- Wraps text in a class color code (and the reset code "|r" at the end).
local function ColorText(text, classToken)
    local code = ClassColorCode(classToken)
    if code == "" then
        return text
    end
    return code .. text .. "|r"
end

-- True if classToken appears anywhere in classList (a plain array of tokens).
local function ClassInList(classToken, classList)
    if not classList then return false end
    for i = 1, table.getn(classList) do
        if classList[i] == classToken then
            return true
        end
    end
    return false
end

-- Finds a definition in BuffDaddy_Definitions by its display name.
local function FindDefByName(name)
    for i = 1, table.getn(BuffDaddy_Definitions) do
        if BuffDaddy_Definitions[i].name == name then
            return BuffDaddy_Definitions[i]
        end
    end
    return nil
end

-- List of optional definitions, in the order they should be displayed.
-- (Display order is controlled by the order of entries in
-- BuffDaddy_Definitions.lua itself - Priest entries first, then Druid.)
local function GetOptionalDefs()
    local list = {}
    for i = 1, table.getn(BuffDaddy_Definitions) do
        local def = BuffDaddy_Definitions[i]
        if def.optional then
            table.insert(list, def)
        end
    end
    return list
end

-- Builds the second-level ("submenu") dropdown for a targeted def: a
-- tickable list of matching online players, or a "No X found" message.
local function BuildTargetSubmenu(defName)
    local def = FindDefByName(defName)
    if not def then return end

    local roster = BuffDaddy.Roster.GetRoster()
    local matches = {}
    for i = 1, table.getn(roster) do
        if ClassInList(roster[i].class, def.targetClasses) then
            table.insert(matches, roster[i])
        end
    end

    if table.getn(matches) == 0 then
        local info = UIDropDownMenu_CreateInfo()
        info.text = def.noneFoundText or "None found"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, 2)
        return
    end

    if not BuffDaddy.OptionalTargets[defName] then
        BuffDaddy.OptionalTargets[defName] = {}
    end
    local ticked = BuffDaddy.OptionalTargets[defName]

    for i = 1, table.getn(matches) do
        local player = matches[i]

        local info = UIDropDownMenu_CreateInfo()
        info.text = ColorText(player.name, player.class)
        info.checked = (ticked[player.name] == true)
        info.func = function()
            ticked[player.name] = not ticked[player.name]
        end
        info.isNotRadio = true
        info.keepShownOnClick = true
        UIDropDownMenu_AddButton(info, 2)
    end
end

-- Builds the "Window: Autoupdate intervall" submenu (1/2/5/10 sec, or Never).
local function BuildIntervalSubmenu()
    for i = 1, table.getn(INTERVAL_OPTIONS) do
        local opt = INTERVAL_OPTIONS[i]

        local info = UIDropDownMenu_CreateInfo()
        info.text = opt.label
        info.checked = (BuffDaddy.AUTO_REFRESH_INTERVAL == opt.value)
        info.func = function()
            BuffDaddy.AUTO_REFRESH_INTERVAL = opt.value
            BuffDaddy.RestartAutoRefresh()
        end
        UIDropDownMenu_AddButton(info, 2)
    end
end

-- Builds the "Output: expiring buff remaining time threshhold" submenu (5/8/10/12/15 min).
local function BuildThresholdSubmenu()
    for i = 1, table.getn(THRESHOLD_OPTIONS_MINUTES) do
        local minutes = THRESHOLD_OPTIONS_MINUTES[i]

        local info = UIDropDownMenu_CreateInfo()
        info.text = minutes .. " min"
        info.checked = (BuffDaddy.RUNNING_OUT_THRESHOLD == minutes * 60)
        info.func = function()
            BuffDaddy.RUNNING_OUT_THRESHOLD = minutes * 60
        end
        UIDropDownMenu_AddButton(info, 2)
    end
end

-- Adds one simple on/off toggle line to the top-level (level 1) dropdown.
local function AddToggleLine(text, isChecked, onToggle)
    local info = UIDropDownMenu_CreateInfo()
    info.text = text
    info.checked = isChecked
    info.func = onToggle
    info.isNotRadio = true
    info.keepShownOnClick = true
    UIDropDownMenu_AddButton(info, 1)
end

-- Adds a line that opens a submenu (level 2) instead of toggling directly.
-- Deliberately left checkable (checked = false, no func - same trick used
-- for the "Inner Fire" style targeted buffs below) so the checkbox space
-- is reserved and the text indents the same way those entries do.
-- notCheckable=true would sit flush left instead, with no indent.
local function AddSubmenuLine(text, menuValue)
    local info = UIDropDownMenu_CreateInfo()
    info.text = text
    info.hasArrow = true
    info.value = menuValue
    info.checked = false
    UIDropDownMenu_AddButton(info, 1)
end

-- Adds a plain, non-clickable divider line.
local function AddDivider()
    local info = UIDropDownMenu_CreateInfo()
    info.text = "----------------------------"
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, 1)
end

-- Called by the dropdown frame's OnLoad (see BuffDaddy.xml). Handles both
-- the top-level menu (level 1) and any submenu (level 2) - the same
-- function is reused for both, same as any nested vanilla UIDropDownMenu.
function BuffDaddy.Minimap.InitializeDropdown()
    local level = UIDROPDOWNMENU_MENU_LEVEL or 1

    if level == 2 then
        local menuValue = UIDROPDOWNMENU_MENU_VALUE
        if menuValue == INTERVAL_MENU_VALUE then
            BuildIntervalSubmenu()
        elseif menuValue == THRESHOLD_MENU_VALUE then
            BuildThresholdSubmenu()
        else
            BuildTargetSubmenu(menuValue)
        end
        return
    end

    -- Window/behavior options, grouped by prefix (Window: first, then Output:).
    AddToggleLine("Window: Clickthrough", BuffDaddy.WindowClickthrough == true, function()
        BuffDaddy.WindowClickthrough = not BuffDaddy.WindowClickthrough
        BuffDaddy.Output.SetClickthrough(BuffDaddy.WindowClickthrough)
    end)

    AddToggleLine("Window: expand playername display", BuffDaddy.PlayerListExpanded == true, function()
        BuffDaddy.Minimap.ToggleExpand()
    end)

    AddToggleLine("Window: show quick access buttons", BuffDaddy.ShowPrintButton == true, function()
        BuffDaddy.ShowPrintButton = not BuffDaddy.ShowPrintButton
        BuffDaddy.Output.SetPrintButtonShown(BuffDaddy.ShowPrintButton)
    end)

    AddToggleLine("Window: Debug button", BuffDaddy.ShowDebugButton == true, function()
        BuffDaddy.ShowDebugButton = not BuffDaddy.ShowDebugButton
        BuffDaddy.Output.SetDebugButtonShown(BuffDaddy.ShowDebugButton)
    end)

    AddSubmenuLine("Window: Autoupdate intervall", INTERVAL_MENU_VALUE)

    AddToggleLine("Output: Detailed (Playernames)", BuffDaddy.DetailedOutput == true, function()
        BuffDaddy.DetailedOutput = not BuffDaddy.DetailedOutput
    end)

    AddToggleLine("Output: display expiring Buffs too", BuffDaddy.CheckExpiring == true, function()
        BuffDaddy.CheckExpiring = not BuffDaddy.CheckExpiring
    end)

    AddSubmenuLine("Output: expiring buff remaining time threshhold", THRESHOLD_MENU_VALUE)

    AddDivider()

    local info = UIDropDownMenu_CreateInfo()
    info.text = "Optional buffs (off by default each login):"
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, 1)

    local optionalDefs = GetOptionalDefs()
    for i = 1, table.getn(optionalDefs) do
        local def = optionalDefs[i]

        info = UIDropDownMenu_CreateInfo()
        info.text = ColorText(def.name, def.dropdownClass)

        if def.targeted then
            -- Opens a submenu of individual raid/group members instead of
            -- toggling directly. notCheckable is deliberately left false
            -- (with checked=false and no func) purely so the checkbox
            -- space is reserved and the text lines up with Shadow
            -- Protection / Emerald Blessing above it - clicking here just
            -- opens the submenu, the checkbox itself never does anything.
            info.hasArrow = true
            info.value = def.name
            info.checked = false
        else
            info.checked = (BuffDaddy.OptionalEnabled[def.name] == true)
            info.func = function()
                BuffDaddy.OptionalEnabled[def.name] = not BuffDaddy.OptionalEnabled[def.name]
            end
            info.isNotRadio = true
            info.keepShownOnClick = true
        end

        UIDropDownMenu_AddButton(info, 1)
    end
end
