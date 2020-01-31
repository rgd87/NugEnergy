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
local isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local GetSpecialization = isClassic and function() end or _G.GetSpecialization

NugEnergy = CreateFrame("StatusBar","NugEnergy",UIParent)

NugEnergy:SetScript("OnEvent", function(self, event, ...)
    -- print(event, unpack{...})
	return self[event](self, event, ...)
end)

local LSM = LibStub("LibSharedMedia-3.0")

LSM:Register("statusbar", "Glamour7", [[Interface\AddOns\NugEnergy\statusbar.tga]])
LSM:Register("statusbar", "NugEnergyVertical", [[Interface\AddOns\NugEnergy\vstatusbar.tga]])

LSM:Register("font", "Emblem", [[Interface\AddOns\NugEnergy\Emblem.ttf]], GetLocale() ~= "enUS" and 15)

local getStatusbar = function() return LSM:Fetch("statusbar", NugEnergyDB.textureName) end
local getFont = function() return LSM:Fetch("font", NugEnergyDB.fontName) end

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
NugEnergy:RegisterEvent("PLAYER_LOGOUT")
local UnitPower = UnitPower
local math_modf = math.modf
local math_abs = math.abs
local PowerFilter
local PowerTypeIndex
local ForcedToShow
local GetPower = UnitPower
local GetPowerMax = UnitPowerMax
local UnitIsFriend = UnitIsFriend
local IsStealthed = IsStealthed
local UnitIsFriend = UnitIsFriend
local GetUnitSpeed = GetUnitSpeed

local execute = false
local execute_range = nil

local tickerEnabled
local twEnabled
local twEnabledCappedOnly
local twStart
local twLength
local twCrossfade
local twChangeColor
local twPlaySound

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
    point = "CENTER",
    x = 0, y = 0,
    marks = {},
    rage = true,
    energy = true,
    mana = false,
    manaPriest = false,
    manaDruid = true,
    enableFSR = true,
    -- powerTypeColors = true,
    -- focusColor = true

    hideText = false,
    hideBar = false,
    enableClassicTicker = true,
    spenderFeedback = not isClassic,
    smoothing = true,
    smoothingSpeed = 6, -- 1 - 8

    width = 100,
    height = 30,
    normalColor = { 0.9, 0.1, 0.1 }, --1
    altColor = { .9, 0.1, 0.4 }, -- for dispatch and meta 2
    maxColor = { 131/255, 0.2, 0.2 }, --max color 3
    lowColor = { 141/255, 31/255, 62/255 }, --low color 4
    twColor = { 0.15, 0.9, 0.4 }, -- tick window color
    enableColorByPowerType = false,
    powerTypeColors = {
        ["ENERGY"] = ColorArray(PowerBarColor["ENERGY"]),
        ["FOCUS"] = ColorArray(PowerBarColor["FOCUS"]),
        ["RAGE"] = ColorArray(PowerBarColor["RAGE"]),
        ["RUNIC_POWER"] = ColorArray(PowerBarColor["RUNIC_POWER"]),
        ["LUNAR_POWER"] = ColorArray(PowerBarColor["LUNAR_POWER"]),
        ["FURY"] = ColorArray(PowerBarColor["FURY"]),
        ["INSANITY"] = ColorArray(PowerBarColor["INSANITY"]),
        ["PAIN"] = ColorArray(PowerBarColor["PAIN"]),
        ["MAELSTROM"] = ColorArray(PowerBarColor["MAELSTROM"]),
        ["MANA"] = ColorArray(PowerBarColor["MANA"]),
    },
    textureName = "Glamour7",
    fontName = "Emblem",
    fontSize = 25,
    textAlign = "END",
    textOffsetX = 0,
    textOffsetY = 0,
    textColor = {1,1,1, isClassic and 0.8 or 0.3},
    outOfCombatAlpha = 0,
    isVertical = false,

    twEnabled = true,
    twEnabledCappedOnly = true,
    twStart = 0.9,
    twLength = 0.4,
    twCrossfade = 0.15,
    twChangeColor = true,
    soundName = "none",
    soundNameCustom = "Interface\\AddOns\\YourSound.mp3",
    soundChannel = "SFX",
}
local normalColor = defaults.normalColor
local lowColor = defaults.lowColor
local maxColor = defaults.maxColor
local free_marks = {}

local function SetupDefaults(t, defaults)
    for k,v in pairs(defaults) do
        if type(v) == "table" then
            if t[k] == nil then
                t[k] = CopyTable(v)
            else
                SetupDefaults(t[k], v)
            end
        else
            if t[k] == nil then t[k] = v end
        end
    end
end
local function RemoveDefaults(t, defaults)
    for k, v in pairs(defaults) do
        if type(t[k]) == 'table' and type(v) == 'table' then
            RemoveDefaults(t[k], v)
            if next(t[k]) == nil then
                t[k] = nil
            end
        elseif t[k] == v then
            t[k] = nil
        end
    end
    return t
end


