local addonName, ns = ...

local textoutline = false
local spenderFeedback = true
local doFadeOut = true
local fadeAfter = 5
local fadeTime = 1
local onlyText = false
local shouldBeFull = false
local isFull = true
local isVertical

local APILevel = math.floor(select(4,GetBuildInfo())/10000)
local isClassic = APILevel <= 3
local GetSpecialization = isClassic and function() return 1 end or _G.GetSpecialization
local GetNumSpecializations = isClassic and function() return 1 end or _G.GetNumSpecializations
local GetSpecializationInfo = isClassic and function() return nil end or _G.GetSpecializationInfo

NugEnergy = CreateFrame("StatusBar","NugEnergy",UIParent)

NugEnergy:SetScript("OnEvent", function(self, event, ...)
    -- print(event, unpack{...})
    return self[event](self, event, ...)
end)

local LSM = LibStub("LibSharedMedia-3.0")

LSM:Register("statusbar", "Glamour7", [[Interface\AddOns\NugEnergy\statusbar.tga]])
LSM:Register("statusbar", "Glamour7NoArt", [[Interface\AddOns\NugEnergy\statusbar3.tga]])
LSM:Register("statusbar", "NugEnergyVertical", [[Interface\AddOns\NugEnergy\vstatusbar.tga]])

LSM:Register("font", "OpenSans Bold", [[Interface\AddOns\NugEnergy\OpenSans-Bold.ttf]], GetLocale() ~= "enUS" and 15)

local getStatusbar = function() return LSM:Fetch("statusbar", NugEnergy.db.profile.textureName) end
local getFont = function() return LSM:Fetch("font", NugEnergy.db.profile.fontName) end

-- local getStatusbar = function() return [[Interface\AddOns\NugEnergy\statusbar.tga]] end
-- local getFont = function() return [[Interface\AddOns\NugEnergy\Emblem.ttf]] end

local L = setmetatable({}, {
    __index = function(t, k)
        -- print(string.format('L["%s"] = ""',k:gsub("\n","\\n")));
        return k
    end,
    __call = function(t,k) return t[k] end,
})
NugEnergy.L = L


NugEnergy:RegisterEvent("PLAYER_LOGIN")
local UnitPower = UnitPower
local math_modf = math.modf
local math_abs = math.abs
local PowerFilter
local PowerTypeIndex
local ForcedToShow
local GetPower = UnitPower
local GetPowerMax = UnitPowerMax

local execute = false
local execute_range = nil
local upvalueInCombat = nil

local EPT = Enum.PowerType
local Enum_PowerType_Insanity = EPT.Insanity
local Enum_PowerType_Energy = EPT.Energy
local Enum_PowerType_RunicPower = EPT.RunicPower
local Enum_PowerType_LunarPower = EPT.LunarPower
local Enum_PowerType_Focus = EPT.Focus
local class = select(2,UnitClass("player"))
local UnitAura = UnitAura

local ColorArray = function(color) return {color.r, color.g, color.b} end

local defaults = {
    global = {
        classConfig = {
            ROGUE = { "EnergyRogue", "EnergyRogue", "EnergyRogue" },
            DRUID = { "ShapeshiftDruid", "ShapeshiftDruid", "ShapeshiftDruid", "ShapeshiftDruid" },
            PALADIN = { "Disabled", "Disabled", "Disabled" },
            MONK = { "EnergyBrewmaster", "Disabled", "EnergyWindwalker" },
            WARLOCK = { "Disabled", "Disabled", "Disabled" },
            DEMONHUNTER = { "FuryDemonHunter", "FuryDemonHunter" },
            DEATHKNIGHT = { "RunicPowerDeathstrike", "RunicPower", "RunicPower" },
            MAGE = { "MageMana", "Disabled", "Disabled" },
            WARRIOR = { "Disabled", "Disabled", "Disabled" },
            SHAMAN = { "Maelstrom", "Disabled", "Disabled" },
            HUNTER = { "Focus", "Focus", "Focus" },
            PRIEST = { "Disabled", "Disabled", "Insanity" },
        },
    },
    profile = {
        point = "CENTER",
        x = 0, y = 0,
        marks = {},
        focus = true,
        rage = true,
        mana = false,
        energy = true,
        fury = true,
        shards = false,
        runic = true,
        balance = true,
        insanity = true,
        maelstrom = true,
        -- powerTypeColors = true,
        -- focusColor = true

        hideText = false,
        hideBar = false,
        enableClassicTicker = true,
        spenderFeedback = not isClassic,
        borderType = "2PX",
        smoothing = true,
        smoothingSpeed = 6, -- 1 - 8

        width = 100,
        height = 30,
        normalColor = { 0.9, 0.1, 0.1 }, --1
        altColor = { 0.9, 0.168, 0.43 }, -- for dispatch and meta 2
        maxColor = { 131/255, 0.2, 0.2 }, --max color 3
        lowColor = { 141/255, 31/255, 62/255 }, --low color 4
        enableColorByPowerType = false,
        powerTypeColors = {
            ["ENERGY"] = ColorArray(PowerBarColor["ENERGY"]),
            ["FOCUS"] = ColorArray(PowerBarColor["FOCUS"]),
            ["RAGE"] = ColorArray(PowerBarColor["RAGE"]),
            ["RUNIC_POWER"] = ColorArray(PowerBarColor["RUNIC_POWER"]),
            ["LUNAR_POWER"] = ColorArray(PowerBarColor["LUNAR_POWER"]),
            ["FURY"] = ColorArray(PowerBarColor["FURY"]),
            ["INSANITY"] = ColorArray(PowerBarColor["INSANITY"]),
            ["MAELSTROM"] = ColorArray(PowerBarColor["MAELSTROM"]),
            ["MANA"] = ColorArray(PowerBarColor["MANA"]),
        },
        textureName = "Glamour7",
        fontName = "OpenSans Bold",
        fontSize = 25,
        textAlign = "END",
        textOffsetX = 0,
        textOffsetY = 0,
        textColor = {1,1,1, isClassic and 0.8 or 0.3},
        outOfCombatAlpha = 0,
        isVertical = false,

        twEnabled = true,
        twColor = { 0.15, 0.9, 0.4 }, -- tick window color
        twEnabledCappedOnly = true,
        twStart = 0.9,
        twLength = 0.4,
        twCrossfade = 0.15,
        twChangeColor = true,
        soundName = "none",
        soundNameCustom = "Interface\\AddOns\\YourSound.mp3",
        soundChannel = "SFX",
    }
}

if APILevel <= 3 then
    defaults.global.classConfig = {
        ROGUE = { "EnergyRogue", "EnergyRogue", "EnergyRogue" },
        DRUID = { "ShapeshiftDruidClassic", "ShapeshiftDruidClassic", "ShapeshiftDruidClassic", "ShapeshiftDruidClassic" },
        PALADIN = { "Disabled", "Disabled", "Disabled" },
        MONK = { "Disabled", "Disabled", "Disabled" },
        WARLOCK = { "Disabled", "Disabled", "Disabled" },
        DEMONHUNTER = { "Disabled", "Disabled" },
        DEATHKNIGHT = { "RunicPower", "RunicPower", "RunicPower" },
        MAGE = { "Disabled", "Disabled", "Disabled" },
        WARRIOR = { "RageWarriorClassic", "RageWarriorClassic", "RageWarriorClassic" },
        SHAMAN = { "Disabled", "Disabled", "Disabled" },
        HUNTER = { "Disabled", "Disabled", "Disabled" },
        PRIEST = { "Disabled", "Disabled", "Disabled" },
    }
end

local normalColor = defaults.profile.normalColor
local lowColor = defaults.profile.lowColor
local maxColor = defaults.profile.maxColor
local free_marks = {}


local pmult = 1
local function pixelperfect(size)
    return floor(size/pmult + 0.5)*pmult
end



function NugEnergy.PLAYER_LOGIN(self,event)
    _G.NugEnergyDB = _G.NugEnergyDB or {}
    self:DoMigrations(NugEnergyDB)
    self.db = LibStub("AceDB-3.0"):New("NugEnergyDB", defaults, "Default") -- Create a DB using defaults and using a shared default profile
    -- NugEnergyDB = self.db
    -- SetupDefaults(NugEnergyDB, defaults)

    local res = GetCVar("gxWindowedResolution")
    if res then
        local w,h = string.match(res, "(%d+)x(%d+)")
        pmult = (768/h) / UIParent:GetScale()
    end

    NugEnergy:UpdateUpvalues()

    NugEnergy:Initialize()

    SLASH_NUGENERGY1= "/nugenergy"
    SLASH_NUGENERGY2= "/nen"
    SlashCmdList["NUGENERGY"] = self.SlashCmd

    local f = CreateFrame('Frame', nil, InterfaceOptionsFrame)
        f:SetScript('OnShow', function(self)
            self:SetScript('OnShow', nil)

            if not NugEnergy.optionsPanel then
                NugEnergy.optionsPanel = NugEnergy:CreateGUI()
            end
        end)
end

function NugEnergy:UpdateUpvalues()
    isVertical = NugEnergy.db.profile.isVertical
    onlyText = NugEnergy.db.profile.hideBar
    spenderFeedback = NugEnergy.db.profile.spenderFeedback

    if APILevel <= 2 then
        self.ticker.UpdateUpvalues()
    end
end


local function FindAura(unit, spellID, filter)
    for i=1, 100 do
        -- rank will be removed in bfa
        local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, nameplateShowPersonal, auraSpellID = UnitAura(unit, i, filter)
        if not name then return nil end
        if spellID == auraSpellID then
            return name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, nameplateShowPersonal, auraSpellID
        end
    end
end

local GetPowerBy5 = function(unit)
    local p = UnitPower(unit)
    local pmax = UnitPowerMax(unit)
    -- p, p2, execute, shine, capped, insufficient
    return p, math_modf(p/5)*5, nil, nil, p == pmax, nil
end

local RageBarGetPower = function(shineZone, cappedZone, minLimit, throttleText)
    return function(unit)
        local p = UnitPower(unit, PowerTypeIndex)
        local pmax = UnitPowerMax(unit, PowerTypeIndex)
        local shine = shineZone and (p >= pmax-shineZone)
        -- local state
        -- if p >= pmax-10 then state = "CAPPED" end
        -- if GetSpecialization() == 3  p < 60 pmax-10
        local capped = p >= pmax-cappedZone
        local p2 = throttleText and math_modf(p/5)*5
        return p, p2, execute, shine, capped, (minLimit and p < minLimit)
    end
end

local ManaBarGetPower = function(shineZone, cappedZone, minLimit, throttleText)
    return function(unit)
        local p = UnitPower(unit, PowerTypeIndex)
        local pmax = UnitPowerMax(unit, PowerTypeIndex)
        local p2 = math.floor(p/pmax*100)
        return p, p2
    end
end

