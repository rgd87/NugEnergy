local addonName, ns = ...

local UnitPower = UnitPower

ns.APILevel = math.floor(select(4,GetBuildInfo())/10000)
local APILevel = ns.APILevel

local math_modf = math.modf
local math_abs = math.abs
local GetSpecialization = APILevel <= 4 and function() return 1 end or _G.GetSpecialization
local isMainline = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

local IsAnySpellKnown = function (...)
    for i=1, select("#", ...) do
        local spellID = select(i, ...)
        if not spellID then break end
        if IsPlayerSpell(spellID) then return spellID end
    end
end

local GetSpell = function(spellId)
    return function()
        return IsPlayerSpell(spellId)
    end
end

local GetPowerBy5 = function(unit)
    local p = UnitPower(unit)
    local pmax = UnitPowerMax(unit)
    -- p, p2, execute, shine, capped, insufficient
    return p, math_modf(p/5)*5, nil, nil, p == pmax, nil
end

local glowCurve = C_CurveUtil.CreateCurve();
-- glowCurve:SetType(Enum.LuaCurveType.Step)
local MakeGeneralGetPower = function(PowerTypeIndex, glowZone, cappedZone, minZone, throttleText)
    local pmax = UnitPowerMax("player", PowerTypeIndex)
    if glowZone then
        glowCurve:ClearPoints()
        glowCurve:AddPoint(0.0, 0);
        glowCurve:AddPoint((pmax-glowZone)/pmax, 0);
        glowCurve:AddPoint(1.0, 1);
    end
    local capLimit = (pmax-cappedZone)/pmax
    local minLimit
    if minZone then
        minLimit = minZone/pmax
    end
    NugEnergy:SetColorThresholds(capLimit, minLimit)
    return function(unit)
        local p = UnitPower(unit, PowerTypeIndex)
        local glowIntensity = 0
        if glowZone then
            glowIntensity = UnitPowerPercent(unit, PowerTypeIndex, false, glowCurve)
        end
        return p, nil, glowIntensity
        --[[
        local p = UnitPower(unit, PowerTypeIndex)
        local pmax = UnitPowerMax(unit, PowerTypeIndex)
        local shine = shineZone and (p >= pmax-shineZone)
        -- local state
        -- if p >= pmax-10 then state = "CAPPED" end
        -- if GetSpecialization() == 3  p < 60 pmax-10
        local capped = p >= pmax-cappedZone
        local p2 = throttleText and math_modf(p/5)*5
        return p, p2, execute, shine, capped, (minLimit and p < minLimit)
        ]]
    end
end



local function GENERAL_UNIT_POWER_UPDATE(self, event, unit, powertype)
    self:UpdateEnergy()
end

local function FILTERED_UNIT_POWER_UPDATE(PowerFilter)
    return function(self, event, unit, powertype)
        if powertype == PowerFilter then self:UpdateEnergy() end
    end
end

local function GENERAL_UNIT_MAXPOWER(self)
    local _, ptIndex = self:GetPowerFilter()
    self.bar:SetMinMaxValues(0, UnitPowerMax("player", ptIndex))
    self.fade:SetMinMaxValues(0, UnitPowerMax("player", ptIndex))
end

local function GENERAL_UPDATE_STEALTH(self)
    self:UpdateVisibility()
end


ns.IsAnySpellKnown = IsAnySpellKnown
ns.GetSpell = GetSpell
ns.GetPowerBy5 = GetPowerBy5
ns.UNIT_HEALTH_EXECUTE = UNIT_HEALTH_EXECUTE
ns.UNIT_HEALTH_EXECUTE_PLAYER_TARGET_CHANGED = UNIT_HEALTH_EXECUTE_PLAYER_TARGET_CHANGED
ns.MakeGeneralGetPower = MakeGeneralGetPower
ns.GENERAL_UNIT_POWER_UPDATE = GENERAL_UNIT_POWER_UPDATE
ns.FILTERED_UNIT_POWER_UPDATE = FILTERED_UNIT_POWER_UPDATE
ns.GENERAL_UNIT_MAXPOWER = GENERAL_UNIT_MAXPOWER
ns.GENERAL_UPDATE_STEALTH = GENERAL_UPDATE_STEALTH





NugEnergy:RegisterConfig("EnergyRogue", {
    triggers = { GetSpecialization },
    setup = function(self, spec)
        self:SetPowerFilter("ENERGY", Enum.PowerType.Energy)
        self:SetNormalColor()

        self.eventProxy:RegisterEvent("UPDATE_STEALTH")
        self.eventProxy.UPDATE_STEALTH = GENERAL_UPDATE_STEALTH

        self.eventProxy:RegisterUnitEvent("UNIT_MAXPOWER", "player")
        self.eventProxy.UNIT_MAXPOWER = GENERAL_UNIT_MAXPOWER
        GENERAL_UNIT_MAXPOWER(self)

        self.eventProxy:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
        self.eventProxy.UNIT_POWER_UPDATE = FILTERED_UNIT_POWER_UPDATE("ENERGY")

        self.eventProxy:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
        self.eventProxy.UNIT_POWER_FREQUENT = FILTERED_UNIT_POWER_UPDATE("ENERGY")

        self:SetPowerGetter(MakeGeneralGetPower(Enum.PowerType.Energy, nil, 5, nil, true))
    end,
}, "ROGUE")


