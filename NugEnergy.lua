local addonName, ns = ...

local spenderFeedback = true
local doFadeOut = true
local fadeAfter = 5
local fadeTime = 1
local onlyText = false
local shouldBeFull = false
local isFull = true
local isVertical

local APILevel = math.floor(select(4,GetBuildInfo())/10000)
local isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local isMainline = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
local isForever = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
local GlobalGetSpecialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or _G.GetSpecialization
local GetSpecialization = isForever and function() return 1 end or GlobalGetSpecialization
local GetNumSpecializations = isForever and function() return 1 end or _G.GetNumSpecializations
local GetSpecializationInfo = isForever and function() return nil end or (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or _G.GetSpecializationInfo)

NugEnergy = CreateFrame("Frame","NugEnergy",UIParent)

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
local math_max = math.max
local PowerFilter
local PowerTypeIndex
local ForcedToShow
local GetPower = function() return 0,0,0 end
local GetPowerMax-- = UnitPowerMax

local colorCurve

local executeRange = nil
local upvalueInCombat = nil

local EPT = Enum.PowerType
local Enum_PowerType_Insanity = EPT.Insanity
local Enum_PowerType_Energy = EPT.Energy
local Enum_PowerType_RunicPower = EPT.RunicPower
local Enum_PowerType_LunarPower = EPT.LunarPower
local Enum_PowerType_Focus = EPT.Focus
local class = select(2,UnitClass("player"))
local executeCurve = C_CurveUtil.CreateCurve();
executeCurve:SetType(Enum.LuaCurveType.Step)

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
            DEATHKNIGHT = { "RunicPower", "RunicPower", "RunicPower" },
            MAGE = { "Disabled", "Disabled", "Disabled" },
            WARRIOR = { "RageWarriorExecute", "RageWarriorExecute", "RageWarriorExecute" },
            SHAMAN = { "Maelstrom", "Disabled", "Disabled" },
            HUNTER = { "Focus", "Focus", "Focus" },
            PRIEST = { "Disabled", "Disabled", "Insanity" },
            EVOKER = { "Disabled", "Disabled", "Disabled" },
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
        borderType = "STATUSBAR",
        smoothing = true,
        smoothingSpeed = 6, -- 1 - 8

        width = 100,
        height = 30,
        normalColor = { 0.9, 0.1, 0.1 }, --1
        altColor = { 0.9, 0.168, 0.43 }, -- for dispatch and meta 2
        useMaxColor = true,
        maxColor = { 131/255, 0.2, 0.2 }, --max color 3
        lowColor = { 141/255, 31/255, 62/255 }, --low color 4
        enableColorByPowerType = false,
        powerTypeColors = {
            ["ENERGY"] = ColorArray(PowerBarColor["ENERGY"]),
            ["FOCUS"] = ColorArray(PowerBarColor["FOCUS"]),
            ["RAGE"] = ColorArray(PowerBarColor["RAGE"]),
            ["RUNIC_POWER"] = ColorArray(PowerBarColor["RUNIC_POWER"]),
            ["LUNAR_POWER"] = ColorArray(PowerBarColor["LUNAR_POWER"]),
            ["BALANCE"] = ColorArray(PowerBarColor["LUNAR_POWER"]),
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
        textColor = {1,1,1, 0.6},
        textOutline = "", -- can be "OUTLINE" or empty string
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

if isForever then
    defaults.global.classConfig = {
        ROGUE = { "EnergyRogue", "EnergyRogue", "EnergyRogue" },
        DRUID = { "ShapeshiftDruid", "ShapeshiftDruid", "ShapeshiftDruid", "ShapeshiftDruid" },
        PALADIN = { "Disabled", "Disabled", "Disabled" },
        MONK = { "Disabled", "Disabled", "Disabled" },
        WARLOCK = { "Disabled", "Disabled", "Disabled" },
        DEMONHUNTER = { "Disabled", "Disabled" },
        DEATHKNIGHT = { "RunicPower", "RunicPower", "RunicPower" },
        MAGE = { "Disabled", "Disabled", "Disabled" },
        WARRIOR = { "RageWarrior", "RageWarrior", "RageWarrior" },
        SHAMAN = { "Disabled", "Disabled", "Disabled" },
        HUNTER = { "Disabled", "Disabled", "Disabled" },
        PRIEST = { "Disabled", "Disabled", "Disabled" },
    }
end

local normalColor = defaults.profile.normalColor
local lowColor = defaults.profile.lowColor
local maxColor = defaults.profile.maxColor


local pmult = 1
local function pixelperfect(size)
    return floor(size/pmult + 0.5)*pmult
end

local GetNearestPixelSize = PixelUtil.GetNearestPixelSize
local ppScaleRegion = UIParent
function pixelperfect(size)
    return GetNearestPixelSize(size, ppScaleRegion:GetEffectiveScale())
end



function NugEnergy.PLAYER_LOGIN(self,event)
    _G.NugEnergyDB = _G.NugEnergyDB or {}
    self:DoMigrations(NugEnergyDB)
    self.db = LibStub("AceDB-3.0"):New("NugEnergyDB", defaults, "Default") -- Create a DB using defaults and using a shared default profile

    NugEnergy:UpdateUpvalues()

    NugEnergy:Initialize()

    SLASH_NUGENERGY1= "/nugenergy"
    SLASH_NUGENERGY2= "/nen"
    SlashCmdList["NUGENERGY"] = self.SlashCmd

    local f = CreateFrame('Frame', nil, SettingsPanel or InterfaceOptionsFrame)
        f:SetScript('OnShow', function(self)
            self:SetScript('OnShow', nil)

            if not NugEnergy.optionsPanel then
                local optionsPanel, categoryID = NugEnergy:CreateGUI()
                NugEnergy.optionsPanel = optionsPanel
                NugEnergy.settingsCategoryID = categoryID
            end
        end)
end

function NugEnergy:UpdateUpvalues()
    isVertical = false -- NugEnergy.db.profile.isVertical
    -- spenderFeedback = NugEnergy.db.profile.spenderFeedback
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

    self:UPDATE_STEALTH()
    self:UpdateEnergy()
    return true
end


function NugEnergy.UNIT_POWER_UPDATE(self,event,unit,powertype)
    if powertype == PowerFilter then self:UpdateEnergy() end
end
NugEnergy.UNIT_POWER_FREQUENT = NugEnergy.UNIT_POWER_UPDATE

function NugEnergy.UpdateEnergy(self, elapsed)
    local p, _, glowIntensity = GetPower("player")

    self.text:SetText(p)

    local c = UnitPowerPercent("player", PowerTypeIndex, false, colorCurve)

    local executeAlpha = 0
    if executeRange and UnitExists("target") then
        executeAlpha = UnitHealthPercent("target", nil, executeCurve)
    end
    self.execute:SetAlpha(executeAlpha)

    self:SetColor(c:GetRGBA())
    self.alertFrame:SetAlpha(glowIntensity)

    self.bar:SetValue(p)
    self.fade:SetValue(p, 1)
end
NugEnergy.Update = NugEnergy.UpdateEnergy


function NugEnergy:Disable()
    PowerFilter = nil
    PowerTypeIndex = nil
    self:UnregisterEvent("UNIT_POWER_UPDATE")
    self:UnregisterEvent("UNIT_MAXPOWER")
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    self:Hide()
end


function NugEnergy:SetExecuteRange(range)
    executeCurve:ClearPoints()
    executeCurve:AddPoint(0.0, 0.35)
    executeCurve:AddPoint(range, 0)
    executeRange = range
end

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
    if a < 0 then a = 0 end
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
        self.fade:Hide()
        fader:SetScript("OnUpdate", HideTimer)
        fader.OnUpdateCounter = 0
        self.hiding = true
    end
end

function NugEnergy:StopHiding()
    -- if self.hiding then
        self.fade:Show()
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
        ((class == "ROGUE" or class == "DRUID") and IsStealthed()) or
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


local colorOverride = nil
-- local cor, cog, cob = 1,1,1
function NugEnergy:DisableColorOverride()
    colorOverride = nil
end
function NugEnergy:SetColorOverride(r,g,b)
    colorOverride = {r,g,b}
    self:SetNormalColor()
end




colorCurve = C_CurveUtil.CreateColorCurve()
colorCurve:SetType(Enum.LuaCurveType.Step);
local currentCapLimit = 1
local currentMinLimit = nil
function NugEnergy:SetColorThresholds(capLimit, minLimit)
    currentCapLimit = capLimit
    currentMinLimit = minLimit
    colorCurve:ClearPoints()
    local normalStart = 0.0
    if minLimit then
        colorCurve:AddPoint(0.0, CreateColor(unpack(lowColor)))
        normalStart = minLimit
    end
    colorCurve:AddPoint(normalStart, CreateColor(unpack(normalColor)))
    colorCurve:AddPoint(capLimit, CreateColor(unpack(maxColor)))
end

function NugEnergy:SetNormalColor()
    if colorOverride then
        normalColor = colorOverride
        lowColor = { hsv_shift(normalColor, -0.07, -0.22, -0.3) }
        maxColor = { hsv_shift(normalColor, 0, -0.3, -0.4) }
    elseif NugEnergy.db.profile.enableColorByPowerType and PowerFilter then
        normalColor = NugEnergy.db.profile.powerTypeColors[PowerFilter]
        lowColor = { hsv_shift(normalColor, -0.07, -0.22, -0.3) }
        maxColor = { hsv_shift(normalColor, 0, -0.3, -0.4) }
    else
        normalColor = NugEnergy.db.profile.normalColor
        lowColor = NugEnergy.db.profile.lowColor
        maxColor = NugEnergy.db.profile.maxColor
    end
    if not NugEnergy.db.profile.useMaxColor then
        maxColor = normalColor
    end
    NugEnergy:SetColorThresholds(currentCapLimit, currentMinLimit)
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
            text:SetJustifyV("MIDDLE")
        elseif textAlign == "START" then
            text:SetPoint("BOTTOM", f, "BOTTOM", 0+NugEnergy.db.profile.textOffsetX, 0+NugEnergy.db.profile.textOffsetY)
            text:SetJustifyV("BOTTOM")
        end

        text:SetJustifyH("CENTER")

    else
        self:SetWidth(width)
        self:SetHeight(height)

        self.bar:SetOrientation("HORIZONTAL")

        text:ClearAllPoints()
        local textAlign = NugEnergy.db.profile.textAlign
        if textAlign == "END" then
            text:SetPoint("RIGHT", f, "RIGHT", -7+NugEnergy.db.profile.textOffsetX, -1+NugEnergy.db.profile.textOffsetY)
            text:SetJustifyH("RIGHT")
        elseif textAlign == "CENTER" then
            text:SetPoint("CENTER", f, "CENTER", 0+NugEnergy.db.profile.textOffsetX, -1+NugEnergy.db.profile.textOffsetY)
            text:SetJustifyH("CENTER")
        elseif textAlign == "START" then
            text:SetPoint("LEFT", f, "LEFT", 7+NugEnergy.db.profile.textOffsetX, -1+NugEnergy.db.profile.textOffsetY)
            text:SetJustifyH("LEFT")
        end

        text:SetJustifyV("MIDDLE")
    end

    if not onlyText then
        self:UpdateEnergy()

        local tex = getStatusbar()
        self.bar:SetStatusBarTexture(tex)
        self.bar.bg:SetTexture(tex)
    end
end

function NugEnergy:ResizeText()
    local text = self.text
    local font = getFont()
    local fontSize = NugEnergy.db.profile.fontSize
    text:SetFont(font,fontSize, NugEnergy.db.profile.textOutline)
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
    self = self.bar
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
    local width = NugEnergy.db.profile.width
    local height = NugEnergy.db.profile.height

    local f = CreateFrame("StatusBar", "NugEnergyBar", self)
    if isVertical then
        height, width = width, height
        f:SetOrientation("VERTICAL")
    end
    self:SetWidth(width)
    self:SetHeight(height)

    self.bar = f

    f:SetFrameLevel(10)
    f:SetAllPoints(self)

    self:UpdateFrameBorder()

    local tex = getStatusbar()
    f:SetStatusBarTexture(tex)
    -- f:SetStatusBarTexture("Interface\\BUTTONS\\WHITE8X8")
    -- f:SetStatusBarColor(0,0,0,0.7)
    -- f:SetFillStyle(Enum.StatusBarFillStyle.Reverse)
    -- f:SetReverseFill(true)
    local barTex = f:GetStatusBarTexture()

    local bg = self:CreateTexture(nil,"BACKGROUND")
    bg:SetTexture(tex)
    bg:SetAllPoints(f)
    f.bg = bg

    local missingPart = self:CreateTexture(nil,"BACKGROUND", nil, 2)
    missingPart:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    missingPart:SetVertexColor(0,0,0,0.7)
    missingPart:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT",0,0)
    missingPart:SetPoint("TOPLEFT", barTex, "TOPRIGHT",0,0)


    local spark = f:CreateTexture(nil, "ARTWORK", nil, 4)
    spark:SetBlendMode("ADD")
    spark:SetTexture([[Interface\AddOns\NugEnergy\spark.tga]])
    if isVertical then
        spark:SetSize(f:GetWidth(), f:GetWidth()*2)
        spark:SetTexCoord(1,1,0,1,1,0,0,0)
    else
        spark:SetWidth(height*2)
        spark:SetPoint("TOP", barTex, "TOPRIGHT",0,0)
        spark:SetPoint("BOTTOM", barTex, "BOTTOMRIGHT",0,0)
    end
    f.spark = spark

    local fade = CreateFrame("StatusBar", "NugEnergyBar", self)
    fade:SetUsingParentLevel(true)
    fade:SetStatusBarTexture("Interface\\BUTTONS\\WHITE8X8")
    fade:SetStatusBarColor(1,0.3,0.3)
    fade:SetAllPoints(self)
    self.fade = fade


    local execute = f:CreateTexture(nil, "ARTWORK", nil, 3)
    -- execute:SetVertexColor(unpack(NugEnergy.db.profile.altColor))
    execute:SetTexture([[Interface\AddOns\NugEnergy\executeIcon.tga]])
    -- execute:SetAtlas("icons_64x64_deadly")
    execute:SetBlendMode("ADD")
    execute:SetSize(height, height)
    execute:SetPoint("LEFT", self, "LEFT", 5,0)
    f.execute = execute
    self.execute = execute

    self.SetColor = function(self, r,g,b,a)
        local bar = self.bar
        bar:SetStatusBarColor(r,g,b)
        bar.bg:SetVertexColor(r,g,b)
        bar.spark:SetVertexColor(r,g,b)
        bar.execute:SetVertexColor(r,g,b)
    end

    local color = NugEnergy.db.profile.normalColor
    self:SetColor(unpack(color))


    local at = CreateFrame("Frame", nil, self, BackdropTemplateMixin  and "BackdropTemplate")
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
    self.alertFrame = at

    --[[
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
    ]]

    local text = f:CreateFontString(nil, "OVERLAY")
    local font = getFont()
    local fontSize = NugEnergy.db.profile.fontSize
    text:SetFont(font,fontSize, NugEnergy.db.profile.textOutline)

    local r,g,b,a = unpack(NugEnergy.db.profile.textColor)
    text:SetTextColor(r,g,b)
    text:SetAlpha(a)
    self.text = text

    NugEnergy:Resize()

    if NugEnergy.db.profile.hideText then
        text:Hide()
    else
        text:Show()
    end

    self:SetPoint(NugEnergy.db.profile.point, UIParent, NugEnergy.db.profile.point, NugEnergy.db.profile.x, NugEnergy.db.profile.y)

    local oocA = NugEnergy.db.profile.outOfCombatAlpha
    if oocA > 0 then
        self:SetAlpha(oocA)
    else
        self:Hide()
    end

    self:EnableMouse(false)
    self:RegisterForDrag("LeftButton")
    self:SetMovable(true)
    self:SetScript("OnDragStart",function(self) self:StartMoving() end)
    self:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing();
        local _
        _,_, NugEnergy.db.profile.point, NugEnergy.db.profile.x, NugEnergy.db.profile.y = self:GetPoint(1)
    end)