function NugEnergy.Initialize(self)
    -- self:RegisterEvent("UNIT_POWER_UPDATE")
    -- self:RegisterEvent("UNIT_MAXPOWER")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.PLAYER_REGEN_ENABLED = self.UPDATE_STEALTH
    self.PLAYER_REGEN_DISABLED = self.UPDATE_STEALTH

    if not self.initialized then
        self:Create()
        self.eventProxy = CreateFrame("Frame", nil, self)
        self.eventProxy:SetScript("OnEvent", function(proxy, event, ...)
            return proxy[event](self, event, ...)
        end)

        self.flags = setmetatable({}, {
            __index = function(t,k)
                return NugEnergy.db.profile[k]
            end
        })
        -- flags = self.flags

        self.initialized = true
        self:SetNormalColor()
    end

    self:RegisterEvent("SPELLS_CHANGED")
    self:SPELLS_CHANGED()


    --[===[
    if class == "ROGUE" and NugEnergy.db.profile.energy then
        -- PowerFilter = "ENERGY"
        -- self:SetNormalColor()
        -- PowerTypeIndex = Enum.PowerType.Energy
        -- shouldBeFull = true
        -- self:RegisterEvent("UPDATE_STEALTH")
        -- self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")

        -- self.SPELLS_CHANGED = function(self)
        --     local spec = GetSpecialization()
        --     self:UnregisterEvent("UNIT_HEALTH")
        --     self:UnregisterEvent("UNIT_AURA")
        --     self:RegisterEvent("PLAYER_TARGET_CHANGED")
        --     if spec == 1 and IsPlayerSpell(111240) then --blindside
        --         execute_range = 0.30
        --         self:RegisterUnitEvent("UNIT_HEALTH", "target")
        --         self:UnregisterEvent("UNIT_AURA")
        --     elseif spec == 3 then
        --         self:RegisterUnitEvent("UNIT_AURA", "player")
        --         self:UnregisterEvent("UNIT_HEALTH")
        --         self.UNIT_AURA = function(self, event, unit)
        --             execute = ( FindAura("player", 185422, "HELPFUL") ~= nil)
        --             self:UpdateEnergy()
        --         end
        --     else
        --         execute_range = nil
        --         execute = nil
        --         self:UnregisterEvent("PLAYER_TARGET_CHANGED")
        --     end
        -- end

        -- if isClassic and NugEnergy.db.profile.enableClassicTicker then
        --     GetPower = GetPower_ClassicRogueTicker(nil, 19, 0, false)
        --     ClassicTickerFrame:Enable()
        --     self:UpdateBarEffects() -- Will Disable Smoothing
        --     NugEnergy.UNIT_MAXPOWER = UNIT_MAXPOWER_ClassicTicker
        -- else
        --     GetPower = RageBarGetPower(nil, 5, nil, true)
        --     if ClassicTickerFrame.isEnabled then
        --         ClassicTickerFrame:Disable()
        --         self:UpdateBarEffects()
        --     end
        --     NugEnergy.UNIT_MAXPOWER = NugEnergy.NORMAL_UNIT_MAXPOWER
        --     self:RegisterEvent("SPELLS_CHANGED")
        --     self:SPELLS_CHANGED()
        -- end
        -- self:UNIT_MAXPOWER()

    elseif class == "MAGE" and NugEnergy.db.profile.mana then
        self:RegisterEvent("SPELLS_CHANGED")
        self.SPELLS_CHANGED = function(self)
            if GetSpecialization() == 1 and NugEnergy.db.profile.mana then
                PowerFilter = "MANA"
                PowerTypeIndex = Enum.PowerType.Mana
                GetPower = ManaBarGetPower()
                self:SetNormalColor()
                self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
                self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
            else
                self:Disable()
            end
            self:UPDATE_STEALTH()
        end
        self:SPELLS_CHANGED()

    elseif class == "PALADIN" and NugEnergy.db.profile.mana then
        self:RegisterEvent("SPELLS_CHANGED")
        self.SPELLS_CHANGED = function(self)
            if GetSpecialization() == 1 and NugEnergy.db.profile.mana then
                PowerFilter = "MANA"
                PowerTypeIndex = Enum.PowerType.Mana
                GetPower = ManaBarGetPower()
                self:SetNormalColor()
                self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
                self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
            else
                self:Disable()
            end
            self:UPDATE_STEALTH()
        end
        self:SPELLS_CHANGED()

    elseif class == "PRIEST" and NugEnergy.db.profile.insanity then
        local voidform = false
        local dpCost = 50
        self.UNIT_AURA = function(self, event, unit)
            voidform = ( FindAura("player", 194249, "HELPFUL") ~= nil)
            self:UpdateEnergy()
        end
        self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
        self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")

        self:RegisterEvent("SPELLS_CHANGED")
        self.SPELLS_CHANGED = function(self)
            if GetSpecialization() == 3 then
                PowerFilter = "INSANITY"
                PowerTypeIndex = Enum.PowerType.Insanity
                GetPower = RageBarGetPower(30, 10, dpCost)
                self:SetNormalColor()
                self:RegisterUnitEvent("UNIT_AURA", "player")
            elseif NugEnergy.db.profile.mana then
                PowerFilter = "MANA"
                PowerTypeIndex = Enum.PowerType.Mana
                GetPower = ManaBarGetPower()
                self:SetNormalColor()
                self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
                self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
                self:UnregisterEvent("UNIT_AURA");
            else
                self:Disable()
            end
            self:UPDATE_STEALTH()
        end
        self:SPELLS_CHANGED()
    elseif class == "DRUID" then
        self:RegisterEvent("UNIT_DISPLAYPOWER")
        self:RegisterEvent("UPDATE_STEALTH")

        self:SetScript("OnUpdate",self.UpdateEnergy)
        self.UNIT_DISPLAYPOWER = function(self)
            local newPowerType = select(2,UnitPowerType("player"))
            shouldBeFull = false

            -- restore to original MAXPOWER in case it was switched for classic energy
            NugEnergy.UNIT_MAXPOWER = NugEnergy.NORMAL_UNIT_MAXPOWER
            if newPowerType == "ENERGY" and NugEnergy.db.profile.energy then
                PowerFilter = "ENERGY"
                PowerTypeIndex = Enum.PowerType.Energy
                self:SetNormalColor()
                shouldBeFull = true
                self:RegisterEvent("UNIT_POWER_UPDATE")
                self:RegisterEvent("UNIT_MAXPOWER")
                self.PLAYER_REGEN_ENABLED = self.UPDATE_STEALTH
                self.PLAYER_REGEN_DISABLED = self.UPDATE_STEALTH
                -- self.UPDATE_STEALTH = self.__UPDATE_STEALTH
                -- self.UpdateEnergy = self.__UpdateEnergy
                if isClassic and NugEnergy.db.profile.enableClassicTicker then
                    GetPower = GetPower_ClassicRogueTicker(nil, 19, 0, false)
                    NugEnergy.UNIT_MAXPOWER = UNIT_MAXPOWER_ClassicTicker
                    ClassicTickerFrame:Enable()
                    self:UpdateBarEffects()
                else
                    GetPower = RageBarGetPower(nil, 5, nil, true)
                    if ClassicTickerFrame.isEnabled then
                        ClassicTickerFrame:Disable()
                        self:UpdateBarEffects()
                    end
                end
                self:UNIT_MAXPOWER()
                self:RegisterEvent("PLAYER_REGEN_DISABLED")
                self:UPDATE_STEALTH()
                self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
            elseif newPowerType =="RAGE" and NugEnergy.db.profile.rage then
                PowerFilter = "RAGE"
                PowerTypeIndex = Enum.PowerType.Rage
                self:SetNormalColor()
                self:RegisterEvent("UNIT_POWER_UPDATE")
                self:RegisterEvent("UNIT_MAXPOWER")
                self.PLAYER_REGEN_ENABLED = self.UPDATE_STEALTH
                self.PLAYER_REGEN_DISABLED = self.UPDATE_STEALTH
                -- self.UPDATE_STEALTH = self.__UPDATE_STEALTH
                -- self.UpdateEnergy = self.__UpdateEnergy
                GetPower = RageBarGetPower(30, 10, 45)
                self:RegisterEvent("PLAYER_REGEN_DISABLED")
                self:UnregisterEvent("UNIT_POWER_FREQUENT")
                self:UNIT_MAXPOWER()
                self:UPDATE_STEALTH()
            elseif GetSpecialization() == 1 and NugEnergy.db.profile.balance then
                self:RegisterEvent("UNIT_POWER_UPDATE")
                self:RegisterEvent("UNIT_MAXPOWER")
                GetPower = RageBarGetPower(30, 10, 40)
                PowerFilter = "LUNAR_POWER"
                PowerTypeIndex = Enum.PowerType.LunarPower
                self:SetNormalColor()
                self.PLAYER_REGEN_ENABLED = self.UPDATE_STEALTH
                self.PLAYER_REGEN_DISABLED = self.UPDATE_STEALTH
                -- self.UPDATE_STEALTH = self.__UPDATE_STEALTH
                -- self.UpdateEnergy = self.__UpdateEnergy
                self:RegisterEvent("PLAYER_REGEN_DISABLED")
                self:UNIT_MAXPOWER()
                self:UPDATE_STEALTH()
            elseif NugEnergy.db.profile.mana then
                PowerFilter = "MANA"
                PowerTypeIndex = Enum.PowerType.Mana
                GetPower = ManaBarGetPower()
                self:SetNormalColor()
                self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
                self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
                self:UnregisterEvent("UNIT_AURA");
                self:UPDATE_STEALTH()
            else
                self:Disable()
                self:UPDATE_STEALTH()
            end
            self:UpdateEnergy()
        end
        self:UNIT_DISPLAYPOWER()

        self.SPELLS_CHANGED = self.UNIT_DISPLAYPOWER
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("SPELLS_CHANGED")
        self.PLAYER_ENTERING_WORLD = function(self)
            C_Timer.After(2, function() self:UNIT_DISPLAYPOWER() end)
        end

    elseif class == "DEMONHUNTER" and NugEnergy.db.profile.fury then
        self:RegisterEvent("UNIT_POWER_FREQUENT")
        GetPower = RageBarGetPower(30, 10)
        PowerFilter = "FURY"
        PowerTypeIndex = Enum.PowerType.Fury
        self:SetNormalColor()
        self:UpdateEnergy()

    elseif class == "MONK" and NugEnergy.db.profile.energy then
        self:RegisterEvent("UNIT_DISPLAYPOWER")
        self.UNIT_DISPLAYPOWER = function(self)
            local newPowerType = select(2,UnitPowerType("player"))
            if newPowerType == "ENERGY" then
                PowerFilter = "ENERGY"
                PowerTypeIndex = Enum.PowerType.Energy
                self:SetNormalColor()
                shouldBeFull = true
                -- GetPower = GetPowerBy5
                -- GetPower = function(unit)
                --     local p, p2 = GetPowerBy5(unit)
                --     local pmax = UnitPowerMax(unit)
                --     -- local shine = p >= pmax-30
                --     local capped = p == pmax
                --     local insufficient
                --     if p < 50 and GetSpecialization() == 3 then insufficient = true end
                --     return p, p2, execute, shine, capped, insufficient
                -- end
                if GetSpecialization() == 3 then
                    GetPower = RageBarGetPower(-1, 5, 50, true)
                else
                    GetPower = RageBarGetPower(10, 5, 25, true)
                end

                self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
                self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
                self:RegisterEvent("PLAYER_REGEN_DISABLED")
            elseif NugEnergy.db.profile.mana then
                PowerFilter = "MANA"
                PowerTypeIndex = Enum.PowerType.Mana
                GetPower = ManaBarGetPower()
                self:SetNormalColor()
                self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
                self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
                self:RegisterEvent("PLAYER_REGEN_DISABLED")
            else
                self:Disable()
            end
            self:UPDATE_STEALTH()
        end
        self:UNIT_DISPLAYPOWER()

    --[[
    elseif class == "WARLOCK" and NugEnergy.db.profile.shards then
        self:RegisterEvent("SPELLS_CHANGED")
        self.SPELLS_CHANGED = function(self)
            local spec = GetSpecialization()
            local ShardsPowerTypeIndex = Enum.PowerType.SoulShards
            -- GetPower = function(unit) return UnitPower(unit, SPELL_POWER_SOUL_SHARDS) end
            GetPower = function(unit)
                local p = UnitPower(unit, ShardsPowerTypeIndex, true)
                local pmax = UnitPowerMax(unit, ShardsPowerTypeIndex, true)
                -- p, p2, execute, shine, capped, insufficient
                return p, math_modf(p/10), nil, nil, p == pmax, nil
            end
            GetPowerMax = function(unit) return UnitPowerMax(unit, ShardsPowerTypeIndex, true) end
            PowerFilter = "SOUL_SHARDS"
        end
        self:SPELLS_CHANGED()
    ]]
    elseif class == "DEATHKNIGHT" and NugEnergy.db.profile.runic then
        PowerFilter = "RUNIC_POWER"
        PowerTypeIndex = Enum.PowerType.RunicPower
        self:SetNormalColor()

        local MakeGetPowerUsableSpell = function(shineZone, cappedZone, minCheckSpellID, throttleText)
            return function(unit)
                local p = UnitPower(unit, PowerTypeIndex)
                local pmax = UnitPowerMax(unit, PowerTypeIndex)
                local _, nomana = IsUsableSpell(minCheckSpellID)
                local shine = shineZone and (p >= pmax-shineZone)
                local capped = p >= pmax-cappedZone
                local p2 = throttleText and math_modf(p/5)*5
                return p, p2, execute, shine, capped, nomana
            end
        end

        self:RegisterEvent("SPELLS_CHANGED")
        self.SPELLS_CHANGED = function(self)
            self:UnregisterEvent("UNIT_AURA")
            if GetSpecialization() == 1 then
                GetPower = MakeGetPowerUsableSpell(30, 10, 49998, nil)
                self:RegisterUnitEvent("UNIT_AURA", "player")
                self.UNIT_AURA = self.UpdateEnergy
            elseif GetSpecialization() == 2 then
                GetPower = RageBarGetPower(30, 10, 25, nil)
            else
                GetPower = RageBarGetPower(30, 10, nil, nil)
            end
        end
        self:SPELLS_CHANGED()

    elseif class == "WARRIOR" and NugEnergy.db.profile.rage then
        PowerFilter = "RAGE"
        PowerTypeIndex = Enum.PowerType.Rage
        self:SetNormalColor()

        self:RegisterEvent("SPELLS_CHANGED")
        self.SPELLS_CHANGED = function(self)
            local spec = GetSpecialization()
            if spec == 1 then
                execute_range = IsPlayerSpell(281001) and 0.35 or 0.2 -- Arms Massacre
                GetPower = RageBarGetPower(30, 10, nil, nil)
                self:RegisterUnitEvent("UNIT_HEALTH", "target")
                self:RegisterEvent("PLAYER_TARGET_CHANGED")
            elseif spec == 2 then
                execute_range = IsPlayerSpell(206315) and 0.35 or 0.2 -- Fury Massacre
                local maxRage = UnitPowerMax("player", PowerTypeIndex)

                local rampageCost = 80
                GetPower = RageBarGetPower(maxRage-rampageCost, maxRage-rampageCost, nil, nil)

                self:RegisterUnitEvent("UNIT_HEALTH", "target")
                self:RegisterEvent("PLAYER_TARGET_CHANGED")
            else
                execute_range = nil
                execute = nil
                GetPower = RageBarGetPower(30, 10, 30, nil)
                self:UnregisterEvent("UNIT_HEALTH")
                self:UnregisterEvent("PLAYER_TARGET_CHANGED")
            end
        end
        self:SPELLS_CHANGED()

    elseif class == "HUNTER" and NugEnergy.db.profile.focus then
        PowerFilter = "FOCUS"
        PowerTypeIndex = Enum.PowerType.Focus
        self:SetNormalColor()
        shouldBeFull = true
        self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
        GetPower = GetPowerBy5

    elseif class == "SHAMAN" and NugEnergy.db.profile.maelstrom then
        PowerFilter = "MAELSTROM"
        PowerTypeIndex = Enum.PowerType.Maelstrom
        self:SetNormalColor()
        GetPower = RageBarGetPower(30, 10, 60)

        self:RegisterEvent("SPELLS_CHANGED")
        self.SPELLS_CHANGED = function(self)
            local spec = GetSpecialization()
            if spec == 1 then
                PowerFilter = "MAELSTROM"
                PowerTypeIndex = Enum.PowerType.Maelstrom
                self:RegisterEvent("UNIT_MAXPOWER")
                self:RegisterEvent("UNIT_POWER_FREQUENT");
                self:RegisterEvent("PLAYER_REGEN_DISABLED")
            elseif NugEnergy.db.profile.mana then
                PowerFilter = "MANA"
                PowerTypeIndex = Enum.PowerType.Mana
                GetPower = ManaBarGetPower()
                self:SetNormalColor()
                self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
                self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
                self:RegisterEvent("PLAYER_REGEN_DISABLED")
            else
                self:Disable()
            end
            self:UPDATE_STEALTH()
        end
        self:SPELLS_CHANGED()
    else
        self:UnregisterAllEvents()
        self:SetScript("OnUpdate", nil)
        self:Hide()
        return false
    end

    ]===]

    self:UPDATE_STEALTH()
    self:UpdateEnergy()
    return true
