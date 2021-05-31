local lastEnergyTickTime = GetTime()
local lastEnergyValue = 0
local heartbeatPlayed = false
--[==[
local GetPower_ClassicRogueTicker = function(shineZone, cappedZone, minLimit, throttleText)
    return function(unit)
        local p = GetTime() - lastEnergyTickTime
        local p2 = UnitPower(unit, PowerTypeIndex)
        local pmax = UnitPowerMax(unit, PowerTypeIndex)
        local shine = shineZone and (p2 >= pmax-shineZone)
        local capped = p2 >= pmax-cappedZone
        -- local p2 = throttleText and math_modf(p2/5)*5 or p2
        return p, p2, execute, shine, capped, (minLimit and p2 < minLimit)
    end
end
]==]
local EPT = Enum.PowerType
local Enum_PowerType_Energy = EPT.Energy

local tickFiltering = true
local ClassicTickerFrame = CreateFrame("Frame")
NugEnergy.ticker = ClassicTickerFrame
local ClassicTickerOnUpdate = function(self)
    local _, PowerTypeIndex = NugEnergy:GetPowerFilter()
    local currentEnergy = UnitPower("player", PowerTypeIndex)
    local now = GetTime()
    local possibleTick = false
    if currentEnergy > lastEnergyValue then
        if PowerTypeIndex == Enum_PowerType_Energy and tickFiltering then
            local diff = currentEnergy - lastEnergyValue
            if  (diff > 18 and diff < 22) or -- normal tick
                (diff > 38 and diff < 42) or -- adr rush
                (diff < 42 and currentEnergy == UnitPowerMax("player", PowerTypeIndex)) -- including tick to cap, but excluding thistle tea
            then
                possibleTick = true
            end
        else
            possibleTick = true
        end
    end
    if now >= lastEnergyTickTime + 2 then
        possibleTick = true
    end
    if possibleTick then
        lastEnergyTickTime = now
        heartbeatPlayed = false
    end
    lastEnergyValue = currentEnergy
end

local fsrCallback
local ClassicTickerOnUpdateFSR = function(self)
    local now = GetTime()
    if now >= lastEnergyTickTime + 5 then
        self:Disable()
        fsrCallback(NugEnergy)
    end
end

function ClassicTickerFrame:GetLastTickTime()
    return lastEnergyTickTime
end
function ClassicTickerFrame:Reset()
    lastEnergyTickTime = GetTime()
end
function ClassicTickerFrame:Enable(mode, callback)
    if mode == "FSR" then
        self:SetScript("OnUpdate", ClassicTickerOnUpdateFSR)
        fsrCallback = callback
        self:Reset()
    else
        self:SetScript("OnUpdate", ClassicTickerOnUpdate)
    end
    self.isEnabled = true
end
function ClassicTickerFrame:Disable()
    self:SetScript("OnUpdate", nil)
    self.isEnabled = false
end

function ClassicTickerFrame:GetTickProgress()
    return GetTime() - lastEnergyTickTime
end
function ClassicTickerFrame:SetHeartbeatPlayed(status)
    heartbeatPlayed = status
end
function ClassicTickerFrame:HasHeartbeatPlayed()
    return heartbeatPlayed
end

