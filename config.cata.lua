local addonName, ns = ...
NENNS = ns

local UnitPower = UnitPower
local APILevel = ns.APILevel
local GetSpecialization = APILevel == 4 and function() return 1 end or _G.GetSpecialization

local IsAnySpellKnown = ns.IsAnySpellKnown
local GetSpell = ns.GetSpell
local GetPowerBy5 = ns.GetPowerBy5
local UNIT_HEALTH_EXECUTE = ns.UNIT_HEALTH_EXECUTE
local UNIT_HEALTH_EXECUTE_PLAYER_TARGET_CHANGED = ns.UNIT_HEALTH_EXECUTE_PLAYER_TARGET_CHANGED
local MakeGeneralGetPower = ns.MakeGeneralGetPower
local GENERAL_UNIT_POWER_UPDATE = ns.GENERAL_UNIT_POWER_UPDATE
local FILTERED_UNIT_POWER_UPDATE = ns.FILTERED_UNIT_POWER_UPDATE
local GENERAL_UNIT_MAXPOWER = ns.GENERAL_UNIT_MAXPOWER
local GENERAL_UPDATE_STEALTH = ns.GENERAL_UPDATE_STEALTH
local FindAura = ns.FindAura

if APILevel == 4 then
    -- ROGUE

    NugEnergy:RegisterConfig("EnergyRogue", {
        triggers = { GetSpecialization },
        setup = function(self, spec)
            self:SetPowerFilter("ENERGY", Enum.PowerType.Energy)
            self:SetNormalColor()
            self.flags.shouldBeFull = true

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


    -- WARRIOR

    NugEnergy:RegisterConfig("RageWarrior", {
        triggers = { GetSpecialization },
        setup = function(self, spec)
            self:ApplyConfig("GeneralRage")

            if IsAnySpellKnown(5308) then
                self.eventProxy:RegisterUnitEvent("UNIT_HEALTH", "target")
                self.eventProxy.UNIT_HEALTH = UNIT_HEALTH_EXECUTE(0.2)

                self.eventProxy:RegisterEvent("PLAYER_TARGET_CHANGED")
                self.eventProxy.PLAYER_TARGET_CHANGED = UNIT_HEALTH_EXECUTE_PLAYER_TARGET_CHANGED
            end

            self:SetPowerGetter(MakeGeneralGetPower(Enum.PowerType.Rage, 30, 10, nil, nil))
        end,
    }, "WARRIOR")





    -- DRUID

    NugEnergy:RegisterConfig("RageDruid", {
        triggers = { GetSpecialization },
        setup = function(self, spec)
            self:ApplyConfig("GeneralRage")

            self:SetPowerGetter(MakeGeneralGetPower(Enum.PowerType.Rage, 30, 10, nil, nil))
        end,
    }, "DRUID")



    local MakeBalanceGetPower = function(...)
        local normalGetPower = MakeGeneralGetPower(...)
        local math_abs = math.abs
        local GetEclipseDirection = _G.GetEclipseDirection
        return function(unit)
            local p, p2, execute, shine, capped, insufficient = normalGetPower(unit)
            local isSolar = p >= 0
            local isEclipse = false
            local directionPrefix = ""
            if isSolar then
                NugEnergy:SetColorOverride(1,0.7,0.3)
                if FindAura("player", 48517, "HELPFUL") then
                    isEclipse = true
                end
                if GetEclipseDirection() == "sun" then
                    directionPrefix = ">"
                elseif GetEclipseDirection() == "moon" then
                    directionPrefix = "<"
                end
            else
                NugEnergy:SetColorOverride(0.3,0.52,0.9)
                if FindAura("player", 48518, "HELPFUL") then
                    isEclipse = true
                end
                if GetEclipseDirection() == "sun" then
                    directionPrefix = "<"
                elseif GetEclipseDirection() == "moon" then
                    directionPrefix = ">"
                end
            end
            p = math_abs(p)
            p2 = directionPrefix..p
            return p, p2, execute, shine, not isEclipse, insufficient, isSolar
        end
    end
    NugEnergy:RegisterConfig("DruidBalanceCata", {
        triggers = { GetSpecialization },
        setup = function(self, spec)
            self:SetPowerFilter("BALANCE", Enum.PowerType.Balance)
            self:SetColorOverride(0,1,0)

            self.eventProxy:RegisterUnitEvent("UNIT_MAXPOWER", "player")
            self.eventProxy.UNIT_MAXPOWER = GENERAL_UNIT_MAXPOWER
            GENERAL_UNIT_MAXPOWER(self)

            self.eventProxy:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
            self.eventProxy.UNIT_POWER_UPDATE = FILTERED_UNIT_POWER_UPDATE("BALANCE")

            self:SetPowerGetter(MakeBalanceGetPower(Enum.PowerType.Balance, 0, 10, nil, nil))
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
                    self:Enable()
                    self:ApplyConfig("EnergyRogue")
                    if APILevel == 2 and self.ticker then
                        self.ticker:Reset()
                    end
                    self:Update()
                elseif newPowerType == "RAGE" then
                    self:Enable()
                    self:ApplyConfig("RageDruid")
                    self:Update()

                elseif IsPlayerSpell(78674) then -- Starsurge / Balance Spec trigger
                    self:Enable()
                    self:ApplyConfig("DruidBalanceCata")
                    self:Update()
                -- elseif newPowerType == "MANA" then
                --     self:ApplyConfig("GeneralFSRMana")
                --     self:Update()
                else
                    self:Disable()
                end
            end
            self.UNIT_DISPLAYPOWER(self)
        end
    }, "DRUID")

    -- HUNTER

    NugEnergy:RegisterConfig("Focus", {
        triggers = { GetSpecialization },
        setup = function(self, spec)
            self:SetPowerFilter("FOCUS", Enum.PowerType.Focus)
            self:SetNormalColor()
            self.flags.shouldBeFull = true

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

    -- DEATH KNIGHT

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
end