end


function NugEnergy.UNIT_POWER_UPDATE(self,event,unit,powertype)
    if powertype == PowerFilter then self:UpdateEnergy() end
end
NugEnergy.UNIT_POWER_FREQUENT = NugEnergy.UNIT_POWER_UPDATE
function NugEnergy.UpdateEnergy(self, elapsed)
    local p, p2, _, shine, capped, insufficient = GetPower("player")
    local wasFull = isFull
    isFull = p == GetPowerMax("player", PowerTypeIndex)
    if isFull ~= wasFull then
        NugEnergy:UPDATE_STEALTH(nil, true)
    end

    p2 = p2 or p
    self.text:SetText(p2)
    if not onlyText then
        if shine and upvalueInCombat then
            -- self.glow:Show()
            if not self.glow:IsPlaying() then self.glow:Play() end
        else
            -- self.glow:Hide()
            self.glow:Stop()
        end
        local c
        if capped then
            c = maxColor
            self.glowanim:SetDuration(0.15)
        elseif execute then
            c = NugEnergy.db.profile.altColor
            self.glowanim:SetDuration(0.3)
        elseif insufficient then
            c = lowColor
            self.glowanim:SetDuration(0.3)
        else
            c = normalColor
            self.glowanim:SetDuration(0.3)
        end
        -- self.spentBar:SetColor(unpack(c))
        self:SetColor(unpack(c))

        if APILevel <= 2 and PowerTypeIndex == Enum_PowerType_Energy then
            self:ColorTickWindow(capped, c)
        end

        self:SetValue(p)
        --if self.marks[p] then self:PlaySpell(self.marks[p]) end
        if self.marks[p] then self.marks[p].shine:Play() end
    end
end
NugEnergy.Update = NugEnergy.UpdateEnergy
NugEnergy.__UpdateEnergy = NugEnergy.UpdateEnergy

-- local idleSince = nil
-- function NugEnergy.UpdateEclipseEnergy(self)
--     local p = UnitPower( "player", SPELL_POWER_ECLIPSE )
--     local mp = UnitPowerMax( "player", SPELL_POWER_ECLIPSE )
--     local absp = math.abs(p)
--     self.text:SetText(absp)
--     if not onlyText then
--         if p <= 0 then
--             self:SetStatusBarColor(unpack(lunar))
--             self.bg:SetVertexColor(lunar[1]*.5,lunar[2]*.5,lunar[3]*.5)
--         else
--             self:SetStatusBarColor(unpack(solar))
--             self.bg:SetVertexColor(solar[1]*.5,solar[2]*.5,solar[3]*.5)
--         end
--         self:SetValue(absp)
--     end
--     if p == 0 and not UnitAffectingCombat("player") then
--         if not idleSince then
--             idleSince = GetTime()
--         else
--             if idleSince < GetTime()-3 then
--                 self:Hide()
--                 idleSince = nil
--             end
--         end
--     else
--         idleSince = nil
--     end
-- end

function NugEnergy:Disable()
    PowerFilter = nil
    PowerTypeIndex = nil
    self:UnregisterEvent("UNIT_POWER_UPDATE")
    self:UnregisterEvent("UNIT_MAXPOWER")
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    self:Hide()
end

function NugEnergy.UNIT_HEALTH(self, event, unit)
    if unit ~= "target" then return end
    local uhm = UnitHealthMax(unit)
    if uhm == 0 then uhm = 1 end
    if execute_range then
        execute = UnitHealth(unit)/uhm < execute_range
    else
        execute = false
    end
    self:UpdateEnergy()
end

function NugEnergy.PLAYER_TARGET_CHANGED(self,event)
    if UnitExists('target') then
        self.UNIT_HEALTH(self,event,"target")
    end
end


-- function NugEnergy.UNIT_MAXPOWER(self)
--     self:SetMinMaxValues(0,GetPowerMax("player", PowerTypeIndex))
--     if not self.marks then return end
--     for _, mark in pairs(self.marks) do
--         mark:Update()
--     end
-- end

local fader = CreateFrame("Frame", nil, NugEnergy)
NugEnergy.fader = fader
local HideTimer = function(self, time)
    self.OnUpdateCounter = (self.OnUpdateCounter or 0) + time
    if self.OnUpdateCounter < fadeAfter then return end

    local nen = self:GetParent()
    local p = fadeTime - ((self.OnUpdateCounter - fadeAfter) / fadeTime)
    -- if p < 0 then p = 0 end
    -- local ooca = NugEnergy.db.profile.outOfCombatAlpha
    -- local a = ooca + ((1 - ooca) * p)
    local pA = NugEnergy.db.profile.outOfCombatAlpha
    local rA = 1 - NugEnergy.db.profile.outOfCombatAlpha
    local a = pA + (p*rA)
    nen:SetAlpha(a)
    if self.OnUpdateCounter >= fadeAfter + fadeTime then
        if nen:GetAlpha() <= 0.03 then
            nen:Hide()
        end
        NugEnergy:StopHiding()
        self.OnUpdateCounter = 0
    end
end
function NugEnergy:StartHiding()
    self:Show()
    if (not self.hiding)  then
        fader:SetScript("OnUpdate", HideTimer)
        fader.OnUpdateCounter = 0
        self.hiding = true
    end
end

function NugEnergy:StopHiding()
    -- if self.hiding then
        fader:SetScript("OnUpdate", nil)
        fader.OnUpdateCounter = 0
        self.hiding = false
    -- end
end

function NugEnergy.UPDATE_STEALTH(self, event, fromUpdateEnergy)
    self:UpdateVisibility()
end