function NugEnergy.PLAYER_LOGIN(self,event)
    NugEnergyDB = NugEnergyDB or {}
    SetupDefaults(NugEnergyDB, defaults)

    NugEnergyDB_Character = NugEnergyDB_Character or {}
    NugEnergyDB_Character.marks = NugEnergyDB_Character.marks or { [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {} }

    NugEnergy:UpdateUpvalues()

    twEnabled = NugEnergyDB.twEnabled
    tickerEnabled = NugEnergyDB.enableClassicTicker
    twEnabledCappedOnly = NugEnergyDB.twEnabledCappedOnly
    twStart = NugEnergyDB.twStart
    twLength = NugEnergyDB.twLength
    twCrossfade = NugEnergyDB.twCrossfade

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

function NugEnergy.PLAYER_LOGOUT(self, event)
    RemoveDefaults( NugEnergyDB, defaults)
end

function NugEnergy:UpdateUpvalues()
    isVertical = NugEnergyDB.isVertical
    onlyText = NugEnergyDB.hideBar
    spenderFeedback = NugEnergyDB.spenderFeedback
    twPlaySound = NugEnergyDB.soundNameFull ~= "none"
    twChangeColor = NugEnergyDB.twChangeColor
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

local IsAnySpellKnown = function (...)
    for i=1, select("#", ...) do
        local spellID = select(i, ...)
        if not spellID then break end
        if IsPlayerSpell(spellID) then return spellID end
    end
end

local lastEnergyTickTime = GetTime()
local lastEnergyValue = 0
local heartbeatPlayed = false
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

local function GetGradientColor(c1, c2, v)
    if v > 1 then v = 1 end
    local r = c1[1] + v*(c2[1]-c1[1])
    local g = c1[2] + v*(c2[2]-c1[2])
    local b = c1[3] + v*(c2[3]-c1[3])
    return r,g,b
end

local GetTickProgress = function() return GetTime() - lastEnergyTickTime end

local ClassicTickerColorUpdate = function(self, tp, prevColor)
    local twSecondThreshold = twStart + twLength

    if tp > twSecondThreshold then
        local fp = twCrossfade > 0 and  ((twSecondThreshold + twCrossfade - tp) / twCrossfade) or 0
        if fp < 0 then fp = 0 end
        local cN = prevColor
        local cA = NugEnergyDB.twColor
        self:SetColor(GetGradientColor(cN, cA, fp))
    elseif tp > twStart then
        local fp = twCrossfade > 0 and  ((twStart + twCrossfade - tp) / twCrossfade) or 0
        if fp < 0 then fp = 0 end
        local cN = prevColor
        local cA = NugEnergyDB.twColor
        self:SetColor(GetGradientColor(cA, cN, fp))
    elseif tp >= 0 then
        local cN = prevColor
        self:SetColor(unpack(cN))
    end
end

local ClassicTickerFrame = CreateFrame("Frame")
local ClassicTickerOnUpdate = function(self)
    local currentEnergy = UnitPower("player", PowerTypeIndex)
    local now = GetTime()
    if currentEnergy > lastEnergyValue or now >= lastEnergyTickTime + 2 then
        lastEnergyTickTime = now
        heartbeatPlayed = false
    end
    lastEnergyValue = currentEnergy
end
ClassicTickerFrame.Enable = function(self)
    self:SetScript("OnUpdate", ClassicTickerOnUpdate)
    self.isEnabled = true
end
ClassicTickerFrame.Disable = function(self)
    self:SetScript("OnUpdate", nil)
    self.isEnabled = false
end
local UNIT_MAXPOWER_ClassicTicker = function(self)
    self:SetMinMaxValues(0, 2)
end

--[[
function NugEnergy:DRUID(EnergyType, EnergyIndex)
    UnitPowerType = function()
        return EnergyIndex, EnergyType
    end
    UnitClass = function()
        return "Druid", "DRUID"
    end
    self:Initialize()
    self:UNIT_DISPLAYPOWER()
end
]]

function NugEnergy.Initialize(self)
    self:RegisterEvent("UNIT_POWER_UPDATE")
    self:RegisterEvent("UNIT_MAXPOWER")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.PLAYER_REGEN_ENABLED = self.UPDATE_STEALTH
    self.PLAYER_REGEN_DISABLED = self.UPDATE_STEALTH

    if not self.initialized then
        self:Create()
        self.initialized = true
        self:SetNormalColor()
    end

    twEnabled = false

    if class == "ROGUE" and NugEnergyDB.energy then
        PowerFilter = "ENERGY"
        self:SetNormalColor()
        PowerTypeIndex = Enum.PowerType.Energy
        twEnabled = NugEnergyDB.twEnabled
        shouldBeFull = true
        self:RegisterEvent("UPDATE_STEALTH")
        self:SetScript("OnUpdate",self.UpdateEnergy)

        self.SPELLS_CHANGED = function(self)
            local spec = GetSpecialization()
            if spec == 1 and IsPlayerSpell(111240) then --blindside
                execute_range = 0.30
                self:RegisterUnitEvent("UNIT_HEALTH", "target")
                self:RegisterEvent("PLAYER_TARGET_CHANGED")
            else
                execute_range = nil
                execute = nil
                self:UnregisterEvent("UNIT_HEALTH")
                self:UnregisterEvent("PLAYER_TARGET_CHANGED")
            end
        end

        if isClassic and NugEnergyDB.enableClassicTicker then
            GetPower = GetPower_ClassicRogueTicker(nil, 19, 0, false)
            ClassicTickerFrame:Enable()
            self:UpdateBarEffects() -- Will Disable Smoothing
            NugEnergy.UNIT_MAXPOWER = UNIT_MAXPOWER_ClassicTicker
        else
            GetPower = RageBarGetPower(nil, 5, nil, true)
            if ClassicTickerFrame.isEnabled then
                ClassicTickerFrame:Disable()
                self:UpdateBarEffects()
            end
            NugEnergy.UNIT_MAXPOWER = NugEnergy.NORMAL_UNIT_MAXPOWER
            self:RegisterEvent("SPELLS_CHANGED")
            self:SPELLS_CHANGED()
        end
        self:UNIT_MAXPOWER()



    elseif class == "DRUID" then
        self:RegisterEvent("UNIT_DISPLAYPOWER")
        self:RegisterEvent("UPDATE_STEALTH")

        self:SetScript("OnUpdate",self.UpdateEnergy)
        self.UNIT_DISPLAYPOWER = function(self)
            local newPowerType = select(2,UnitPowerType("player"))
            shouldBeFull = false
            twEnabled = false

            -- restore to original MAXPOWER in case it was switched for classic energy
            NugEnergy.UNIT_MAXPOWER = NugEnergy.NORMAL_UNIT_MAXPOWER
            if newPowerType == "ENERGY" and NugEnergyDB.energy then
                PowerFilter = "ENERGY"
                PowerTypeIndex = Enum.PowerType.Energy
                twEnabled = NugEnergyDB.twEnabled
                self:SetNormalColor()
                shouldBeFull = true
                self:RegisterEvent("UNIT_POWER_UPDATE")
                self:RegisterEvent("UNIT_MAXPOWER")
                self.PLAYER_REGEN_ENABLED = self.UPDATE_STEALTH
                self.PLAYER_REGEN_DISABLED = self.UPDATE_STEALTH
                -- self.UPDATE_STEALTH = self.__UPDATE_STEALTH
                -- self.UpdateEnergy = self.__UpdateEnergy
                if isClassic and NugEnergyDB.enableClassicTicker then
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
                self:SetScript("OnUpdate",self.UpdateEnergy)
            elseif newPowerType =="RAGE" and NugEnergyDB.rage then
                PowerFilter = "RAGE"
                PowerTypeIndex = Enum.PowerType.Rage
                self:SetNormalColor()
                self:RegisterEvent("UNIT_POWER_UPDATE")
                self:RegisterEvent("UNIT_MAXPOWER")
                self.PLAYER_REGEN_ENABLED = self.UPDATE_STEALTH
                self.PLAYER_REGEN_DISABLED = self.UPDATE_STEALTH
                -- self.UPDATE_STEALTH = self.__UPDATE_STEALTH
                -- self.UpdateEnergy = self.__UpdateEnergy
                GetPower = RageBarGetPower(30, 10, nil, nil)
                self:RegisterEvent("PLAYER_REGEN_DISABLED")
                self:SetScript("OnUpdate", nil)
                self:UNIT_MAXPOWER()
                self:UPDATE_STEALTH()
            elseif newPowerType =="MANA" and isClassic and NugEnergyDB.manaDruid then
                self:SwitchToMana()
            else
                PowerFilter = nil
                PowerTypeIndex = nil
                self:UnregisterEvent("UNIT_POWER_UPDATE")
                self:UnregisterEvent("UNIT_MAXPOWER")
                self:UnregisterEvent("PLAYER_REGEN_DISABLED")
                self:SetScript("OnUpdate", nil)
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

    elseif class == "WARRIOR" and NugEnergyDB.rage then
        PowerFilter = "RAGE"
        PowerTypeIndex = Enum.PowerType.Rage
        self:SetNormalColor()

        GetPower = RageBarGetPower(30, 10, nil, nil)
        if IsAnySpellKnown(20662, 20661, 20660, 20658, 5308) then
            execute_range = 0.2
            self:RegisterUnitEvent("UNIT_HEALTH", "target")
            self:RegisterEvent("PLAYER_TARGET_CHANGED")
        end

    elseif class == "PRIEST" and isClassic and (NugEnergyDB.manaPriest or NugEnergyDB.mana) then
        self:SwitchToMana()

    elseif NugEnergyDB.mana then
        self:SwitchToMana()

    else
        self:UnregisterAllEvents()
        self:SetScript("OnUpdate", nil)
        self:Hide()
        return false
    end

    self:UPDATE_STEALTH()
    self:UpdateEnergy()
    return true
end

local heartbeatEligible
local heartbeatEligibleLastTime = 0
local heartbeatEligibleTimeout = 8

function NugEnergy.UNIT_POWER_UPDATE(self,event,unit,powertype)
    if powertype == PowerFilter then self:UpdateEnergy() end
end
NugEnergy.UNIT_POWER_FREQUENT = NugEnergy.UNIT_POWER_UPDATE
function NugEnergy.UpdateEnergy(self, elapsed)
    local p, p2, execute, shine, capped, insufficient = GetPower("player")
    local wasFull = isFull
    isFull = p == GetPowerMax("player", PowerTypeIndex)
    if isFull ~= wasFull then
        NugEnergy:UPDATE_STEALTH(nil, true)
    end

    p2 = p2 or p
    self.text:SetText(p2)
    if not onlyText then
        if shine then
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
            c = NugEnergyDB.altColor
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

        if twEnabled and tickerEnabled and (not twEnabledCappedOnly or capped) and GetTickProgress() > twStart then

            if twPlaySound then
                local now = GetTime()
                heartbeatEligible = IsStealthed() and UnitExists("target") and not UnitIsFriend("target", "player") and GetUnitSpeed("player") > 0
                if heartbeatEligible then
                    heartbeatEligibleLastTime = now
                end

                if not heartbeatPlayed and now - heartbeatEligibleLastTime < heartbeatEligibleTimeout then
                    heartbeatPlayed = true
                    self:PlaySound()
                end
            end

            if twChangeColor then
                ClassicTickerColorUpdate(self, GetTickProgress(), c)
            end
        end

        self:SetValue(p)
        --if self.marks[p] then self:PlaySpell(self.marks[p]) end
        if self.marks[p] then self.marks[p].shine:Play() end
    end
end
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
--

function NugEnergy:PlaySound()
    local sound
    if NugEnergyDB.soundName == "Heartbeat" then
        sound = "Interface\\AddOns\\NugEnergy\\heartbeat.mp3"
    elseif NugEnergyDB.soundName then
        sound = NugEnergyDB.soundNameCustom
    end
    PlaySoundFile(sound, NugEnergyDB.soundChannel)
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


function NugEnergy.UNIT_MAXPOWER(self)
    self:SetMinMaxValues(0,GetPowerMax("player", PowerTypeIndex))
    if not self.marks then return end
    for _, mark in pairs(self.marks) do
        mark:Update()
    end
end
NugEnergy.NORMAL_UNIT_MAXPOWER = NugEnergy.UNIT_MAXPOWER

local fader = CreateFrame("Frame", nil, NugEnergy)
NugEnergy.fader = fader
local HideTimer = function(self, time)
    self.OnUpdateCounter = (self.OnUpdateCounter or 0) + time
    if self.OnUpdateCounter < fadeAfter then return end

    local nen = self:GetParent()
    local p = fadeTime - ((self.OnUpdateCounter - fadeAfter) / fadeTime)
    -- if p < 0 then p = 0 end
    -- local ooca = NugEnergyDB.outOfCombatAlpha
    -- local a = ooca + ((1 - ooca) * p)
    local pA = NugEnergyDB.outOfCombatAlpha
    local rA = 1 - NugEnergyDB.outOfCombatAlpha
    local a = pA + (p*rA)
    nen:SetAlpha(a)
    if self.OnUpdateCounter >= fadeAfter + fadeTime then
        self:SetScript("OnUpdate",nil)
        if nen:GetAlpha() <= 0.03 then
            nen:Hide()
        end
        nen.hiding = false
        self.OnUpdateCounter = 0
    end
end
function NugEnergy:StartHiding()
    if (not self.hiding and self:IsVisible())  then
        fader:SetScript("OnUpdate", HideTimer)
        fader.OnUpdateCounter = 0
        self.hiding = true
    end
end

function NugEnergy:StopHiding()
    -- if self.hiding then
        fader:SetScript("OnUpdate", nil)
        self.hiding = false
    -- end
end

function NugEnergy.UPDATE_STEALTH(self, event, fromUpdateEnergy)
    local inCombat = UnitAffectingCombat("player")
    if (inCombat or
        ((class == "ROGUE" or class == "DRUID") and IsStealthed() and (isClassic or (shouldBeFull and not isFull))) or
        ForcedToShow)
        and PowerFilter
    then
        self:UNIT_MAXPOWER()
        self:UpdateEnergy()
        self:SetAlpha(1)
        self:StopHiding()
        self:Show()
    elseif doFadeOut and self:IsVisible() and self:GetAlpha() > NugEnergyDB.outOfCombatAlpha and PowerFilter then
        self:StartHiding()
    elseif NugEnergyDB.outOfCombatAlpha > 0 and PowerFilter then
        self:SetAlpha(NugEnergyDB.outOfCombatAlpha)
        self:Show()
    else
        self:Hide()
    end
end
NugEnergy.__UPDATE_STEALTH = NugEnergy.UPDATE_STEALTH

function NugEnergy.ACTIVE_TALENT_GROUP_CHANGED()
    NugEnergy:ReconfigureMarks()
    if NugEnergy.UNIT_DISPLAYPOWER then
        NugEnergy:UNIT_DISPLAYPOWER()
    end
end
function NugEnergy.ReconfigureMarks(self)
    local spec_marks = NugEnergyDB_Character.marks[GetSpecialization() or 0]
    for at, frame in pairs(NugEnergy.marks) do
        frame:Hide()
        table.insert(free_marks, frame)
        NugEnergy.marks[at] = nil
        -- print("Hiding", at)
    end
    for at in pairs(spec_marks) do
        -- print("Showing", at)
        NugEnergy:CreateMark(at)
    end
    -- NugEnergy:RealignMarks()
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
    if NugEnergyDB.enableColorByPowerType and PowerFilter then
        normalColor = NugEnergyDB.powerTypeColors[PowerFilter]
        lowColor = { hsv_shift(normalColor, -0.07, -0.22, -0.3) }
        maxColor = { hsv_shift(normalColor, 0, -0.3, -0.4) }
    else
        normalColor = NugEnergyDB.normalColor
        lowColor = NugEnergyDB.lowColor
        maxColor = NugEnergyDB.maxColor
    end
end

function NugEnergy:Resize()
    local f = self
    local width = NugEnergyDB.width
    local height = NugEnergyDB.height
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
        local textAlign = NugEnergyDB.textAlign
        if textAlign == "END" then
            text:SetPoint("TOP", f, "TOP", 0+NugEnergyDB.textOffsetX, -5+NugEnergyDB.textOffsetY)
            text:SetJustifyV("TOP")
        elseif textAlign == "CENTER" then
            text:SetPoint("CENTER", f, "CENTER", 0+NugEnergyDB.textOffsetX, 0+NugEnergyDB.textOffsetY)
            text:SetJustifyV("CENTER")
        elseif textAlign == "START" then
            text:SetPoint("BOTTOM", f, "BOTTOM", 0+NugEnergyDB.textOffsetX, 0+NugEnergyDB.textOffsetY)
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
        local textAlign = NugEnergyDB.textAlign
        if textAlign == "END" then
            text:SetPoint("RIGHT", f, "RIGHT", -7+NugEnergyDB.textOffsetX, -2+NugEnergyDB.textOffsetY)
            text:SetJustifyH("RIGHT")
        elseif textAlign == "CENTER" then
            text:SetPoint("CENTER", f, "CENTER", 0+NugEnergyDB.textOffsetX, -2+NugEnergyDB.textOffsetY)
            text:SetJustifyH("CENTER")
        elseif textAlign == "START" then
            text:SetPoint("LEFT", f, "LEFT", 7+NugEnergyDB.textOffsetX, -2+NugEnergyDB.textOffsetY)
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
    local fontSize = NugEnergyDB.fontSize
    text:SetFont(font,fontSize, textoutline and "OUTLINE")
    local r,g,b,a = unpack(NugEnergyDB.textColor)
    text:SetTextColor(r,g,b)
    text:SetAlpha(a)
    if NugEnergyDB.hideText then
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

function NugEnergy.Create(self)
    local f = self
    local width = NugEnergyDB.width
    local height = NugEnergyDB.height
    if isVertical then
        height, width = width, height
        f:SetOrientation("VERTICAL")
    end
    f:SetWidth(width)
    f:SetHeight(height)

    if not onlyText then
    local backdrop = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 0,
        insets = {left = -2, right = -2, top = -2, bottom = -2},
    }
    f:SetBackdrop(backdrop)
    f:SetBackdropColor(0,0,0,0.5)
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

    local color = NugEnergyDB.normalColor
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
    f:UNIT_MAXPOWER()
    -- NEW MARKS
    -- for p in pairs(NugEnergyDB_Character.marks) do
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

    local at = CreateFrame("Frame", nil, f)
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

    local text = f:CreateFontString(nil, "OVERLAY")
    local font = getFont()
    local fontSize = NugEnergyDB.fontSize
    text:SetFont(font,fontSize, textoutline and "OUTLINE")

    local r,g,b,a = unpack(NugEnergyDB.textColor)
    text:SetTextColor(r,g,b)
    text:SetAlpha(a)
    f.text = text

    NugEnergy:Resize()

    if NugEnergyDB.hideText then
        text:Hide()
    else
        text:Show()
    end

    f:SetPoint(NugEnergyDB.point, UIParent, NugEnergyDB.point, NugEnergyDB.x, NugEnergyDB.y)

    local oocA = NugEnergyDB.outOfCombatAlpha
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
        _,_, NugEnergyDB.point, NugEnergyDB.x, NugEnergyDB.y = self:GetPoint(1)
    end)