NugEnergy:RegisterConfig("GeneralRage", {
    triggers = { GetSpecialization },
    setup = function(self, spec)
        self:SetPowerFilter("RAGE", Enum.PowerType.Rage)
        self:SetNormalColor()

        self.eventProxy:RegisterUnitEvent("UNIT_MAXPOWER", "player")
        self.eventProxy.UNIT_MAXPOWER = GENERAL_UNIT_MAXPOWER
        GENERAL_UNIT_MAXPOWER(self)

        self.eventProxy:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
        self.eventProxy.UNIT_POWER_UPDATE = FILTERED_UNIT_POWER_UPDATE("RAGE")

        -- self.eventProxy:RegisterUnitEvent("UNIT_HEALTH", "target")
        -- self.eventProxy.UNIT_HEALTH = UNIT_HEALTH_EXECUTE(0.2)

        -- self:SetPowerGetter(MakeGeneralGetPower(Enum.PowerType.Rage, 30, 10, nil, nil))
    end,
}, "TEMPLATE")


--------------------------
--- MAINLINE
--------------------------

    NugEnergy:RegisterConfig("RageWarriorExecute", {
        triggers = { GetSpecialization },
        setup = function(self, spec)
            self:ApplyConfig("GeneralRage")

            if IsAnySpellKnown(20662, 20661, 20660, 20658, 5308,     163201) then -- 163201 is Retail
                self:SetExecuteRange(0.2)
                self.eventProxy:RegisterUnitEvent("UNIT_HEALTH", "target")
                self.eventProxy.UNIT_HEALTH = GENERAL_UNIT_POWER_UPDATE

                self.eventProxy:RegisterEvent("PLAYER_TARGET_CHANGED")
                self.eventProxy.PLAYER_TARGET_CHANGED = GENERAL_UNIT_POWER_UPDATE
            end

            self:SetPowerGetter(MakeGeneralGetPower(Enum.PowerType.Rage, 30, 10, nil, nil))
        end,
    }, "WARRIOR")

    NugEnergy:RegisterConfig("RageDruid", {
        triggers = { GetSpecialization },
        setup = function(self, spec)
            self:ApplyConfig("GeneralRage")

            self:SetPowerGetter(MakeGeneralGetPower(Enum.PowerType.Rage, 30, 10, nil, nil))
        end,
    }, "DRUID")

    NugEnergy:RegisterConfig("ShapeshiftDruid", {
        triggers = { GetSpecialization },

        setup = function(self, spec)
            self:RegisterEvent("UNIT_DISPLAYPOWER") -- Registering on main addon, not event proxy
            self.UNIT_DISPLAYPOWER = function(self)
                local newPowerType = select(2,UnitPowerType("player"))
                self:ResetConfig()

                if newPowerType == "ENERGY" then
                    self:ApplyConfig("EnergyRogue")
                    self:Enable()
                    self:Update()
                elseif newPowerType == "RAGE" then
                    self:ApplyConfig("RageDruid")
                    self:Enable()
                    self:Update()
                elseif isMainline and GetSpecialization() == 1 then
                    self:ApplyConfig("LunarPower")
                    self:Enable()
                    self:Update()
                else
                    self:Disable()
                end
            end
            self.UNIT_DISPLAYPOWER(self)
        end
    }, "DRUID")