function NugEnergy:UpdateVisibility()
    if self.isDisabled then self:Hide(); return end

    local inCombat = UnitAffectingCombat("player")
    upvalueInCombat = inCombat
    if (inCombat or
        ((class == "ROGUE" or class == "DRUID") and IsStealthed() and (self.ticker.isEnabled or (shouldBeFull and not isFull))) or
        ForcedToShow)
        and PowerFilter
    then
        -- self:UNIT_MAXPOWER()
        self:UpdateEnergy()
        self:StopHiding()
        self:SetAlpha(1)
        self:Show()
    elseif doFadeOut and self:IsVisible() and self:GetAlpha() > NugEnergy.db.profile.outOfCombatAlpha and PowerFilter then
        self:StartHiding()
    elseif NugEnergy.db.profile.outOfCombatAlpha > 0 and PowerFilter then
        self:SetAlpha(NugEnergy.db.profile.outOfCombatAlpha)
        self:Show()
    else
        self:Hide()
    end
end

function NugEnergy.ReconfigureMarks(self)
    -- local spec_marks = NugEnergy.db.profile_Character.marks[GetSpecialization() or 0]
    -- for at, frame in pairs(NugEnergy.marks) do
    --     frame:Hide()
    --     table.insert(free_marks, frame)
    --     NugEnergy.marks[at] = nil
    --     -- print("Hiding", at)
    -- end
    -- for at in pairs(spec_marks) do
    --     -- print("Showing", at)
    --     NugEnergy:CreateMark(at)
    -- end
    -- -- NugEnergy:RealignMarks()
end


local function rgb2hsv (r, g, b)
    local rabs, gabs, babs, rr, gg, bb, h, s, v, diff, diffc, percentRoundFn
    rabs = r
    gabs = g
    babs = b
    v = math.max(rabs, gabs, babs)
    diff = v - math.min(rabs, gabs, babs);
    diffc = function(c) return (v - c) / 6 / diff + 1 / 2 end
    -- percentRoundFn = function(num) return math.floor(num * 100) / 100 end
    if (diff == 0) then
        h = 0
        s = 0
    else
        s = diff / v;
        rr = diffc(rabs);
        gg = diffc(gabs);
        bb = diffc(babs);

        if (rabs == v) then
            h = bb - gg;
        elseif (gabs == v) then
            h = (1 / 3) + rr - bb;
        elseif (babs == v) then
            h = (2 / 3) + gg - rr;
        end
        if (h < 0) then
            h = h + 1;
        elseif (h > 1) then
            h = h - 1;
        end
    end
    return h, s, v
end

local function hsv2rgb(h,s,v)
    local r,g,b
    local i = math.floor(h * 6);
    local f = h * 6 - i;
    local p = v * (1 - s);
    local q = v * (1 - f * s);
    local t = v * (1 - (1 - f) * s);
    local rem = i % 6
    if rem == 0 then
        r = v; g = t; b = p;
    elseif rem == 1 then
        r = q; g = v; b = p;
    elseif rem == 2 then
        r = p; g = v; b = t;
    elseif rem == 3 then
        r = p; g = q; b = v;
    elseif rem == 4 then
        r = t; g = p; b = v;
    elseif rem == 5 then
        r = v; g = p; b = q;
    end

    return r,g,b
end

local function hsv_shift(src, hm,sm,vm)
    local r,g,b = unpack(src)
    local h,s,v = rgb2hsv(r,g,b)

    -- rollover on hue
    local h2 = h + hm
    if h2 < 0 then h2 = h2 + 1 end
    if h2 > 1 then h2 = h2 - 1 end

    local s2 = s + sm
    if s2 < 0 then s2 = 0 end
    if s2 > 1 then s2 = 1 end

    local v2 = v + vm
    if v2 < 0 then v2 = 0 end
    if v2 > 1 then v2 = 1 end

    local r2,g2,b2 = hsv2rgb(h2, s2, v2)

    return r2, g2, b2
end


function NugEnergy:SetNormalColor()
    if NugEnergy.db.profile.enableColorByPowerType and PowerFilter then
        normalColor = NugEnergy.db.profile.powerTypeColors[PowerFilter]
        lowColor = { hsv_shift(normalColor, -0.07, -0.22, -0.3) }
        maxColor = { hsv_shift(normalColor, 0, -0.3, -0.4) }
    else
        normalColor = NugEnergy.db.profile.normalColor
        lowColor = NugEnergy.db.profile.lowColor
        maxColor = NugEnergy.db.profile.maxColor
    end
end

function NugEnergy:Resize()
    local f = self
    local width = NugEnergy.db.profile.width
    local height = NugEnergy.db.profile.height
    local text = f.text
    if isVertical then
        height, width = width, height
        f:SetWidth(width)
        f:SetHeight(height)

        f:SetOrientation("VERTICAL")

        if not onlyText then
            f.spark:ClearAllPoints()
            f.spark:SetWidth(width)
            f.spark:SetHeight(width*2)
            f.spark:SetTexCoord(1,1,0,1,1,0,0,0)
        end

        text:ClearAllPoints()
        local textAlign = NugEnergy.db.profile.textAlign
        if textAlign == "END" then
            text:SetPoint("TOP", f, "TOP", 0+NugEnergy.db.profile.textOffsetX, 0+NugEnergy.db.profile.textOffsetY)
            text:SetJustifyV("TOP")
        elseif textAlign == "CENTER" then
            text:SetPoint("CENTER", f, "CENTER", 0+NugEnergy.db.profile.textOffsetX, 0+NugEnergy.db.profile.textOffsetY)
            text:SetJustifyV("CENTER")
        elseif textAlign == "START" then
            text:SetPoint("BOTTOM", f, "BOTTOM", 0+NugEnergy.db.profile.textOffsetX, 0+NugEnergy.db.profile.textOffsetY)
            text:SetJustifyV("BOTTOM")
        end

        text:SetJustifyH("CENTER")

    else
        f:SetWidth(width)
        f:SetHeight(height)

        f:SetOrientation("HORIZONTAL")

        if not onlyText then
            f.spark:ClearAllPoints()
            f.spark:SetTexCoord(0,1,0,1)
            f.spark:SetWidth(height*2)
            f.spark:SetHeight(height)
        end

        text:ClearAllPoints()
        local textAlign = NugEnergy.db.profile.textAlign
        if textAlign == "END" then
            text:SetPoint("RIGHT", f, "RIGHT", -7+NugEnergy.db.profile.textOffsetX, -2+NugEnergy.db.profile.textOffsetY)
            text:SetJustifyH("RIGHT")
        elseif textAlign == "CENTER" then
            text:SetPoint("CENTER", f, "CENTER", 0+NugEnergy.db.profile.textOffsetX, -2+NugEnergy.db.profile.textOffsetY)
            text:SetJustifyH("CENTER")
        elseif textAlign == "START" then
            text:SetPoint("LEFT", f, "LEFT", 7+NugEnergy.db.profile.textOffsetX, -2+NugEnergy.db.profile.textOffsetY)
            text:SetJustifyH("LEFT")
        end

        text:SetJustifyV("CENTER")
    end

    if not onlyText then
        f.spentBar:ClearAllPoints()
        self:UpdateEnergy()

        local tex = getStatusbar()
        f:SetStatusBarTexture(tex)
        f.bg:SetTexture(tex)
        f.spentBar:SetTexture(tex)

        f.spentBar:SetWidth(width)
        f.spentBar:SetHeight(height)
    end
end

function NugEnergy:ResizeText()
    local text = self.text
    local font = getFont()
    local fontSize = NugEnergy.db.profile.fontSize
    text:SetFont(font,fontSize, textoutline and "OUTLINE")
    local r,g,b,a = unpack(NugEnergy.db.profile.textColor)
    text:SetTextColor(r,g,b)
    text:SetAlpha(a)
    if NugEnergy.db.profile.hideText then
        text:Hide()
    else
        text:Show()
    end
end

local SparkSetValue = function(self, v)
    local min, max = self:GetMinMaxValues()
    local total = max-min
    local p
    if total == 0 then
        p = 0
    else
        p = (v-min)/(max-min)
        if p > 1 then p = 1 end
    end
    local len = p*self:GetWidth()
    self.spark:SetPoint("CENTER", self, "LEFT", len, 0)
    return self:NormalSetValue(v)
end

function NugEnergy:UpdateFrameBorder()
    local borderType = NugEnergy.db.profile.borderType

    if self.border then self.border:Hide() end
    if self.backdrop then self.backdrop:Hide() end

    if borderType == "2PX" then
        self.backdrop = self.backdrop or self:CreateTexture(nil, "BACKGROUND", nil, -2)
        local backdrop = self.backdrop
        local offset = pixelperfect(2)
        backdrop:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        backdrop:SetVertexColor(0,0,0, 0.5)
        backdrop:SetPoint("TOPLEFT", -offset, offset)
        backdrop:SetPoint("BOTTOMRIGHT", offset, -offset)
        backdrop:Show()

    elseif borderType == "1PX" then
        self.backdrop = self.backdrop or self:CreateTexture(nil, "BACKGROUND", nil, -2)
        local backdrop = self.backdrop
        local offset = pixelperfect(1)
        backdrop:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        backdrop:SetVertexColor(0,0,0, 1)
        backdrop:SetPoint("TOPLEFT", -offset, offset)
        backdrop:SetPoint("BOTTOMRIGHT", offset, -offset)
        backdrop:Show()

    elseif borderType == "TOOLTIP" then
        self.border = self.border or CreateFrame("Frame", nil, self, BackdropTemplateMixin and "BackdropTemplate")
        local border = self.border
        border:SetPoint("TOPLEFT", -3, 3)
        border:SetPoint("BOTTOMRIGHT", 3, -3)
        border:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
            -- insets = {left = -5, right = -5, top = -5, bottom = -5},
        })
        border:SetBackdropBorderColor(0.55,0.55,0.55)
        border:Show()
    elseif borderType == "STATUSBAR" then
        self.border = self.border or CreateFrame("Frame", nil, self, BackdropTemplateMixin and "BackdropTemplate")
        local border = self.border
        border:SetPoint("TOPLEFT", -2, 3)
        border:SetPoint("BOTTOMRIGHT", 2, -3)
        border:SetBackdrop({
            edgeFile = "Interface\\AddOns\\NugEnergy\\border_statusbar", edgeSize = 8, tileEdge = false,
        })
        border:SetBackdropBorderColor(1,1,1)
        border:Show()
    elseif borderType == "3PX" then
        self.border = self.border or CreateFrame("Frame", nil, self, BackdropTemplateMixin and "BackdropTemplate")
        local border = self.border
        border:SetPoint("TOPLEFT", -2, 2)
        border:SetPoint("BOTTOMRIGHT", 2, -2)
        border:SetBackdrop({
            edgeFile = "Interface\\AddOns\\NugEnergy\\border_3px", edgeSize = 8, tileEdge = false,
        })
        border:SetBackdropBorderColor(0.4,0.4,0.4)
        border:Show()
    end
end