end

function NugEnergy:UpdateBarEffects()
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

    if NugEnergyDB.smoothing and not ClassicTickerFrame.isEnabled then
        f.SetValueWithoutSmoothing = f.SetValue

        f.smoothTicker = f.smoothTicker or CreateFrame("Frame", nil, f)
        f.smoothTicker:Show()
        f.smoothTicker.parent = f
        local animationSpeed = 1 + 8 - NugEnergyDB.smoothingSpeed
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

    if NugEnergyDB.spenderFeedback then
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
            NugEnergyDB_Character.marks[GetSpecialization() or 0][at] = true
            NugEnergy:CreateMark(at)
        end
    end,
    ["markdel"] = function(v)
        local p = ParseOpts(v)
        local at = p["at"]
        if at then
            NugEnergyDB_Character.marks[GetSpecialization() or 0][at] = nil
            NugEnergy:ReconfigureMarks()
            -- NugEnergy.marks[at]:Hide()
            -- NugEnergy.marks[at] = nil
        end
    end,
    ["marklist"] = function(v)
        print("Current marks:")
        for p in pairs(NugEnergyDB.marks) do
            print(string.format("    @%d",p))
        end
    end,
    ["reset"] = function(v)
        NugEnergy:SetPoint("CENTER",UIParent,"CENTER",0,0)
    end,
    ["vertical"] = function(v)
        NugEnergyDB.isVertical = not NugEnergyDB.isVertical
        isVertical = NugEnergyDB.isVertical
        NugEnergy:Resize()
    end,
    ["rage"] = function(v)
        NugEnergyDB.rage = not NugEnergyDB.rage
        NugEnergy:Initialize()
    end,
    ["energy"] = function(v)
        NugEnergyDB.energy = not NugEnergyDB.energy
        NugEnergy:Initialize()
    end,
}