end


local ParseOpts = function(str)
    local fields = {}
    for opt,args in string.gmatch(str,"(%w*)%s*=%s*([%w%,%-%_%.%:%\\%']+)") do
        fields[opt:lower()] = tonumber(args) or args
    end
    return fields
end

local function InterfaceOptions_AddCategory(frame, addOn, position)
	-- cancel is no longer a default option. May add menu extension for this.
	frame.OnCommit = frame.okay;
	frame.OnDefault = frame.default;
	frame.OnRefresh = frame.refresh;

	if frame.parent then
		local category = Settings.GetCategory(frame.parent);
		local subcategory, layout = Settings.RegisterCanvasLayoutSubcategory(category, frame, frame.name, frame.name);
		subcategory.ID = frame.name;
		return subcategory, category;
	else
		local category, layout = Settings.RegisterCanvasLayoutCategory(frame, frame.name, frame.name);
		category.ID = frame.name;
		Settings.RegisterAddOnCategory(category);
		return category;
	end
end

-- Deprecated. Use Settings.OpenToCategory().
local function InterfaceOptionsFrame_OpenToCategory(categoryIDOrFrame)
	if type(categoryIDOrFrame) == "table" then
		local categoryID = categoryIDOrFrame.name;
		return Settings.OpenToCategory(categoryID);
	else
		return Settings.OpenToCategory(categoryIDOrFrame);
	end