function NugEnergy.Create(self)
    local f = self
    local width = NugEnergy.db.profile.width
    local height = NugEnergy.db.profile.height
    if isVertical then
        height, width = width, height
        f:SetOrientation("VERTICAL")
    end
    f:SetWidth(width)
    f:SetHeight(height)

    if not onlyText then

    self:UpdateFrameBorder()

    local tex = getStatusbar()
    f:SetStatusBarTexture(tex)
    -- f:GetStatusBarTexture():SetDrawLayer("ARTWORK", 3)

    local bg = f:CreateTexture(nil,"BACKGROUND")
    bg:SetTexture(tex)
    bg:SetAllPoints(f)

    f.bg = bg

    local spark = f:CreateTexture(nil, "ARTWORK", nil, 4)
    spark:SetBlendMode("ADD")
    spark:SetTexture([[Interface\AddOns\NugEnergy\spark.tga]])
    if isVertical then
        spark:SetSize(f:GetWidth(), f:GetWidth()*2)
        spark:SetTexCoord(1,1,0,1,1,0,0,0)
    else
        spark:SetSize(f:GetHeight()*2, f:GetHeight())
    end
    spark:SetPoint("CENTER", f, "TOP",0,0)

    f.spark = spark

    local spentBar = f:CreateTexture(nil, "ARTWORK", 7)
    -- spentBar:SetTexture([[Interface\AddOns\NugEnergy\white.tga]])
    spentBar:SetTexture(tex)
    -- spentBar:SetVertexColor(unpack(color))
    spentBar:SetHeight(height*1)
    spentBar:SetWidth(width)

    spentBar.SetColor = function(self, r1,g1,b1)
        local r = math.min(1, r1 + 0.15)
        local g = math.min(1, g1 + 0.15)
        local b = math.min(1, b1 + 0.15)
        self:SetVertexColor(r,g,b)
    end
    -- spentBar:SetBlendMode("ADD")
    spentBar:SetPoint("LEFT", f, "LEFT",0,0)
    spentBar:SetAlpha(0)
    f.spentBar = spentBar

    f.SetColor = function(self, r,g,b,a)
        self:SetStatusBarColor(r,g,b,a)
        self.bg:SetVertexColor(r*0.3,g*0.3,b*0.3)
        self.spark:SetVertexColor(r,g,b)
        -- self.spentBar:SetColor(r,g,b)
        self.spentBar:SetVertexColor(r,g,b)
    end

    local color = NugEnergy.db.profile.normalColor
    f:SetColor(unpack(color))


    f.OriginalSetValue = f.OriginalSetValue or f.SetValue

    self:UpdateBarEffects()


    local trail = spentBar:CreateAnimationGroup()
    -- local sa1 = trail:CreateAnimation("Alpha")
    -- sa1:SetFromAlpha(0)
    -- sa1:SetToAlpha(1)
    -- sa1:SetSmoothing("OUT")
    -- sa1:SetDuration(0.1)
    -- sa1:SetOrder(1)

    local sa2 = trail:CreateAnimation("Alpha")
    sa2:SetFromAlpha(1)
    sa2:SetToAlpha(0)
    -- sa2:SetSmoothing("IN")
    sa2:SetDuration(0.6)
    sa2:SetOrder(1)

    -- local ta1 = trail:CreateAnimation("Translation")
    -- ta1:SetOffset(0, 8)
    -- ta1:SetSmoothing("OUT")
    -- ta1:SetDuration(0.2)
    -- ta1:SetOrder(1)

    -- local ta1 = trail:CreateAnimation("Translation")
    -- ta1:SetOffset(0, -38)
    -- ta1:SetSmoothing("IN")
    -- ta1:SetDuration(0.20)
    -- ta1:SetOrder(2)

    f.trail = trail
    f.marks = {}
    -- f:UNIT_MAXPOWER()
    -- NEW MARKS
    -- for p in pairs(NugEnergy.db.profile_Character.marks) do
    --     self:CreateMark(p)
    -- end
    NugEnergy:ReconfigureMarks()

    -- local glow = f:CreateTexture(nil,"OVERLAY")
    -- glow:SetAllPoints(f)
    -- glow:SetTexture([[Interface\AddOns\NugEnergy\white.tga]])
    -- glow:SetAlpha(0)

    -- local ag = glow:CreateAnimationGroup()
    -- ag:SetLooping("BOUNCE")
    -- local a1 = ag:CreateAnimation("Alpha")
    -- a1:SetChange(0.1)
    -- a1:SetDuration(0.2)
    -- a1:SetOrder(1)

    local at = CreateFrame("Frame", nil, f, BackdropTemplateMixin  and "BackdropTemplate")
    local border_backdrop = {
        edgeFile = "Interface\\Addons\\NugEnergy\\glow", tileEdge = true, edgeSize = 16,
        -- insets = {left = -16, right = -16, top = -16, bottom = -16},
    }
    at:SetBackdrop(border_backdrop)
    at:SetSize(64, 64)
    at:SetFrameStrata("BACKGROUND")
    at:SetBackdropBorderColor(1,0,0)
    at:SetPoint("TOPLEFT", -16, 16)
    at:SetPoint("BOTTOMRIGHT", 16, -16)
    at:SetAlpha(0)
    f.alertFrame = at

    local sag = at:CreateAnimationGroup()
    sag:SetLooping("BOUNCE")
    local sa1 = sag:CreateAnimation("Alpha")
    sa1:SetFromAlpha(0)
    sa1:SetToAlpha(1)
    sa1:SetDuration(0.3)
    sa1:SetOrder(1)
    -- local sa2 = sag:CreateAnimation("Alpha")
    -- sa2:SetChange(-1)
    -- sa2:SetDuration(0.5)
    -- sa2:SetSmoothing("OUT")
    -- sa2:SetOrder(2)
    --
    -- f.shine = sag

    self.glow = sag
    self.glowanim = sa1
    -- self.glowtex = glow





--~     -- MARKS
--~     local f2 = CreateFrame("Frame",nil,f)
--~     f2:SetWidth(height)--*.8
--~     f2:SetHeight(height)
--~     f2:SetBackdrop(backdrop)
--~     f2:SetBackdropColor(0,0,0,0.5)
--~     f2:SetAlpha(0)
--~     --f2:SetFrameStrata("BACKGROUND") --fall behind energy bar
--~     local icon = f2:CreateTexture(nil,"BACKGROUND")
--~     icon:SetTexCoord(.07, .93, .07, .93)
--~     icon:SetAllPoints(f2)
--~
--~     --local sht = f2:CreateTexture(nil,"OVERLAY")
--~     --sht:SetTexture([[Interface\AddOns\NugEnergy\white.tga]])
--~     --sht:SetAlpha(0.3)
--~     --sht:SetAllPoints(f)

--~     f2:SetPoint("RIGHT",f,"LEFT",-2,0)
--~
--~     local ag = f2:CreateAnimationGroup()
--~     local a1 = ag:CreateAnimation("Alpha")
--~     a1:SetChange(1)
--~     a1:SetDuration(0.3)
--~     a1:SetOrder(1)
--~
--~     local a2 = ag:CreateAnimation("Alpha")
--~     a2:SetChange(-1)
--~     a2:SetDuration(0.7)
--~     a2:SetOrder(2)
--~
--~     f.icon = icon
--~     f.ag = ag
--~
--~     f.PlaySpell = function(self,spellID)
--~         self.icon:SetTexture(select(3,GetSpellInfo(spellID)))
--~         self.ag:Play()
--~     end

    end -- endif not onlyText

    local pf = CreateFrame("Frame", nil, f)
    pf:SetFrameLevel(2)
    pf:SetAllPoints(f)

    local text = pf:CreateFontString(nil, "OVERLAY")
    local font = getFont()
    local fontSize = NugEnergy.db.profile.fontSize
    text:SetFont(font,fontSize, textoutline and "OUTLINE")

    local r,g,b,a = unpack(NugEnergy.db.profile.textColor)
    text:SetTextColor(r,g,b)
    text:SetAlpha(a)
    f.text = text

    NugEnergy:Resize()

    if NugEnergy.db.profile.hideText then
        text:Hide()
    else
        text:Show()
    end

    f:SetPoint(NugEnergy.db.profile.point, UIParent, NugEnergy.db.profile.point, NugEnergy.db.profile.x, NugEnergy.db.profile.y)

    local oocA = NugEnergy.db.profile.outOfCombatAlpha
    if oocA > 0 then
        f:SetAlpha(oocA)
    else
        f:Hide()
    end

    f:EnableMouse(false)
    f:RegisterForDrag("LeftButton")
    f:SetMovable(true)
    f:SetScript("OnDragStart",function(self) self:StartMoving() end)
    f:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing();
        local _
        _,_, NugEnergy.db.profile.point, NugEnergy.db.profile.x, NugEnergy.db.profile.y = self:GetPoint(1)
    end)
end

function NugEnergy:UpdateBarEffects(disableSmoothing)
    local f = self

    f.SetValue = f.OriginalSetValue

    if true then
        f.SetValueWithoutSpark = f.SetValue
        -- Spark Layer
        f.SetValue = function(self, new)
            local cur = self:GetValue()
            local min, max = self:GetMinMaxValues()
            local fwidth = self:GetWidth()
            local fheight = self:GetHeight()
            local total = max-min

            -- spark
            local p = 0
            if total > 0 then
                p = (new-min)/(max-min)
                if p > 1 then
                    p = 1
                end
                if p <= 0.07 then -- hide spark when it's close to left border
                    p = p - 0.2
                    if p < 0 then p = 0 end
                    local a = p*20
                    self.spark:SetAlpha(a)
                -- if p > 0.95 then
                --     local a = (1-p)*20
                --     self.spark:SetAlpha(a)
                else
                    self.spark:SetAlpha(1)
                end
            end
            if isVertical then
                self.spark:SetPoint("CENTER", self, "BOTTOM", 0, p*fheight)
            else
                self.spark:SetPoint("CENTER", self, "LEFT", p*fwidth, 0)
            end
            return self:SetValueWithoutSpark(new)
        end
    end

    if NugEnergy.db.profile.smoothing and not disableSmoothing then
        f.SetValueWithoutSmoothing = f.SetValue

        f.smoothTicker = f.smoothTicker or CreateFrame("Frame", nil, f)
        f.smoothTicker:Show()
        f.smoothTicker.parent = f
        local animationSpeed = 1 + 8 - NugEnergy.db.profile.smoothingSpeed
        f.smoothTicker:SetScript("OnUpdate", function(self)
            local value = self.smoothTargetValue
            local bar = self.parent
            local cur = bar:GetValue()
            if not value or cur == value then return end

            local threshold = self.threshold

            local new = cur + (value-cur)/animationSpeed
            bar:SetValueWithoutSmoothing(new)

            if cur == value or math_abs(new - value) < threshold then
                bar:SetValueWithoutSmoothing(value)
                self.smoothTargetValue = nil
            end
        end)

        f.SetValue = function(self, new)
            self.smoothTicker.smoothTargetValue = new
        end

        f._SetMinMaxValues = f._SetMinMaxValues or f.SetMinMaxValues

        f.SetMinMaxValues = function(self, min, max)
            local range = max - min
            self.smoothTicker.threshold = range/2000
            self:_SetMinMaxValues(min, max)
        end
    else
        if f.smoothTicker then f.smoothTicker:Hide() end
    end

    if NugEnergy.db.profile.spenderFeedback then
        f.SetValueWithoutSpenderFeedback = f.SetValue
        f.SetValue = function(self, new)
            local cur = self:GetValue()
            local min, max = self:GetMinMaxValues()
            local fwidth = self:GetWidth()
            local fheight = self:GetHeight()
            local total = max-min

            if spenderFeedback then
                local diff = new - cur
                if diff < 0 and math.abs(diff)/max > 0.1 then

                    local p1 = new/max
                    local pd = (-diff/max)


                    if isVertical then
                        local lpos = p1*fheight
                        local len = pd*fheight
                        self.spentBar:SetPoint("BOTTOM", self, "BOTTOM",0,lpos)
                        self.spentBar:SetTexCoord(0, 1, p1, p1+pd)
                        self.spentBar:SetHeight(len)
                    else
                        local lpos = p1*fwidth
                        local len = pd*fwidth
                        self.spentBar:SetPoint("LEFT", self, "LEFT",lpos,0)
                        self.spentBar:SetTexCoord(p1, p1+pd, 0, 1)
                        self.spentBar:SetWidth(len)
                    end
                    if self.trail:IsPlaying() then self.trail:Stop() end
                    self.trail:Play()
                    self.spentBar.currentValue = cur
                end
            end

            return self:SetValueWithoutSpenderFeedback(new)
        end
    end
