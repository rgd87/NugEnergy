local UnitPower = UnitPower

local APILevel = math.floor(select(4,GetBuildInfo())/10000)

local math_modf = math.modf
local math_abs = math.abs
local GetSpecialization = APILevel <= 2 and function() return 1 end or _G.GetSpecialization

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

local execute = false
local function UNIT_HEALTH_EXECUTE(execute_range)
    return function(self, event, unit)
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
end
local function UNIT_HEALTH_EXECUTE_PLAYER_TARGET_CHANGED(self,event)
    if UnitExists('target') then
        self.eventProxy:UNIT_HEALTH(self, event, "target")
    end
end

local MakeGeneralGetPower = function(PowerTypeIndex, shineZone, cappedZone, minLimit, throttleText)
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
    self:SetMinMaxValues(0, UnitPowerMax("player", ptIndex))
end

local function GENERAL_UPDATE_STEALTH(self)
    self:UpdateVisibility()
end


local GetPower_ClassicRogueTicker = function(PowerTypeIndex, shineZone, cappedZone, minLimit, throttleText)
    local ticker = NugEnergy.ticker
    return function(unit)
        local p = GetTime() - ticker:GetLastTickTime()
        local p2 = UnitPower(unit, PowerTypeIndex)
        local pmax = UnitPowerMax(unit, PowerTypeIndex)
        local shine = shineZone and (p2 >= pmax-shineZone)
        local capped = p2 >= pmax-cappedZone
        -- local p2 = throttleText and math_modf(p2/5)*5 or p2
        return p, p2, nil, shine, capped, (minLimit and p2 < minLimit)
    end
end




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

NugEnergy:RegisterConfig("EnergyRogueTicker", {
    triggers = { GetSpecialization, GetSpell(193531) }, -- Deeper Stratagem,
    setup = function(self, spec)
        self:ApplyConfig("EnergyRogue")

        self:SetPowerGetter(GetPower_ClassicRogueTicker(Enum.PowerType.Energy, nil, 19, 0, false))
        self.eventProxy:SetScript("OnUpdate", function() NugEnergy:UpdateEnergy() end)
        self.eventProxy:UnregisterEvent("UNIT_MAXPOWER")
        self:SetMinMaxValues(0, 2)
        self.ticker:Enable()
        self:UpdateBarEffects("DISABLE_SMOOTHING")
    end,
}, "ROGUE")

NugEnergy:RegisterConfig("GeneralRage", {
    triggers = { GetSpecialization },
    setup = function(self, spec)
        self:SetPowerFilter("RAGE", Enum.PowerType.Rage)
        self:SetNormalColor()
        self.flags.shouldBeFull = true

        self.eventProxy:RegisterUnitEvent("UNIT_MAXPOWER", "player")
        self.eventProxy.UNIT_MAXPOWER = GENERAL_UNIT_MAXPOWER
        GENERAL_UNIT_MAXPOWER(self)

        self.eventProxy:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
        self.eventProxy.UNIT_POWER_UPDATE = FILTERED_UNIT_POWER_UPDATE("RAGE")

        -- self.eventProxy:RegisterUnitEvent("UNIT_HEALTH", "target")
        -- self.eventProxy.UNIT_HEALTH = UNIT_HEALTH_EXECUTE(0.2)

        -- self:SetPowerGetter(MakeGeneralGetPower(Enum.PowerType.Rage, 30, 10, nil, nil))
    end,
}, "GENERAL")


local GetPower_ClassicMana = function(unit)
    local p = GetTime() - NugEnergy.ticker:GetLastTickTime()
    local _, PowerTypeIndex = NugEnergy:GetPowerFilter()
    local mana = UnitPower(unit, PowerTypeIndex)
    local pmax = UnitPowerMax(unit, PowerTypeIndex)
    local p2
    if pmax > 0  then
        p2 = string.format("%d", mana/pmax*100)
    end
    local shine = nil
    local capped = mana == pmax
    local insufficient = nil
    return p, p2, execute, shine, capped, insufficient
end