end

NugEnergy.Commands = {
    ["gui"] = function(v)
        if not NugEnergy.optionsPanel then
            local optionsPanel, categoryID = NugEnergy:CreateGUI()
            NugEnergy.optionsPanel = optionsPanel
            NugEnergy.settingsCategoryID = categoryID
        end
        Settings.OpenToCategory(NugEnergy.settingsCategoryID)
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
                            --[[
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
                            ]]
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
                        width = "full",
                        order = 1.1,
                        get = function(info) return NugEnergy.db.profile.enableColorByPowerType end,
                        set = function(info, v)
                            NugEnergy.db.profile.enableColorByPowerType = not NugEnergy.db.profile.enableColorByPowerType
                            NugEnergy:SetNormalColor()
                        end
                    },
                    useMaxColor = {
                        name = L"Recolor when Capped",
                        type = "toggle",
                        width = "full",
                        order = 1.11,
                        get = function(info) return NugEnergy.db.profile.useMaxColor end,
                        set = function(info, v)
                            NugEnergy.db.profile.useMaxColor = not NugEnergy.db.profile.useMaxColor
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
                    --[[
                    isVertical = {
                        name = L"Vertical",
                        type = "toggle",
                        order = 2.5,
                        get = function(info) return NugEnergy.db.profile.isVertical end,
                        set = function(info, v) NugEnergy.Commands.vertical() end
                    },
                    ]]
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
                                width = 0.7,
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
                            outline = {
                                name = L"Ouline",
                                type = "toggle",
                                width = 0.6,
                                order = 2.1,
                                get = function(info) return NugEnergy.db.profile.textOutline == "OUTLINE" end,
                                set = function(info, v)
                                    if NugEnergy.db.profile.textOutline ~= "OUTLINE" then
                                        NugEnergy.db.profile.textOutline = "OUTLINE"
                                    else
                                        NugEnergy.db.profile.textOutline = ""
                                    end
                                    NugEnergy:ResizeText()
                                end,
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
            width = 3.2,
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
    local panelFrame, categoryID = AceConfigDialog:AddToBlizOptions("NugEnergyOptions", "NugEnergy")

    return panelFrame, categoryID
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
    self:DisableColorOverride()
    self.eventProxy:UnregisterAllEvents()
    executeRange = nil
    self.eventProxy:SetScript("OnUpdate", nil)
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