end



local ParseOpts = function(str)
    local fields = {}
    for opt,args in string.gmatch(str,"(%w*)%s*=%s*([%w%,%-%_%.%:%\\%']+)") do
        fields[opt:lower()] = tonumber(args) or args
    end
    return fields
end

NugEnergy.Commands = {
    ["gui"] = function(v)
        if not NugEnergy.optionsPanel then
            NugEnergy.optionsPanel = NugEnergy:CreateGUI()
        end
        InterfaceOptionsFrame_OpenToCategory("NugEnergy")
        InterfaceOptionsFrame_OpenToCategory("NugEnergy")
    end,
    ["unlock"] = function(v)
        NugEnergy:EnableMouse(true)
        ForcedToShow = true
        NugEnergy:UPDATE_STEALTH()
    end,
    ["lock"] = function(v)
        NugEnergy:EnableMouse(false)
        ForcedToShow = nil
        NugEnergy:UPDATE_STEALTH()
    end,
    ["markadd"] = function(v)
        local p = ParseOpts(v)
        local at = p["at"]
        if at then
            NugEnergy.db.profile_Character.marks[GetSpecialization() or 0][at] = true
            NugEnergy:CreateMark(at)
        end
    end,
    ["markdel"] = function(v)
        local p = ParseOpts(v)
        local at = p["at"]
        if at then
            NugEnergy.db.profile_Character.marks[GetSpecialization() or 0][at] = nil
            NugEnergy:ReconfigureMarks()
            -- NugEnergy.marks[at]:Hide()
            -- NugEnergy.marks[at] = nil
        end
    end,
    ["marklist"] = function(v)
        print("Current marks:")
        for p in pairs(NugEnergy.db.profile.marks) do
            print(string.format("    @%d",p))
        end
    end,
    ["reset"] = function(v)
        NugEnergy:SetPoint("CENTER",UIParent,"CENTER",0,0)
    end,
    ["vertical"] = function(v)
        NugEnergy.db.profile.isVertical = not NugEnergy.db.profile.isVertical
        isVertical = NugEnergy.db.profile.isVertical
        NugEnergy:Resize()
    end,
    ["rage"] = function(v)
        NugEnergy.db.profile.rage = not NugEnergy.db.profile.rage
        NugEnergy:Initialize()
    end,
    ["energy"] = function(v)
        NugEnergy.db.profile.energy = not NugEnergy.db.profile.energy
        NugEnergy:Initialize()
    end,
    ["focus"] = function(v)
        NugEnergy.db.profile.focus = not NugEnergy.db.profile.focus
        NugEnergy:Initialize()
    end,
    ["shards"] = function(v)
        NugEnergy.db.profile.shards = not NugEnergy.db.profile.shards
        NugEnergy:Initialize()
    end,
    ["runic"] = function(v)
        NugEnergy.db.profile.runic = not NugEnergy.db.profile.runic
        NugEnergy:Initialize()
    end,
    ["balance"] = function(v)
        NugEnergy.db.profile.balance = not NugEnergy.db.profile.balance
        NugEnergy:Initialize()
    end,
    ["insanity"] = function(v)
        NugEnergy.db.profile.insanity = not NugEnergy.db.profile.insanity
        NugEnergy:Initialize()
    end,
    ["mana"] = function(v)
        NugEnergy.db.profile.mana = not NugEnergy.db.profile.mana
        NugEnergy:Initialize()
    end,
    ["fury"] = function(v)
        NugEnergy.db.profile.fury = not NugEnergy.db.profile.fury
        NugEnergy:Initialize()
    end,
    ["maelstrom"] = function(v)
        NugEnergy.db.profile.maelstrom = not NugEnergy.db.profile.maelstrom
        NugEnergy:Initialize()
    end,
}

local helpMessage = {
    "|cff00ffbb/nen gui|r",
    "|cff00ff00/nen lock|r",
    "|cff00ff00/nen unlock|r",
    "|cff00ff00/nen reset|r",
    "|cff00ff00/nen focus|r",
    "|cff00ff00/nen monk|r",
    "|cff00ff00/nen fury|r",
    "|cff00ff00/nen insanity|r",
    "|cff00ff00/nen runic|r",
    "|cff00ff00/nen balance|r",
    "|cff00ff00/nen shards|r",
}

function NugEnergy.SlashCmd(msg)
    local k,v = string.match(msg, "([%w%+%-%=]+) ?(.*)")
    if not k or k == "help" then
        print("Usage:")
        for k,v in ipairs(helpMessage) do
            print(" - ",v)
        end
    end
    if NugEnergy.Commands[k] then
        NugEnergy.Commands[k](v)
    end
end


local UpdateMark = function(self)
    local bar = self:GetParent()
    local min,max = bar:GetMinMaxValues()
    local pos = self.position / max * bar:GetWidth()
    self:SetPoint("CENTER",bar,"LEFT",pos,0)
end


function NugEnergy.CreateMark(self, at)
        if next(free_marks) then
            local frame = table.remove(free_marks)
            self.marks[at] = frame
            frame.position = at
            frame:Show()
            return
        end

        local m = CreateFrame("Frame",nil,self)
        m:SetWidth(2)
        m:SetHeight(self:GetHeight())
        m:SetFrameLevel(4)
        m:SetAlpha(0.6)

        local texture = m:CreateTexture(nil, "OVERLAY")
        texture:SetTexture("Interface\\AddOns\\NugEnergy\\mark")
        texture:SetVertexColor(1,1,1,0.3)
        texture:SetAllPoints(m)
        m.texture = texture

        local spark = m:CreateTexture(nil, "OVERLAY")
        spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        spark:SetAlpha(0)
        spark:SetWidth(20)
        spark:SetHeight(m:GetHeight()*2.7)
        spark:SetPoint("CENTER",m)
        spark:SetBlendMode('ADD')
        m.spark = spark

        local ag = spark:CreateAnimationGroup()
        local a1 = ag:CreateAnimation("Alpha")
        a1:SetFromAlpha(0)
        a1:SetToAlpha(1)
        a1:SetDuration(0.2)
        a1:SetOrder(1)
        local a2 = ag:CreateAnimation("Alpha")
        a1:SetFromAlpha(1)
        a1:SetToAlpha(0)
        a2:SetDuration(0.4)
        a2:SetOrder(2)

        m.shine = ag
        m.position = at
        m.Update = UpdateMark
        m:Update()
        m:Show()

        self.marks[at] = m

        return m
end