do

    local twEnabled
    local twEnabledCappedOnly
    local twStart
    local twLength
    local twCrossfade
    local twChangeColor
    local twPlaySound

    function ClassicTickerFrame:UpdateUpvalues()
        twEnabled = NugEnergy.db.profile.twEnabled
        twEnabledCappedOnly = NugEnergy.db.profile.twEnabledCappedOnly
        twStart = NugEnergy.db.profile.twStart
        twLength = NugEnergy.db.profile.twLength
        twCrossfade = NugEnergy.db.profile.twCrossfade
        twPlaySound = NugEnergy.db.profile.soundName ~= "none"
        twChangeColor = NugEnergy.db.profile.twChangeColor
    end

    local UnitReaction = UnitReaction
    local GetUnitSpeed = GetUnitSpeed
    local IsStealthed = IsStealthed

    local heartbeatEligible
    local heartbeatEligibleLastTime = 0
    local heartbeatEligibleTimeout = 8
    local function GetGradientColor(c1, c2, v)
        if v > 1 then v = 1 end
        local r = c1[1] + v*(c2[1]-c1[1])
        local g = c1[2] + v*(c2[2]-c1[2])
        local b = c1[3] + v*(c2[3]-c1[3])
        return r,g,b
    end
    local function ClassicTickerColorUpdate(self, tp, prevColor)
        local twSecondThreshold = twStart + twLength

        if tp > twSecondThreshold then
            local fp = twCrossfade > 0 and  ((twSecondThreshold + twCrossfade - tp) / twCrossfade) or 0
            if fp < 0 then fp = 0 end
            local cN = prevColor
            local cA = NugEnergy.db.profile.twColor
            self:SetColor(GetGradientColor(cN, cA, fp))
        elseif tp > twStart then
            local fp = twCrossfade > 0 and  ((twStart + twCrossfade - tp) / twCrossfade) or 0
            if fp < 0 then fp = 0 end
            local cN = prevColor
            local cA = NugEnergy.db.profile.twColor
            self:SetColor(GetGradientColor(cA, cN, fp))
        elseif tp >= 0 then
            local cN = prevColor
            self:SetColor(unpack(cN))
        end
    end

    function NugEnergy:ColorTickWindow(isCapped, prevColor)
        if twEnabled then
            local ticker = self.ticker
            if ticker.isEnabled and (not twEnabledCappedOnly or isCapped) and ticker:GetTickProgress() > twStart then
                if twPlaySound then
                    local now = GetTime()
                    local isEnemy = (UnitReaction("target", "player") or 4) <= 4
                    heartbeatEligible = IsStealthed() and UnitExists("target") and isEnemy and GetUnitSpeed("player") > 0
                    if heartbeatEligible then
                        heartbeatEligibleLastTime = now
                    end

                    if not ticker:HasHeartbeatPlayed() and now - heartbeatEligibleLastTime < heartbeatEligibleTimeout then
                        ticker:SetHeartbeatPlayed(true)
                        self:PlaySound()
                    end
                end

                if twChangeColor then
                    ClassicTickerColorUpdate(self, ticker:GetTickProgress(), prevColor)
                end
            end
        end
    end

    function NugEnergy:PlaySound()
        local sound
        if NugEnergy.db.profile.soundName == "Heartbeat" then
            sound = "Interface\\AddOns\\NugEnergy\\heartbeat.mp3"
        elseif NugEnergy.db.profile.soundName then
            sound = NugEnergy.db.profile.soundNameCustom
        end
        PlaySoundFile(sound, NugEnergy.db.profile.soundChannel)
    end
end

function NugEnergy:Make5SRWatcher(default_callback)
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetScript("OnEvent", function(self, event, ...)
        return self[event](self, event, ...)
    end)

    local callback = default_callback

    local lastManaDropTime = 0
    local prevMana = UnitPower("player", 0)
    f.UNIT_SPELLCAST_SUCCEEDED = function(self, event, unit)
        if unit == "player" then
            local now = GetTime()
            if now - lastManaDropTime < 0.01 then
                callback(NugEnergy)
            end
        end
    end
    f.UNIT_POWER_UPDATE = function(self, event, unit, ptype)
        if ptype == "MANA" then
            local mana = UnitPower("player", 0)
            if mana < prevMana then
                lastManaDropTime = GetTime()
            end
            prevMana = mana
        end
    end

    f.Enable = function(self, new_callback)
        self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
        if new_callback then
            callback = new_callback
        end
    end
    f.Disable = function(self)
        self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:UnregisterEvent("UNIT_POWER_UPDATE")
    end

    f.GetLastManaSpentTime = function(self)
        return lastManaDropTime
    end

    f:Enable()

    return f
end