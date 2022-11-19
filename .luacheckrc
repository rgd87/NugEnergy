std = "lua51"
max_line_length = false
exclude_files = {
    "**/libs",
}
only = {
    "011", -- syntax
    "1", -- globals
}
ignore = {
	"113/NugEnergy",
	"212/self",
	"11/SLASH_.*", -- slash handlers
	"1/[A-Z][A-Z][A-Z0-9_]+", -- three letter+ constants
}
globals = {
	-- WoW LUA API
    "math",
	"math.abs",
	"math.ceil",
	"math.floor",
    "floor",
	"math.max",
    "max",
	"math.min",
    "min",
	"math.mod",
    "string",
	"string.match",
    "string.gmatch",
    "string.format",
    "hooksecurefunc",
	"tinsert",
	"tremove",

    -- Addon globals
    "NugEnergy",
    "NugEnergyDB",
    "NugEnergyDB_Character",

    -- Libraries
    "LibStub",

	-- Frame globals
    "BackdropTemplateMixin",
	"SlashCmdList",
    "InterfaceOptionsFrame_OpenToCategory",
    "UIParent",

    -- WoW constants
    "Enum",

    -- WoW API
    "C_CVar",
    "C_NamePlate",
    "C_Spell",
    "C_Timer",
    "CombatLogGetCurrentEventInfo",
    "CreateFrame",
    "GetBuildInfo",
    "GetCVar",
    "GetLocale",
    "GetScreenHeight",
    "GetScreenWidth",
    "GetSpecialization",
    "GetSpecializationInfoByID",
    "GetSpecializationRole",
    "GetSpellCooldown",
    "GetSpellInfo",
    "GetSpellLink",
    "GetSpellTexture",
    "GetTime",
    "GetTimePreciseSec",
    "GetUnitSpeed",
    "InCombatLockdown",
    "IsSpellKnown",
    "IsStealthed",
    "PlaySound",
    "PlaySoundFile",
    "StopSound",
    "UnitAffectingCombat",
    "UnitAura",
    "UnitCanAttack",
    "UnitCastingInfo",
    "UnitClass",
    "UnitExists",
    "UnitGroupRolesAssigned",
    "UnitHealth",
    "UnitHealthMax",
    "UnitIsCorpse",
    "UnitIsDead",
    "UnitIsDeadOrGhost",
    "UnitIsEnemy",
    "UnitIsPlayer",
    "UnitIsUnit",
    "UnitLevel",
    "UnitPlayerControlled",
    "UnitPower",
    "UnitPowerMax",
    "UnitPowerType",
    "UnitReaction",
}