function NugEnergy:RealignMarks(t)
    local old_pos = {}
    for k,v in pairs(self.marks) do
        table.insert(old_pos, k)
    end
    local len = math.max(#t, #old_pos)
    for i=1,len do
        local v = old_pos[i]
        if not v then
            self:CreateMark(t[i])
        else
            local mark = self.marks[v]
            if not t[i] then
                mark:Hide()
            else
                local new = t[i]
                mark.position = new
                self.marks[v] = nil
                self.makrs[new] = mark
            end
        end
    end
end


function NugEnergy:NotifyGUI()
    if LibStub then
        local cfgreg = LibStub("AceConfigRegistry-3.0", true)
        if cfgreg then cfgreg:NotifyChange("NugEnergyOptions") end
    end
end

function ns.GetProfileList(db)
    local profiles = db:GetProfiles()
    local t = {}
    for i,v in ipairs(profiles) do
        t[v] = v
    end
    return t
end
local GetProfileList = ns.GetProfileList

function NugEnergy:CreateGUI()
    local opt = {
        type = 'group',
        name = "NugEnergy Settings",
        order = 1,
        args = {
            configSelection = {
                type = "group",
                name = " ",
                guiInline = true,
                order = 0.5,
                args = {
                }
            },
            unlock = {
                name = L"Unlock",
                type = "execute",
                desc = "Unlock anchor for dragging",
                func = function() NugEnergy.Commands.unlock() end,
                order = 1,
            },
            lock = {
                name = L"Lock",
                type = "execute",
                desc = "Lock anchor",
                func = function() NugEnergy.Commands.lock() end,
                order = 2,
            },
            resetToDefault = {
                name = L"Restore Defaults",
                type = 'execute',
                func = function()
                    NugEnergy.db:Reset()
                    NugEnergy:Resize()
                    NugEnergy:ResizeText()
                end,
                order = 3,
            },
            anchors = {
                type = "group",
                name = " ",
                guiInline = true,
                order = 4,
                args = {
                    colorGroup = {
                        type = "group",
                        name = "",
                        order = 1,
                        args = {
                            classColor = {
                                name = L"Normal Color",
                                type = 'color',
                                disabled = function() return NugEnergy.db.profile.enableColorByPowerType end,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergy.db.profile.normalColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergy.db.profile.normalColor = {r,g,b}
                                    NugEnergy:SetNormalColor()
                                end,
                                order = 1,
                            },
                            customcolor2 = {
                                name = L"Alt Color",
                                type = 'color',
                                order = 2,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergy.db.profile.altColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergy.db.profile.altColor = {r,g,b}
                                    NugEnergy:SetNormalColor()
                                end,
                            },
                            customcolor3 = {
                                name = L"Max Color",
                                type = 'color',
                                disabled = function() return NugEnergy.db.profile.enableColorByPowerType end,
                                order = 3,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergy.db.profile.maxColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergy.db.profile.maxColor = {r,g,b}
                                    NugEnergy:SetNormalColor()
                                end,
                            },
                            customcolor4 = {
                                name = L"Insufficient Color",
                                type = 'color',
                                disabled = function() return NugEnergy.db.profile.enableColorByPowerType end,
                                order = 4,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergy.db.profile.lowColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergy.db.profile.lowColor = {r,g,b}
                                    NugEnergy:SetNormalColor()
                                end,
                            },
                            textColor = {
                                name = L"Text Color & Alpha",
                                type = 'color',
                                hasAlpha = true,
                                order = 5,
                                get = function(info)
                                    local r,g,b,a = unpack(NugEnergy.db.profile.textColor)
                                    return r,g,b,a
                                end,
                                set = function(info, r, g, b, a)
                                    NugEnergy.db.profile.textColor = {r,g,b, a}
                                    NugEnergy:ResizeText()
                                end,
                            },
                        },
                    },
                    ColorByPowerType = {
                        name = L"Color by Power Type",
                        type = "toggle",
                        order = 1.1,
                        get = function(info) return NugEnergy.db.profile.enableColorByPowerType end,
                        set = function(info, v)
                            NugEnergy.db.profile.enableColorByPowerType = not NugEnergy.db.profile.enableColorByPowerType
                            NugEnergy:SetNormalColor()
                        end
                    },
                    customColorGroup = {
                        type = "group",
                        name = "Custom Power Colors",
                        disabled = function() return not NugEnergy.db.profile.enableColorByPowerType end,
                        order = 1.2,
                        args = {
                            Energy = {
                                name = L"Energy",
                                type = 'color',
                                order = 1,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergy.db.profile.powerTypeColors["ENERGY"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergy.db.profile.powerTypeColors["ENERGY"] = {r,g,b}
                                    NugEnergy:SetNormalColor()
                                end,
                            },
                            Focus = {
                                name = L"Focus",
                                type = 'color',
                                order = 2,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergy.db.profile.powerTypeColors["FOCUS"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergy.db.profile.powerTypeColors["FOCUS"] = {r,g,b}
                                    NugEnergy:SetNormalColor()
                                end,
                            },
                            RAGE = {
                                name = L"Rage",
                                type = 'color',
                                order = 3,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergy.db.profile.powerTypeColors["RAGE"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergy.db.profile.powerTypeColors["RAGE"] = {r,g,b}
                                    NugEnergy:SetNormalColor()
                                end,
                            },
                            RUNIC_POWER = {
                                name = L"Runic Power",
                                type = 'color',
                                order = 4,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergy.db.profile.powerTypeColors["RUNIC_POWER"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergy.db.profile.powerTypeColors["RUNIC_POWER"] = {r,g,b}
                                    NugEnergy:SetNormalColor()
                                end,
                            },
                            LUNAR_POWER = {
                                name = L"Lunar Power",
                                type = 'color',
                                order = 5,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergy.db.profile.powerTypeColors["LUNAR_POWER"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergy.db.profile.powerTypeColors["LUNAR_POWER"] = {r,g,b}
                                    NugEnergy:SetNormalColor()
                                end,
                            },
                            FURY = {
                                name = L"Fury",
                                type = 'color',
                                order = 6,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergy.db.profile.powerTypeColors["FURY"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergy.db.profile.powerTypeColors["FURY"] = {r,g,b}
                                    NugEnergy:SetNormalColor()
                                end,
                            },
                            INSANITY = {
                                name = L"Insanity",
                                type = 'color',
                                order = 7,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergy.db.profile.powerTypeColors["INSANITY"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergy.db.profile.powerTypeColors["INSANITY"] = {r,g,b}
                                    NugEnergy:SetNormalColor()
                                end,
                            },
                            MAELSTROM = {
                                name = L"Maelstrom",
                                type = 'color',
                                order = 9,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergy.db.profile.powerTypeColors["MAELSTROM"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergy.db.profile.powerTypeColors["MAELSTROM"] = {r,g,b}
                                    NugEnergy:SetNormalColor()
                                end,
                            },
                            MANA = {
                                name = L"Mana",
                                type = 'color',
                                order = 10,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergy.db.profile.powerTypeColors["MANA"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergy.db.profile.powerTypeColors["MANA"] = {r,g,b}
                                    NugEnergy:SetNormalColor()
                                end,
                            },
                        }
                    },
                    fadeGroup = {
                        type = "group",
                        name = "",
                        order = 1.5,
                        args = {
                            font = {
                                name = L"Out of Combat Alpha",
                                desc = "0 = disabled",
                                type = "range",
                                get = function(info) return NugEnergy.db.profile.outOfCombatAlpha end,
                                set = function(info, v)
                                    NugEnergy.db.profile.outOfCombatAlpha = tonumber(v)
                                    NugEnergy:Hide()
                                    NugEnergy:UPDATE_STEALTH()
                                end,
                                min = 0,
                                max = 1,
                                step = 0.05,
                                order = 1,
                            },
                            borderType = {
                                type = "select",
                                name = L"Border Type",
                                order = 1.4,
                                get = function(info) return NugEnergy.db.profile.borderType end,
                                set = function(info, value)
                                    NugEnergy.db.profile.borderType = value
                                    NugEnergy:UpdateFrameBorder()
                                end,
                                values = {
                                    ["1PX"] = "1px Border",
                                    ["2PX"] = "2px Border",
                                    ["3PX"] = "3px Border",
                                    ["TOOLTIP"] = "Tooltip Border",
                                    ["STATUSBAR"] = "Status Border",
                                },
                            },
                            spenderFeedback = {
                                name = L"Spent / Ticker Fade",
                                desc = L"Fade effect after each tick or when spending",
                                type = "toggle",
                                width = 3,
                                order = 2,
                                get = function(info) return NugEnergy.db.profile.spenderFeedback end,
                                set = function(info, v)
                                    NugEnergy.db.profile.spenderFeedback = not NugEnergy.db.profile.spenderFeedback
                                    NugEnergy:UpdateUpvalues()
                                    NugEnergy:UpdateBarEffects()
                                end
                            },
                            smoothing = {
                                name = L"Smoothing",
                                type = "toggle",
                                order = 3,
                                get = function(info) return NugEnergy.db.profile.smoothing end,
                                set = function(info, v)
                                    NugEnergy.db.profile.smoothing = not NugEnergy.db.profile.smoothing
                                    NugEnergy:UpdateBarEffects()
                                end
                            },
                            smoothingSpeed = {
                                name = L"Animation Speed",
                                desc = L"Higher = Faster",
                                disabled = function() return not NugEnergy.db.profile.smoothing end,
                                type = "range",
                                get = function(info) return NugEnergy.db.profile.smoothingSpeed end,
                                set = function(info, v)
                                    NugEnergy.db.profile.smoothingSpeed = tonumber(v)
                                    NugEnergy:UpdateBarEffects()
                                end,
                                min = 1,
                                max = 8,
                                step = 0.5,
                                order = 4,
                            },
                        },
                    },
                    barGroup = {
                        type = "group",
                        name = "",
                        order = 2,
                        args = {
                            texture = {
                                type = "select",
                                name = L"Texture",
                                order = 10,
                                get = function(info) return NugEnergy.db.profile.textureName end,
                                set = function(info, value)
                                    NugEnergy.db.profile.textureName = value
                                    NugEnergy:Resize()
                                end,
                                values = LSM:HashTable("statusbar"),
                                dialogControl = "LSM30_Statusbar",
                            },
                            width = {
                                name = L"Width",
                                type = "range",
                                get = function(info) return NugEnergy.db.profile.width end,
                                set = function(info, v)
                                    NugEnergy.db.profile.width = tonumber(v)
                                    NugEnergy:Resize()
                                end,
                                min = 30,
                                max = 600,
                                step = 1,
                                order = 7,
                            },
                            height = {
                                name = L"Height",
                                type = "range",
                                get = function(info) return NugEnergy.db.profile.height end,
                                set = function(info, v)
                                    NugEnergy.db.profile.height = tonumber(v)
                                    NugEnergy:Resize()
                                end,
                                min = 10,
                                max = 100,
                                step = 1,
                                order = 8,
                            },
                            -- ooc_alpha = {
                            --     name = "Out of Combat Alpha",
                            --     desc = "0 - hide out of combat",
                            --     type = "range",
                            --     get = function(info) return NugEnergy.db.profile.outOfCombatAlpha end,
                            --     set = function(info, v)
                            --         NugEnergy.db.profile.outOfCombatAlpha = tonumber(v)
                            --     end,
                            --     min = 0,
                            --     max = 1,
                            --     step = 0.05,
                            --     order = 11,
                            -- },
                        },
                    },
                    isVertical = {
                        name = L"Vertical",
                        type = "toggle",
                        order = 2.5,
                        get = function(info) return NugEnergy.db.profile.isVertical end,
                        set = function(info, v) NugEnergy.Commands.vertical() end
                    },
                    textGroup = {
                        type = "group",
                        name = "",
                        order = 3,
                        args = {
                            font = {
                                type = "select",
                                name = L"Font",
                                order = 1,
                                desc = "Set the statusbar texture.",
                                get = function(info) return NugEnergy.db.profile.fontName end,
                                set = function(info, value)
                                    NugEnergy.db.profile.fontName = value
                                    NugEnergy:ResizeText()
                                end,
                                values = LSM:HashTable("font"),
                                dialogControl = "LSM30_Font",
                            },
                            fontSize = {
                                name = L"Font Size",
                                type = "range",
                                order = 2,
                                get = function(info) return NugEnergy.db.profile.fontSize end,
                                set = function(info, v)
                                    NugEnergy.db.profile.fontSize = tonumber(v)
                                    NugEnergy:ResizeText()
                                end,
                                min = 5,
                                max = 80,
                                step = 1,
                            },
                            hideText = {
                                name = L"Hide Text",
                                type = "toggle",
                                order = 3,
                                get = function(info) return NugEnergy.db.profile.hideText end,
                                set = function(info, v)
                                    NugEnergy.db.profile.hideText = not NugEnergy.db.profile.hideText
                                    NugEnergy:ResizeText()
                                end
                            },
                            textAlign = {
                                name = L"Text Align",
                                type = 'select',
                                order = 4,
                                values = {
                                    START = L"START",
                                    CENTER = L"CENTER",
                                    END = L"END",
                                },
                                get = function(info) return NugEnergy.db.profile.textAlign end,
                                set = function(info, v)
                                    NugEnergy.db.profile.textAlign = v
                                    NugEnergy:Resize()
                                end,
                            },
                            textOffsetX = {
                                name = L"Text Offset X",
                                type = "range",
                                order = 5,
                                get = function(info) return NugEnergy.db.profile.textOffsetX end,
                                set = function(info, v)
                                    NugEnergy.db.profile.textOffsetX = tonumber(v)
                                    NugEnergy:Resize()
                                end,
                                min = -50,
                                max = 50,
                                step = 1,
                            },
                            textOffsetY = {
                                name = L"Text Offset Y",
                                type = "range",
                                order = 6,
                                get = function(info) return NugEnergy.db.profile.textOffsetY end,
                                set = function(info, v)
                                    NugEnergy.db.profile.textOffsetY = tonumber(v)
                                    NugEnergy:Resize()
                                end,
                                min = -50,
                                max = 50,
                                step = 1,
                            },
                        },
                    },
                },
            }, --
        },
    }

    local specsTable = opt.args.configSelection.args
    for specIndex=1,GetNumSpecializations() do
        local id, name, description, icon = GetSpecializationInfo(specIndex)
        local iconCoords = nil
        if APILevel <= 3 then
            icon = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
            local _, class = UnitClass('player')
            iconCoords = CLASS_ICON_TCOORDS[class];
        end
        local _, class = UnitClass('player')
        specsTable["desc"..specIndex] = {
            name = "",
            type = "description",
            width = 0.25,
            imageWidth = 23,
            imageHeight = 23,
            image = icon,
            imageCoords = iconCoords,
            order = specIndex*10+1,
        }
        specsTable["conf"..specIndex] = {
            name = "",
            -- width = 1.5,
            width = 3.0,
            type = "select",
            values = NugEnergy:GetAvailableConfigsForSpec(specIndex),
            get = function(info) return NugEnergy.db.global.classConfig[class][specIndex] end,
            set = function(info, v)
                NugEnergy.db.global.classConfig[class][specIndex] = v
                NugEnergy:SPELLS_CHANGED()
                NugEnergy:NotifyGUI()
            end,
            order = specIndex*10+2,
        }
        -- specsTable["profile"..specIndex] = {
        --     name = "",
        --     type = 'select',
        --     order = specIndex*10+3,
        --     width = 1.5,
        --     values = function()
        --         return GetProfileList(NugEnergy.db)
        --     end,
        --     get = function(info) return NugEnergy.db.global.specProfiles[class][specIndex] end,
        --     set = function(info, v)
        --         NugEnergy.db.global.specProfiles[class][specIndex] = v
        --         NugEnergy:SPELLS_CHANGED()
        --     end,
        -- }
    end

    if APILevel <= 2 then
        opt.args.ticker = {
            type = "group",
            name = L"",
            guiInline = true,
            order = 5,
            args = {
                ticker = {
                    name = L"Energy Ticker",
                    type = "toggle",
                    width = "full",
                    order = 0,
                    get = function(info) return NugEnergy.db.profile.enableClassicTicker end,
                    set = function(info, v)
                        NugEnergy.db.profile.enableClassicTicker = not NugEnergy.db.profile.enableClassicTicker
                        NugEnergy:UpdateConfig(true)
                    end
                },
                twGroup = {
                    type = "group",
                    name = L"Tick Window",
                    disabled = function() return not NugEnergy.db.profile.enableClassicTicker end,
                    guiInline = true,
                    order = 5,
                    args = {
                        twEnabled = {
                            name = L"Enabled",
                            type = "toggle",
                            order = 1,
                            get = function(info) return NugEnergyDB.twEnabled end,
                            set = function(info, v)
                                NugEnergy.db.profile.twEnabled = not NugEnergy.db.profile.twEnabled
                                NugEnergy:UpdateUpvalues()
                            end
                        },
                        twEnabledCappedOnly = {
                            name = L"Only If Capping",
                            type = "toggle",
                            width = "double",
                            order = 2,
                            get = function(info) return NugEnergy.db.profile.twEnabledCappedOnly end,
                            set = function(info, v)
                                NugEnergy.db.profile.twEnabledCappedOnly = not NugEnergy.db.profile.twEnabledCappedOnly
                                NugEnergy:UpdateUpvalues()
                            end
                        },

                        twChangeColor = {
                            name = L"Change Color",
                            type = "toggle",
                            width = "full",
                            order = 2.3,
                            get = function(info) return NugEnergy.db.profile.twChangeColor end,
                            set = function(info, v)
                                NugEnergy.db.profile.twChangeColor = not NugEnergy.db.profile.twChangeColor
                                NugEnergy:UpdateUpvalues()
                            end
                        },
                        soundNameFull = {
                            name = L"Sound",
                            type = 'select',
                            order = 7.5,
                            values = {
                                none = "None",
                                Heartbeat = "Heartbeat",
                                custom = "Custom",
                            },
                            get = function(info)
                                return NugEnergy.db.profile.soundName
                            end,
                            set = function( info, v )
                                NugEnergy.db.profile.soundName = v
                                NugEnergy:UpdateUpvalues()
                            end,
                        },
                        PlayButton = {
                            name = L"Play",
                            type = 'execute',
                            width = "half",
                            order = 7.7,
                            disabled = function() return (NugEnergy.db.profile.soundNameFull == "none") end,
                            func = function()
                                NugEnergy:PlaySound()
                            end,
                        },
                        soundChannel = {
                            name = L"Sound Channel",
                            type = 'select',
                            order = 7.6,
                            values = {
                                SFX = "SFX",
                                Music = "Music",
                                Ambience = "Ambience",
                                Master = "Master",
                            },
                            get = function(info) return NugEnergy.db.profile.soundChannel end,
                            set = function( info, v ) NugEnergy.db.profile.soundChannel = v end,
                        },
                        customsoundNameFull = {
                            name = L"Custom Sound",
                            type = 'input',
                            width = "full",
                            order = 7.8,
                            disabled = function() return (NugEnergy.db.profile.soundName ~= "custom") end,
                            get = function(info) return NugEnergy.db.profile.soundNameCustom end,
                            set = function( info, v )
                                NugEnergy.db.profile.soundNameCustom = v
                            end,
                        },

                        twStart = {
                            name = L"Start Time",
                            type = "range",
                            get = function(info) return NugEnergy.db.profile.twStart end,
                            set = function(info, v)
                                NugEnergy.db.profile.twStart = tonumber(v)
                                NugEnergy:UpdateUpvalues()
                            end,
                            min = 0,
                            max = 2,
                            step = 0.01,
                            order = 3,
                        },
                        twLength = {
                            name = L"Window Length",
                            type = "range",
                            get = function(info) return NugEnergy.db.profile.twLength end,
                            set = function(info, v)
                                NugEnergy.db.profile.twLength = tonumber(v)
                                NugEnergy:UpdateUpvalues()
                            end,
                            min = 0,
                            max = 1,
                            step = 0.01,
                            order = 4,
                        },
                        twCrossfade = {
                            name = L"Crossfade Length",
                            type = "range",
                            get = function(info) return NugEnergy.db.profile.twCrossfade end,
                            set = function(info, v)
                                NugEnergy.db.profile.twCrossfade = tonumber(v)
                                NugEnergy:UpdateUpvalues()
                            end,
                            min = 0,
                            max = 0.5,
                            step = 0.01,
                            order = 5,
                        },
                    },
                }
            },
        }
    end

    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
    AceConfigRegistry:RegisterOptionsTable("NugEnergyOptions", opt)

    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    local panelFrame = AceConfigDialog:AddToBlizOptions("NugEnergyOptions", "NugEnergy")

    return panelFrame
end

local configs = {}
local currentConfigName
local currentTriggerState = {}

function NugEnergy:SPELLS_CHANGED()
    self:UpdateConfig()
end
function NugEnergy:UpdateConfig(force)
    local spec = GetSpecialization()
    local class = select(2,UnitClass("player"))

    -- local currentProfile = self.db:GetCurrentProfile()
    -- local newSpecProfile = self.db.global.specProfiles[class][spec] or "Default"
    -- if not self.db.profiles[newSpecProfile] then
    --     self.db.global.specProfiles[class][spec] = "Default"
    --     newSpecProfile = "Default"
    -- end
    -- if newSpecProfile ~= currentProfile then
    --     self.db:SetProfile(newSpecProfile)
    -- end

    local newConfigName = self.db.global.classConfig[class][spec] or "Disabled"

    -- If using missing config reset to default
    if newConfigName ~= "Disabled" and not configs[newConfigName] then
        self.db.global.classConfig[class][spec] = defaults.global.classConfig[class][spec]
        newConfigName = self.db.global.classConfig[class][spec] or "Disabled"
    end

    if newConfigName == "Disabled" then
        self:ResetConfig()
        self:Disable()
        currentConfigName = nil
        return
    else
        self:Enable()
    end

    local currentConfig = configs[currentConfigName]

    local needUpdate
    local changedConfig = currentConfigName ~= newConfigName
    if changedConfig then
        needUpdate = true
    else
        local newTriggerState = self:GetTriggerState(currentConfig)
        needUpdate = not self:IsTriggerStateEqual(currentTriggerState, newTriggerState)
    end

    if needUpdate or force then
        self:SelectConfig(newConfigName)
        self:UpdateEnergy()
        self:UpdateVisibility()
    end
end

function NugEnergy:Disable()
    -- GetComboPoints = dummy -- disable
    self.isDisabled = true
    self:Hide()
end

function NugEnergy:Enable()
    self.isDisabled = false
    self:UpdateVisibility()
end
function NugEnergy:IsDisabled()
    return self.isDisabled
end

function NugEnergy:RegisterConfig(name, config, class, specIndex)
    config.class = class
    config.specIndex = specIndex
    configs[name] = config
end

function NugEnergy:GetAvailableConfigsForSpec(specIndex)
    local _, class = UnitClass("player")
    local avConfigs = {}
    for name, config in pairs(configs) do
        if (config.class == class or config.class == "GENERAL") and (config.specIndex == specIndex or config.specIndex == nil) then
            avConfigs[name] = name
        end
    end
    avConfigs["Disabled"] = "Disabled"
    return avConfigs
end

function NugEnergy:IsTriggerStateEqual(state1, state2)
    if #state1 ~= #state2 then return false end
    for i,v in ipairs(state1) do
        if state2[i] ~= v then return false end
    end
    return true
end

function NugEnergy:GetTriggerState(config)
    if not config.triggers then return {} end
    local state = {}
    for i, func in ipairs(config.triggers) do
        table.insert(state, func())
    end
    return state
end

function NugEnergy:ResetConfig()
    table.wipe(self.flags)
    self.eventProxy:UnregisterAllEvents()
    self.eventProxy:SetScript("OnUpdate", nil)
    self:UpdateBarEffects()
    self.ticker:Disable()
    if self.fsrwatch then
        self.fsrwatch:Disable()
    end
end

function NugEnergy:SelectConfig(name)
    self:ResetConfig()
    self:ApplyConfig(name)
    currentConfigName = name
    local newConfig = configs[name]
    currentTriggerState = self:GetTriggerState(newConfig)
end

function NugEnergy:ApplyConfig(name)
    local config = configs[name]
    local spec = GetSpecialization()
    config.setup(self, spec)
end

-- function NugEnergy:SetDefaultValue(value)
--     defaultValue = value
-- end

function NugEnergy:SetPowerFilter(powerName, powerIndex)
    PowerFilter = powerName
    PowerTypeIndex = powerIndex
end

function NugEnergy:GetPowerFilter()
    return PowerFilter, PowerTypeIndex
end


function NugEnergy:ToggleExecute(state)
    execute = state
end

function NugEnergy:SetPowerGetter(func)
    GetPower = func
end

do
    local CURRENT_DB_VERSION = 1
    function NugEnergy:DoMigrations(db)
        if not next(db) or db.DB_VERSION == CURRENT_DB_VERSION then -- skip if db is empty or current
            db.DB_VERSION = CURRENT_DB_VERSION
            return
        end

        if db.DB_VERSION == nil then
            db.global = {}
            db.profiles = {
                Default = {}
            }
            local default_profile = db.profiles["Default"]
            default_profile.point = db.point
            default_profile.x = db.x
            default_profile.y = db.y
            default_profile.marks = db.marks
            default_profile.hideText = db.hideText
            default_profile.hideBar = db.hideBar
            default_profile.enableClassicTicker = db.enableClassicTicker
            default_profile.spenderFeedback = db.spenderFeedback
            default_profile.borderType = db.borderType
            default_profile.smoothing = db.smoothing
            default_profile.smoothingSpeed = db.smoothingSpeed

            default_profile.width = db.width
            default_profile.height = db.height
            default_profile.normalColor = db.normalColor
            default_profile.altColor = db.altColor
            default_profile.maxColor = db.maxColor
            default_profile.lowColor = db.lowColor
            default_profile.enableColorByPowerType = db.enableColorByPowerType
            default_profile.powerTypeColors = db.powerTypeColors
            default_profile.textureName = db.textureName
            default_profile.fontName = db.fontName
            default_profile.fontSize = db.fontSize
            default_profile.textAlign = db.textAlign
            default_profile.textOffsetX = db.textOffsetX
            default_profile.textOffsetY = db.textOffsetY
            default_profile.textColor = db.textColor
            default_profile.outOfCombatAlpha = db.outOfCombatAlpha
            default_profile.isVertical = db.isVertical

            default_profile.twEnabled = db.twEnabled
            default_profile.twEnabledCappedOnly = db.twEnabledCappedOnly
            default_profile.twStart = db.twStart
            default_profile.twLength = db.twLength
            default_profile.twCrossfade = db.twCrossfade
            default_profile.twChangeColor = db.twChangeColor
            default_profile.soundName = db.soundName
            default_profile.soundNameCustom = db.soundNameCustom
            default_profile.soundChannel = db.soundChannel
        end

        db.DB_VERSION = CURRENT_DB_VERSION
    end
end