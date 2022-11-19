local lastEnergyTickTime = GetTime()
local lastEnergyValue = 0
local heartbeatPlayed = false
local ENERGY = Enum.PowerType.Energy

local tickFiltering = true
local ticker = CreateFrame("Frame")
NugEnergy.ticker = ticker

local onUpdate = function(self)
    local _, powerTypeIndex = NugEnergy:GetPowerFilter()
    local currentEnergy = UnitPower("player", powerTypeIndex)
    local now = GetTime()
    local possibleTick = false
    if currentEnergy > lastEnergyValue then
        if powerTypeIndex == ENERGY and tickFiltering then
            local diff = currentEnergy - lastEnergyValue
            if
                (diff > 18 and diff < 22) or
                    (diff > 38 and diff < 42) or
                    (diff < 42 and currentEnergy == UnitPowerMax("player", powerTypeIndex))
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
local onUpdate_FSR = function(self)
    local now = GetTime()
    if now >= lastEnergyTickTime + 5 then
        self:Disable()
        fsrCallback(NugEnergy)
    end
end

function ticker:GetLastTickTime()
    return lastEnergyTickTime
end

function ticker:Reset()
    lastEnergyTickTime = GetTime()
end

function ticker:Enable(mode, callback)
    if mode == "FSR" then
        self:SetScript("OnUpdate", onUpdate_FSR)
        fsrCallback = callback
        self:Reset()
    else
        self:SetScript("OnUpdate", onUpdate)
    end
    self.isEnabled = true
end

function ticker:Disable()
    self:SetScript("OnUpdate", nil)
    self.isEnabled = false
end

function ticker:GetTickProgress()
    return GetTime() - lastEnergyTickTime
end

function ticker:SetHeartbeatPlayed(status)
    heartbeatPlayed = status
end

function ticker:HasHeartbeatPlayed()
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

    function ticker:UpdateUpvalues()
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
        v = math.min(v, 1)
        local r = c1[1] + v * (c2[1] - c1[1])
        local g = c1[2] + v * (c2[2] - c1[2])
        local b = c1[3] + v * (c2[3] - c1[3])
        return r, g, b
    end

    local function ClassicTickerColorUpdate(self, tp, prevColor)
        local twSecondThreshold = twStart + twLength

        if tp > twSecondThreshold then
            local fp = twCrossfade > 0 and ((twSecondThreshold + twCrossfade - tp) / twCrossfade) or 0
            if fp < 0 then
                fp = 0
            end
            local cN = prevColor
            local cA = NugEnergy.db.profile.twColor
            self:SetColor(GetGradientColor(cN, cA, fp))
        elseif tp > twStart then
            local fp = twCrossfade > 0 and ((twStart + twCrossfade - tp) / twCrossfade) or 0
            if fp < 0 then
                fp = 0
            end
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
                    heartbeatEligible =
                        IsStealthed() and UnitExists("target") and isEnemy and GetUnitSpeed("player") > 0
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
            sound = [[Interface\AddOns\NugEnergy\media\sounds\heartbeat.mp3]]
        elseif NugEnergy.db.profile.soundName then
            sound = NugEnergy.db.profile.soundNameCustom
        end
        PlaySoundFile(sound, NugEnergy.db.profile.soundChannel)
    end
end

function NugEnergy:Make5SRWatcher(defaultCallback)
    local watcherFrame = CreateFrame("Frame", nil, UIParent)
    watcherFrame:SetScript(
        "OnEvent",
        function(self, event, ...)
            return self[event](self, event, ...)
        end
    )

    local callback = defaultCallback
    local lastManaDropTime = 0
    local previousMana = UnitPower("player", 0)

    function watcherFrame:UNIT_SPELLCAST_SUCCEEDED(event, unit)
        if unit == "player" then
            local now = GetTime()
            if now - lastManaDropTime < 0.01 then
                callback(NugEnergy)
            end
        end
    end

    function watcherFrame:UNIT_POWER_UPDATE(event, unit, powerType)
        if powerType == "MANA" then
            local mana = UnitPower("player", 0)
            if mana < previousMana then
                lastManaDropTime = GetTime()
            end
            previousMana = mana
        end
    end

    function watcherFrame:Enable(newCallback)
        self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
        if newCallback then
            callback = newCallback
        end
    end

    function watcherFrame:Disable()
        self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:UnregisterEvent("UNIT_POWER_UPDATE")
    end

    function watcherFrame:GetLastManaSpentTime()
        return lastManaDropTime
    end

    watcherFrame:Enable()

    return watcherFrame
end
