local UnitPower = UnitPower

local APILevel = math.floor(select(4,GetBuildInfo())/10000)

local math_modf = math.modf
local math_abs = math.abs
local GetSpecialization = APILevel <= 2 and function() return 1 end or _G.GetSpecialization


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
        return p, p2, nil, shine, capped, (minLimit and p < minLimit)
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


local lastEnergyTickTime = GetTime()
local lastEnergyValue = 0
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
local UNIT_MAXPOWER_ClassicTicker = function(self)
    self:SetMinMaxValues(0, 2)
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