--[[
    BuffDaddy_Definitions.lua

    Pure data. No functions, no dependencies on anything else.
    This file MUST load first (see BuffDaddy.toc).

    This is the file you'll edit most often: buff names, which class
    provides them, who needs them, optional on/off, etc.

    Field reference (see README.md for the full explanation):
        name        - Display name used in whispers / raid chat / dropdown.
        buffNames   - List of exact aura names to look for (any match = found).
        tooltipCheck- (optional) A word/phrase that MUST also appear in the
                      aura's tooltip body text. Only needed when buffNames
                      alone is ambiguous (e.g. two different buffs share a name).
        needsClass  - The class that must be present (online, not Paladin) in
                      the raid/group for this buff to be checked at all.
        appliesTo   - Who needs this buff:
                        "everyone"       - every present, online player
                        "manaUsers"      - every present, online mana-using player
                        "selfMage"       - only players who ARE that class
                        "selfHunter"
                        "selfWarlock"
                        "selfPriest"
                        "selfShaman"
                        "druids"         - special, only used together with groupCheck
                        "selectedTargets"- special, only used together with
                                           targeted (see below)
        personal    - true  = whispered when missing, never shown in the raid
                              chat "Missing:" list.
                      false = shown in raid chat, never whispered.
        optional    - true = only checked if enabled via the minimap dropdown.
                      Always starts OFF when you log in (not saved between sessions).
        groupCheck  - true = special "one person covers everyone" buff, like
                      Emerald Blessing. See BuffDaddy_Check.lua for the logic.
        targeted    - true = instead of a simple on/off tick in the dropdown,
                      this buff opens a submenu where you tick individual
                      raid/group members by name. Only THOSE ticked players
                      are ever checked for this buff. See BuffDaddy_Minimap.lua.
        targetClasses - (targeted defs only) which classes are allowed to show
                      up as tickable names in the submenu.
        noneFoundText - (targeted defs only) text shown in the submenu instead
                      of a name list, when nobody online matches targetClasses.
        dropdownClass - class token used to color this entry's text in the
                      minimap dropdown (and to group/order Priest vs Druid).
]]

-- Classes completely ignored by this addon (as players AND as buff
-- providers). Currently just Paladin, since Max plays Horde.
BuffDaddy_SkippedClasses = {
    ["PALADIN"] = true,
}

-- Classes considered "mana users" for appliesTo = "manaUsers".
-- Warriors and Rogues are NOT mana users.
BuffDaddy_ManaUserClasses = {
    ["MAGE"] = true,
    ["PRIEST"] = true,
    ["WARLOCK"] = true,
    ["SHAMAN"] = true,
    ["DRUID"] = true,
    ["HUNTER"] = true,
}

BuffDaddy_Definitions = {
    {
        name = "Mark of the Wild",
        buffNames = {"Mark of the Wild", "Gift of the Wild"},
        needsClass = "DRUID",
        appliesTo = "everyone",
        personal = false,
    },
    {
        name = "Power Word: Fortitude",
        buffNames = {"Power Word: Fortitude", "Prayer of Fortitude"},
        needsClass = "PRIEST",
        appliesTo = "everyone",
        personal = false,
    },
    {
        name = "Divine Spirit",
        buffNames = {"Divine Spirit", "Prayer of Spirit"},
        needsClass = "PRIEST",
        appliesTo = "manaUsers",
        personal = false,
    },
    {
        name = "Arcane Intellect",
        buffNames = {"Arcane Intellect", "Arcane Brilliance"},
        needsClass = "MAGE",
        appliesTo = "manaUsers",
        personal = false,
    },
    -- Optional buffs shown in the minimap dropdown.
    -- Order below = display order: Priest entries first, then Druid entries.
    {
        name = "Shadow Protection",
        buffNames = {"Shadow Protection", "Prayer of Shadow Protection"},
        tooltipCheck = "Shadow Resistance",
        needsClass = "PRIEST",
        appliesTo = "everyone",
        personal = false,
        optional = true,
        dropdownClass = "PRIEST",
    },
    {
        name = "Inner Fire",
        buffNames = {"Inner Fire"},
        needsClass = "PRIEST",
        appliesTo = "selectedTargets",
        personal = true,
        optional = true,
        targeted = true,
        targetClasses = {"PRIEST"},
        noneFoundText = "No priest found",
        dropdownClass = "PRIEST",
    },
    {
        name = "Enlighten",
        buffNames = {"Enlighten Dummy"},
        needsClass = "PRIEST",
        appliesTo = "selectedTargets",
        personal = true,
        optional = true,
        targeted = true,
        targetClasses = {"PRIEST"},
        noneFoundText = "No priest found",
        dropdownClass = "PRIEST",
    },
    {
        name = "Emerald Blessing",
        buffNames = {"Emerald Blessing"},
        needsClass = "DRUID",
        appliesTo = "druids",
        personal = false,
        optional = true,
        groupCheck = true,
        dropdownClass = "DRUID",
    },
    {
        name = "Thorns",
        buffNames = {"Thorns"},
        needsClass = "DRUID",
        appliesTo = "selectedTargets",
        personal = false,
        optional = true,
        targeted = true,
        targetClasses = {"WARRIOR", "DRUID"},
        noneFoundText = "No druid found",
        dropdownClass = "DRUID",
    },
    -- Non-optional, always-on personal (self) buffs.
    {
        name = "Mage Armor",
        buffNames = {"Mage Armor", "Ice Armor"},
        appliesTo = "selfMage",
        personal = true,
    },
    {
        name = "Aspect of Hawk/Wolf/Viper",
        buffNames = {"Aspect of the Hawk", "Aspect of the Wolf", "Aspect of the Viper"},
        appliesTo = "selfHunter",
        personal = true,
    },
    {
        name = "Trueshot Aura",
        buffNames = {"Trueshot Aura"},
        appliesTo = "selfHunter",
        personal = true,
    },
    {
        name = "Demon Armor",
        buffNames = {"Demon Armor"},
        appliesTo = "selfWarlock",
        personal = true,
    },
    {
        name = "Lightning/Water/Earth Shield",
        buffNames = {"Lightning Shield", "Water Shield", "Earth Shield"},
        appliesTo = "selfShaman",
        personal = true,
    },
    {
        name = "Void/Fire/Fel/Wrathstone",
        buffNames = {"Voidstone", "Firestone", "Felstone", "Wrathstone"},
        appliesTo = "selfWarlock",
        personal = true,
    },
}