local helpMessage = {
    "|cff00ffbb/nen gui|r",
    "|cff00ff00/nen lock|r",
    "|cff00ff00/nen unlock|r",
    "|cff00ff00/nen reset|r",
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



function NugEnergy:CreateGUI()
    local opt = {
        type = 'group',
        name = "NugEnergy Settings",
        order = 1,
        args = {
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
                    NugEnergyDB = {}
                    SetupDefaults(NugEnergyDB, defaults)
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
                                disabled = function() return NugEnergyDB.enableColorByPowerType end,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergyDB.normalColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergyDB.normalColor = {r,g,b}
                                end,
                                order = 1,
                            },
                            customcolor2 = {
                                name = L"Alt Color",
                                type = 'color',
                                order = 2,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergyDB.altColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergyDB.altColor = {r,g,b}
                                end,
                            },
                            customcolor3 = {
                                name = L"Max Color",
                                type = 'color',
                                disabled = function() return NugEnergyDB.enableColorByPowerType end,
                                order = 3,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergyDB.maxColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergyDB.maxColor = {r,g,b}
                                end,
                            },
                            customcolor4 = {
                                name = L"Insufficient Color",
                                type = 'color',
                                disabled = function() return NugEnergyDB.enableColorByPowerType end,
                                order = 4,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergyDB.lowColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergyDB.lowColor = {r,g,b}
                                end,
                            },
                            textColor = {
                                name = L"Text Color & Alpha",
                                type = 'color',
                                hasAlpha = true,
                                order = 5,
                                get = function(info)
                                    local r,g,b,a = unpack(NugEnergyDB.textColor)
                                    return r,g,b,a
                                end,
                                set = function(info, r, g, b, a)
                                    NugEnergyDB.textColor = {r,g,b, a}
                                    NugEnergy:ResizeText()
                                end,
                            },
                            twColor = {
                                name = L"Tick Window Color",
                                type = 'color',
                                order = 6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergyDB.twColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergyDB.twColor = {r,g,b}
                                    NugEnergy:ResizeText()
                                end,
                            },
                        },
                    },
                    ColorByPowerType = {
                        name = L"Color by Power Type",
                        type = "toggle",
                        order = 1.1,
                        get = function(info) return NugEnergyDB.enableColorByPowerType end,
                        set = function(info, v)
                            NugEnergyDB.enableColorByPowerType = not NugEnergyDB.enableColorByPowerType
                            NugEnergy:SetNormalColor()
                        end
                    },
                    customColorGroup = {
                        type = "group",
                        name = "Custom Power Colors",
                        disabled = function() return not NugEnergyDB.enableColorByPowerType end,
                        order = 1.2,
                        args = {
                            Energy = {
                                name = L"Energy",
                                type = 'color',
                                order = 1,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergyDB.powerTypeColors["ENERGY"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergyDB.powerTypeColors["ENERGY"] = {r,g,b}
                                end,
                            },
                            Focus = {
                                name = L"Focus",
                                type = 'color',
                                order = 2,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergyDB.powerTypeColors["FOCUS"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergyDB.powerTypeColors["FOCUS"] = {r,g,b}
                                end,
                            },
                            RAGE = {
                                name = L"Rage",
                                type = 'color',
                                order = 3,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergyDB.powerTypeColors["RAGE"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergyDB.powerTypeColors["RAGE"] = {r,g,b}
                                end,
                            },
                            RUNIC_POWER = {
                                name = L"Runic Power",
                                type = 'color',
                                order = 4,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergyDB.powerTypeColors["RUNIC_POWER"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergyDB.powerTypeColors["RUNIC_POWER"] = {r,g,b}
                                end,
                            },
                            LUNAR_POWER = {
                                name = L"Lunar Power",
                                type = 'color',
                                order = 5,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergyDB.powerTypeColors["LUNAR_POWER"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergyDB.powerTypeColors["LUNAR_POWER"] = {r,g,b}
                                end,
                            },
                            FURY = {
                                name = L"Fury",
                                type = 'color',
                                order = 6,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergyDB.powerTypeColors["FURY"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergyDB.powerTypeColors["FURY"] = {r,g,b}
                                end,
                            },
                            INSANITY = {
                                name = L"Insanity",
                                type = 'color',
                                order = 7,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergyDB.powerTypeColors["INSANITY"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergyDB.powerTypeColors["INSANITY"] = {r,g,b}
                                end,
                            },
                            PAIN = {
                                name = L"Pain",
                                type = 'color',
                                order = 8,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergyDB.powerTypeColors["PAIN"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergyDB.powerTypeColors["PAIN"] = {r,g,b}
                                end,
                            },
                            MAELSTROM = {
                                name = L"Maelstrom",
                                type = 'color',
                                order = 9,
                                width = 0.6,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergyDB.powerTypeColors["MAELSTROM"])
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergyDB.powerTypeColors["MAELSTROM"] = {r,g,b}
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
                                get = function(info) return NugEnergyDB.outOfCombatAlpha end,
                                set = function(info, v)
                                    NugEnergyDB.outOfCombatAlpha = tonumber(v)
                                    NugEnergy:Hide()
                                    NugEnergy:UPDATE_STEALTH()
                                end,
                                min = 0,
                                max = 1,
                                step = 0.05,
                                order = 1,
                            },
                            spenderFeedback = {
                                name = L"Spent / Ticker Fade",
                                desc = L"Fade effect after each tick or when spending",
                                type = "toggle",
                                width = 3,
                                order = 2,
                                get = function(info) return NugEnergyDB.spenderFeedback end,
                                set = function(info, v)
                                    NugEnergyDB.spenderFeedback = not NugEnergyDB.spenderFeedback
                                    NugEnergy:UpdateUpvalues()
                                    NugEnergy:UpdateBarEffects()
                                end
                            },
                            smoothing = {
                                name = L"Smoothing",
                                type = "toggle",
                                order = 3,
                                get = function(info) return NugEnergyDB.smoothing end,
                                set = function(info, v)
                                    NugEnergyDB.smoothing = not NugEnergyDB.smoothing
                                    NugEnergy:UpdateBarEffects()
                                end
                            },
                            smoothingSpeed = {
                                name = L"Animation Speed",
                                desc = L"Higher = Faster",
                                disabled = function() return not NugEnergyDB.smoothing end,
                                type = "range",
                                get = function(info) return NugEnergyDB.smoothingSpeed end,
                                set = function(info, v)
                                    NugEnergyDB.smoothingSpeed = tonumber(v)
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
                                get = function(info) return NugEnergyDB.textureName end,
                                set = function(info, value)
                                    NugEnergyDB.textureName = value
                                    NugEnergy:Resize()
                                end,
                                values = LSM:HashTable("statusbar"),
                                dialogControl = "LSM30_Statusbar",
                            },
                            width = {
                                name = L"Width",
                                type = "range",
                                get = function(info) return NugEnergyDB.width end,
                                set = function(info, v)
                                    NugEnergyDB.width = tonumber(v)
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
                                get = function(info) return NugEnergyDB.height end,
                                set = function(info, v)
                                    NugEnergyDB.height = tonumber(v)
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
                            --     get = function(info) return NugEnergyDB.outOfCombatAlpha end,
                            --     set = function(info, v)
                            --         NugEnergyDB.outOfCombatAlpha = tonumber(v)
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
                        get = function(info) return NugEnergyDB.isVertical end,
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
                                get = function(info) return NugEnergyDB.fontName end,
                                set = function(info, value)
                                    NugEnergyDB.fontName = value
                                    NugEnergy:ResizeText()
                                end,
                                values = LSM:HashTable("font"),
                                dialogControl = "LSM30_Font",
                            },
                            fontSize = {
                                name = L"Font Size",
                                type = "range",
                                order = 2,
                                get = function(info) return NugEnergyDB.fontSize end,
                                set = function(info, v)
                                    NugEnergyDB.fontSize = tonumber(v)
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
                                get = function(info) return NugEnergyDB.hideText end,
                                set = function(info, v)
                                    NugEnergyDB.hideText = not NugEnergyDB.hideText
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
                                get = function(info) return NugEnergyDB.textAlign end,
                                set = function(info, v)
                                    NugEnergyDB.textAlign = v
                                    NugEnergy:Resize()
                                end,
                            },
                            textOffsetX = {
                                name = L"Text Offset X",
                                type = "range",
                                order = 5,
                                get = function(info) return NugEnergyDB.textOffsetX end,
                                set = function(info, v)
                                    NugEnergyDB.textOffsetX = tonumber(v)
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
                                get = function(info) return NugEnergyDB.textOffsetY end,
                                set = function(info, v)
                                    NugEnergyDB.textOffsetY = tonumber(v)
                                    NugEnergy:Resize()
                                end,
                                min = -50,
                                max = 50,
                                step = 1,
                            },
                        },
                    },
                    classResourceGroup = {
                        type = "group",
                        name = "",
                        order = 4,
                        args = {
                            energy = {
                                name = L"Energy",
                                type = "toggle",
                                order = 1,
                                get = function(info) return NugEnergyDB.energy end,
                                set = function(info, v) NugEnergy.Commands.energy() end
                            },
                            rage = {
                                name = L"Rage",
                                type = "toggle",
                                order = 2,
                                get = function(info) return NugEnergyDB.rage end,
                                set = function(info, v) NugEnergy.Commands.rage() end
                            },
                            druidMana = {
                                name = L"Druid Mana",
                                type = "toggle",
                                order = 3,
                                get = function(info) return NugEnergyDB.manaDruid end,
                                set = function(info, v)
                                    NugEnergyDB.manaDruid = not NugEnergyDB.manaDruid
                                    NugEnergy:Initialize()
                                end
                            },
                            manaPriest = {
                                name = L"Priest Mana",
                                type = "toggle",
                                order = 4,
                                get = function(info) return NugEnergyDB.manaPriest end,
                                set = function(info, v)
                                    NugEnergyDB.manaPriest = not NugEnergyDB.manaPriest
                                    NugEnergy:Initialize()
                                end
                            },
                            mana = {
                                name = L"Mana all classes",
                                desc = "Toggle for all other classes",
                                type = "toggle",
                                order = 5,
                                get = function(info) return NugEnergyDB.mana end,
                                set = function(info, v)
                                    NugEnergyDB.mana = not NugEnergyDB.mana
                                    NugEnergy:Initialize()
                                end
                            },
                            enableFSR = {
                                name = L"5 Second Rule",
                                type = "toggle",
                                order = 6,
                                get = function(info) return NugEnergyDB.enableFSR end,
                                set = function(info, v)
                                    NugEnergyDB.enableFSR = not NugEnergyDB.enableFSR
                                    NugEnergy:Initialize()
                                end
                            },
                        },
                    },
                    energyTicker = {
                        name = L"Energy Ticker",
                        type = "toggle",
                        order = 4.9,
                        get = function(info) return NugEnergyDB.enableClassicTicker end,
                        set = function(info, v)
                            NugEnergyDB.enableClassicTicker = not NugEnergyDB.enableClassicTicker
                            tickerEnabled = NugEnergyDB.enableClassicTicker
                            NugEnergy:Initialize()
                        end
                    },
                    twGroup = {
                        type = "group",
                        name = L"Tick Window",
                        order = 5,
                        args = {
                            twEnabled = {
                                name = L"Enabled",
                                type = "toggle",
                                order = 1,
                                get = function(info) return NugEnergyDB.twEnabled end,
                                set = function(info, v)
                                    NugEnergyDB.twEnabled = not NugEnergyDB.twEnabled
                                    twEnabled = NugEnergyDB.twEnabled
                                end
                            },
                            twEnabledCappedOnly = {
                                name = L"Only If Capping",
                                type = "toggle",
                                width = "double",
                                order = 2,
                                get = function(info) return NugEnergyDB.twEnabledCappedOnly end,
                                set = function(info, v)
                                    NugEnergyDB.twEnabledCappedOnly = not NugEnergyDB.twEnabledCappedOnly
                                    twEnabledCappedOnly = NugEnergyDB.twEnabledCappedOnly
                                end
                            },

                            twChangeColor = {
                                name = L"Change Color",
                                type = "toggle",
                                width = "full",
                                order = 2.3,
                                get = function(info) return NugEnergyDB.twChangeColor end,
                                set = function(info, v)
                                    NugEnergyDB.twChangeColor = not NugEnergyDB.twChangeColor
                                    twChangeColor = NugEnergyDB.twChangeColor
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
                                    return NugEnergyDB.soundName
                                end,
                                set = function( info, v )
                                    NugEnergyDB.soundName = v
                                    NugEnergy:UpdateUpvalues()
                                end,
                            },
                            PlayButton = {
                                name = L"Play",
                                type = 'execute',
                                width = "half",
                                order = 7.7,
                                disabled = function() return (NugEnergyDB.soundNameFull == "none") end,
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
                                get = function(info) return NugEnergyDB.soundChannel end,
                                set = function( info, v ) NugEnergyDB.soundChannel = v end,
                            },
                            customsoundNameFull = {
                                name = L"Custom Sound",
                                type = 'input',
                                width = "full",
                                order = 7.8,
                                disabled = function() return (NugEnergyDB.soundName ~= "custom") end,
                                get = function(info) return NugEnergyDB.soundNameCustom end,
                                set = function( info, v )
                                    NugEnergyDB.soundNameCustom = v
                                end,
                            },

                            twStart = {
                                name = L"Start Time",
                                type = "range",
                                get = function(info) return NugEnergyDB.twStart end,
                                set = function(info, v)
                                    NugEnergyDB.twStart = tonumber(v)
                                    twStart = NugEnergyDB.twStart
                                end,
                                min = 0,
                                max = 2,
                                step = 0.01,
                                order = 3,
                            },
                            twLength = {
                                name = L"Window Length",
                                type = "range",
                                get = function(info) return NugEnergyDB.twLength end,
                                set = function(info, v)
                                    NugEnergyDB.twLength = tonumber(v)
                                    twLength = NugEnergyDB.twLength
                                end,
                                min = 0,
                                max = 1,
                                step = 0.01,
                                order = 4,
                            },
                            twCrossfade = {
                                name = L"Crossfade Length",
                                type = "range",
                                get = function(info) return NugEnergyDB.twCrossfade end,
                                set = function(info, v)
                                    NugEnergyDB.twCrossfade = tonumber(v)
                                    twCrossfade = NugEnergyDB.twCrossfade
                                end,
                                min = 0,
                                max = 0.5,
                                step = 0.01,
                                order = 5,
                            },
                        },
                    },
                },
            }, --
        },
    }

    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
    AceConfigRegistry:RegisterOptionsTable("NugEnergyOptions", opt)

    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    local panelFrame = AceConfigDialog:AddToBlizOptions("NugEnergyOptions", "NugEnergy")

    return panelFrame
end


local lastManaDropTime = 0
local GetPower_ClassicMana5SR = function(callback)
    return function(unit)
        local p = GetTime() - lastManaDropTime
        local mana = UnitPower(unit, PowerTypeIndex)
        local pmax = UnitPowerMax(unit, PowerTypeIndex)
        local p2
        if pmax > 0  then
            p2 = string.format("%d", mana/pmax*100)
        end
        local shine = nil
        local capped = nil
        local insufficient = nil
        if p >= 5 and callback then
            callback()
        end
        -- local p2 = throttleText and math_modf(p2/5)*5 or p2
        return p, p2, execute, shine, capped, true
    end
end
local UNIT_MAXPOWER_ClassicMana5SR = function(self)
    self:SetMinMaxValues(0, 5)
end

local GetPower_ClassicManaTicker = function(shineZone, cappedZone, minLimit, throttleText)
    return function(unit)
        local p = GetTime() - lastEnergyTickTime
        local mana = UnitPower(unit, PowerTypeIndex)
        local pmax = UnitPowerMax(unit, PowerTypeIndex)
        local p2
        if pmax > 0  then
            p2 = string.format("%d", mana/pmax*100)
        end
        local shine = shineZone and (p2 >= pmax-shineZone)
        local capped = mana >= pmax-cappedZone
        -- local p2 = throttleText and math_modf(p2/5)*5 or p2
        return p, p2, execute, shine, capped, (minLimit and mana < minLimit)
    end
end

function NugEnergy:SwitchToMana()
            PowerFilter = "MANA"
            PowerTypeIndex = Enum.PowerType.Mana
            self:SetNormalColor()
            lastEnergyValue = 0
            shouldBeFull = true
            twEnabled = false

            local switchToManaCallback = function()
                if NugEnergyDB.enableClassicTicker then
                    GetPower = GetPower_ClassicManaTicker(nil, 0, 0, false)
                    NugEnergy.UNIT_MAXPOWER = UNIT_MAXPOWER_ClassicTicker
                else
                    NugEnergy.UNIT_MAXPOWER = NugEnergy.NORMAL_UNIT_MAXPOWER
                    GetPower = RageBarGetPower(nil, 0, nil, true)
                end
                NugEnergy:UNIT_MAXPOWER()
            end

            if NugEnergyDB.enableFSR then
                self.FSRWatcher = self.FSRWatcher or self:Make5SRWatcher(function()
                    if PowerFilter == "MANA" then
                        GetPower = GetPower_ClassicMana5SR(switchToManaCallback)
                        NugEnergy.UNIT_MAXPOWER = UNIT_MAXPOWER_ClassicMana5SR
                        NugEnergy:UNIT_MAXPOWER()
                    end
                end)
                self.FSRWatcher:Enable()

                self:SetScript("OnUpdate",self.UpdateEnergy)
                ClassicTickerFrame:Enable()
                self:UpdateBarEffects()
                switchToManaCallback()

                self.UNIT_MAXPOWER = UNIT_MAXPOWER_ClassicTicker
                self:UNIT_MAXPOWER()
            else
                if self.FSRWatcher then self.FSRWatcher:Disable() end

                self:SetScript("OnUpdate",self.UpdateEnergy)
                ClassicTickerFrame:Enable()
                self:UpdateBarEffects()
                switchToManaCallback()
            end
end

function NugEnergy:Make5SRWatcher(callback)
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetScript("OnEvent", function(self, event, ...)
        return self[event](self, event, ...)
    end)


    local prevMana = UnitPower("player", 0)
    f.UNIT_SPELLCAST_SUCCEEDED = function(self, event, unit)
        if unit == "player" then
            local now = GetTime()
            if now - lastManaDropTime < 0.01 then
                callback()
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

    f.Enable = function(self)
        self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    end
    f.Disable = function(self)
        self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:UnregisterUnitEvent("UNIT_POWER_UPDATE", "player")
    end

    f:Enable()

    return f
end