if isMainline then

    NugEnergy:RegisterConfig("FuryDemonHunter", {
        triggers = { GetSpecialization },
        setup = function(self, spec)
            self:SetPowerFilter("FURY", Enum.PowerType.Fury)
            self:SetNormalColor()

            self.eventProxy:RegisterUnitEvent("UNIT_MAXPOWER", "player")
            self.eventProxy.UNIT_MAXPOWER = GENERAL_UNIT_MAXPOWER
            GENERAL_UNIT_MAXPOWER(self)

            self.eventProxy:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
            self.eventProxy.UNIT_POWER_UPDATE = FILTERED_UNIT_POWER_UPDATE("FURY")

            self:SetPowerGetter(MakeGeneralGetPower(Enum.PowerType.Fury, 30, 10, nil, nil))
        end,
    }, "DEMONHUNTER")


    NugEnergy:RegisterConfig("Insanity", {
        triggers = { GetSpecialization },
        setup = function(self, spec)
            self:SetPowerFilter("INSANITY", Enum.PowerType.Insanity)
            self:SetNormalColor()

            self.eventProxy:RegisterUnitEvent("UNIT_MAXPOWER", "player")
            self.eventProxy.UNIT_MAXPOWER = GENERAL_UNIT_MAXPOWER
            GENERAL_UNIT_MAXPOWER(self)

            self.eventProxy:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
            self.eventProxy.UNIT_POWER_UPDATE = FILTERED_UNIT_POWER_UPDATE("INSANITY")

            self:SetExecuteRange(0.2)
            self.eventProxy:RegisterUnitEvent("UNIT_HEALTH", "target")
            self.eventProxy.UNIT_HEALTH = GENERAL_UNIT_POWER_UPDATE

            self.eventProxy:RegisterEvent("PLAYER_TARGET_CHANGED")
            self.eventProxy.PLAYER_TARGET_CHANGED = GENERAL_UNIT_POWER_UPDATE

            self:SetPowerGetter(MakeGeneralGetPower(Enum.PowerType.Insanity, 30, 10, nil, nil))
        end,
    }, "PRIEST", 3)

    NugEnergy:RegisterConfig("EnergyBrewmaster", {
        triggers = { GetSpecialization },
        setup = function(self, spec)
            self:ApplyConfig("EnergyRogue")

            self:SetPowerGetter(MakeGeneralGetPower(Enum.PowerType.Energy, nil, 5, 25, true))
        end,
    }, "MONK")

    NugEnergy:RegisterConfig("EnergyWindwalker", {
        triggers = { GetSpecialization },
        setup = function(self, spec)
            self:ApplyConfig("EnergyRogue")

            self:SetPowerGetter(MakeGeneralGetPower(Enum.PowerType.Energy, nil, 5, 50, true))
        end,
    }, "MONK")


    NugEnergy:RegisterConfig("Focus", {
        triggers = { GetSpecialization },
        setup = function(self, spec)
            self:SetPowerFilter("FOCUS", Enum.PowerType.Focus)
            self:SetNormalColor()

            self.eventProxy:RegisterEvent("UPDATE_STEALTH")
            self.eventProxy.UPDATE_STEALTH = GENERAL_UPDATE_STEALTH

            self.eventProxy:RegisterUnitEvent("UNIT_MAXPOWER", "player")
            self.eventProxy.UNIT_MAXPOWER = GENERAL_UNIT_MAXPOWER
            GENERAL_UNIT_MAXPOWER(self)

            self.eventProxy:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
            self.eventProxy.UNIT_POWER_UPDATE = FILTERED_UNIT_POWER_UPDATE("FOCUS")

            self.eventProxy:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
            self.eventProxy.UNIT_POWER_FREQUENT = FILTERED_UNIT_POWER_UPDATE("FOCUS")

            self:SetPowerGetter(MakeGeneralGetPower(Enum.PowerType.Focus, nil, 5, nil, true))
        end,
    }, "HUNTER")


    NugEnergy:RegisterConfig("RunicPower", {
        triggers = { GetSpecialization },
        setup = function(self, spec)
            self:SetPowerFilter("RUNIC_POWER", Enum.PowerType.RunicPower)
            self:SetNormalColor()

            self.eventProxy:RegisterUnitEvent("UNIT_MAXPOWER", "player")
            self.eventProxy.UNIT_MAXPOWER = GENERAL_UNIT_MAXPOWER
            GENERAL_UNIT_MAXPOWER(self)

            self.eventProxy:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
            self.eventProxy.UNIT_POWER_UPDATE = FILTERED_UNIT_POWER_UPDATE("RUNIC_POWER")

            self:SetPowerGetter(MakeGeneralGetPower(Enum.PowerType.RunicPower, 30, 10, nil, nil))
        end,
    }, "DEATHKNIGHT")


    NugEnergy:RegisterConfig("Maelstrom", {
        triggers = { GetSpecialization },
        setup = function(self, spec)
            self:SetPowerFilter("MAELSTROM", Enum.PowerType.Maelstrom)
            self:SetNormalColor()

            self.eventProxy:RegisterUnitEvent("UNIT_MAXPOWER", "player")
            self.eventProxy.UNIT_MAXPOWER = GENERAL_UNIT_MAXPOWER
            GENERAL_UNIT_MAXPOWER(self)

            self.eventProxy:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
            self.eventProxy.UNIT_POWER_UPDATE = FILTERED_UNIT_POWER_UPDATE("MAELSTROM")

            self:SetPowerGetter(MakeGeneralGetPower(Enum.PowerType.Maelstrom, 30, 10, nil, nil))
        end,
    }, "SHAMAN")



    NugEnergy:RegisterConfig("LunarPower", {
        triggers = { GetSpecialization },
        setup = function(self, spec)
            self:SetPowerFilter("LUNAR_POWER", Enum.PowerType.LunarPower)
            self:SetNormalColor()

            self.eventProxy:RegisterUnitEvent("UNIT_MAXPOWER", "player")
            self.eventProxy.UNIT_MAXPOWER = GENERAL_UNIT_MAXPOWER
            GENERAL_UNIT_MAXPOWER(self)

            self.eventProxy:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
            self.eventProxy.UNIT_POWER_UPDATE = FILTERED_UNIT_POWER_UPDATE("LUNAR_POWER")

            self:SetPowerGetter(MakeGeneralGetPower(Enum.PowerType.LunarPower, 30, 10, nil, nil))
        end,
    }, "DRUID")

end