NugEnergy:RegisterConfig("GeneralMana", {
    triggers = { GetSpecialization },
    setup = function(self, spec)
        self:SetPowerFilter("MANA", Enum.PowerType.Mana)
        self:SetNormalColor()
        self.flags.shouldBeFull = true

        -- self.eventProxy:RegisterUnitEvent("UNIT_MAXPOWER", "player")
        -- self.eventProxy.UNIT_MAXPOWER = GENERAL_UNIT_MAXPOWER
        -- GENERAL_UNIT_MAXPOWER(self)
        self.eventProxy:UnregisterEvent("UNIT_MAXPOWER")
        self:SetMinMaxValues(0, 2)

        self.eventProxy:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
        self.eventProxy.UNIT_POWER_UPDATE = FILTERED_UNIT_POWER_UPDATE("MANA")

        self.ticker:Enable()
        self.eventProxy:SetScript("OnUpdate", function() NugEnergy:UpdateEnergy() end)

        self:SetPowerGetter(GetPower_ClassicMana)
    end,
}, "GENERAL")


local GetPower_ClassicMana5SR = function(unit)
    local p = GetTime() - NugEnergy.fsrwatch:GetLastManaSpentTime()
    local _, PowerTypeIndex = NugEnergy:GetPowerFilter()
    local mana = UnitPower(unit, PowerTypeIndex)
    local pmax = UnitPowerMax(unit, PowerTypeIndex)
    local p2
    if pmax > 0  then
        p2 = string.format("%d", mana/pmax*100)
    end
    local shine = nil
    local capped = nil
    local insufficient = nil
    -- if p >= 5 and callback then
    --     callback()
    -- end
    -- local p2 = throttleText and math_modf(p2/5)*5 or p2
    return p, p2, execute, shine, capped, true
end



NugEnergy:RegisterConfig("GeneralFSRMana", {
    triggers = { GetSpecialization },
    setup = function(self, spec)
        -- local powerFilter = self:GetPowerFilter()
        -- if powerFilter ~= "MANA" then
            self:ApplyConfig("GeneralMana")
        -- end

        self.fsrwatch = self.fsrwatch or self:Make5SRWatcher(function(self)
            local powerFilter = self:GetPowerFilter()
            if powerFilter == "MANA" then
                self:ApplyConfig("GeneralFSRMana")
            end
        end)
        self.fsrwatch:Enable()

        self.ticker:Enable("FSR", function(self)
            self:ResetConfig()
            self:ApplyConfig("GeneralMana")
            self.fsrwatch:Enable()
            self:Update()
        end)

        self.eventProxy:UnregisterEvent("UNIT_MAXPOWER")
        self:SetMinMaxValues(0, 5)

        self:SetPowerGetter(GetPower_ClassicMana5SR)
        self.eventProxy:SetScript("OnUpdate", function() NugEnergy:UpdateEnergy() end)
    end,
}, "GENERAL")

NugEnergy:RegisterConfig("RageWarriorClassic", {
    triggers = { GetSpecialization },
    setup = function(self, spec)
        self:ApplyConfig("GeneralRage")

        if IsAnySpellKnown(20662, 20661, 20660, 20658, 5308) then
            self.eventProxy:RegisterUnitEvent("UNIT_HEALTH", "target")
            self.eventProxy.UNIT_HEALTH = UNIT_HEALTH_EXECUTE(0.2)

            self.eventProxy:RegisterEvent("PLAYER_TARGET_CHANGED")
            self.eventProxy.PLAYER_TARGET_CHANGED = UNIT_HEALTH_EXECUTE_PLAYER_TARGET_CHANGED
        end

        self:SetPowerGetter(MakeGeneralGetPower(Enum.PowerType.Rage, 30, 10, nil, nil))
    end,
}, "WARRIOR")









NugEnergy:RegisterConfig("RageDruidClassic", {
    triggers = { GetSpecialization },
    setup = function(self, spec)
        self:ApplyConfig("GeneralRage")

        self:SetPowerGetter(MakeGeneralGetPower(Enum.PowerType.Rage, 30, 10, nil, nil))
    end,
}, "DRUID")


NugEnergy:RegisterConfig("ShapeshiftDruidClassic", {
    triggers = { GetSpecialization },

    setup = function(self, spec)
        self:RegisterEvent("UNIT_DISPLAYPOWER") -- Registering on main addon, not event proxy
        self.UNIT_DISPLAYPOWER = function(self)
            local newPowerType = select(2,UnitPowerType("player"))
            self:ResetConfig()

            if newPowerType == "ENERGY" then
                self:ApplyConfig("EnergyRogueTicker")
                if APILevel == 2 then
                    self.ticker:Reset()
                end
                self:Update()
            elseif newPowerType == "RAGE" then
                self:ApplyConfig("RageDruidClassic")
                self:Update()
            elseif newPowerType == "MANA" then
                self:ApplyConfig("GeneralFSRMana")
                self:Update()
            else
                self:Disable()
            end
        end
        self.UNIT_DISPLAYPOWER(self)
    end
}, "DRUID")