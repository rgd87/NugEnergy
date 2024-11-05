local tex = [[Interface\AddOns\NugEnergy\statusbar.tga]]
local width = 100
local height = 30
-- local font = [[Interface\AddOns\NugEnergy\Emblem.ttf]]
local font = [[Interface\AddOns\NugEnergy\OpenSans-Bold.ttf]]
local fontSize = 25
local color = { 0.9,0.1,0.1 }
local color2 = { .9,0.1,0.4 } -- for dispatch and meta
local textcolor = { 1,1,1 }
local onlyText = false

local db

NugEnergy = CreateFrame("StatusBar","NugEnergy",UIParent)

NugEnergy:SetScript("OnEvent", function()
	return this[event](this, event, arg1, arg2, arg3)
end)
NugEnergy:RegisterEvent("PLAYER_LOGIN");
NugEnergy:RegisterEvent("PLAYER_LOGOUT");
local UnitPower = UnitPower
local math_modf = math.modf

local PowerFilter
local ForcedToShow
local GetPower = UnitMana
local GetPowerMax = UnitManaMax
local shouldBeFull = false
local isFull = true
local isEmpty = true
local doFadeOut = true
local fadeAfter = 5
local fadeTime = 1


local PowerTypeEnum = {
    MANA = 0,
    RAGE = 1,
    ENERGY = 3,
}

local ColorArray = function(t) return { t.r, t.g, t.b } end

local defaults = {
    profile = {
        point = "CENTER",
        x = 0, y = 0,
        fontSize = 25,
        energy = true,
        rage = true,
        enableColorByPowerType = false,
        normalColor = { 0.9, 0.1, 0.1 }, --1
        altColor = { 0.9, 0.168, 0.43 }, -- for dispatch and meta 2
        useMaxColor = true,
        maxColor = { 131/255, 0.2, 0.2 }, --max color 3
        lowColor = { 141/255, 31/255, 62/255 }, --low color 4
        outOfCombatAlpha = 0,

        borderType = "STATUSBAR",

        twEnabled = false,
        twColor = { 0.15, 0.9, 0.4 }, -- tick window color

        powerTypeColors = {
            [3] = ColorArray(ManaBarColor[3]),
            [1] = ColorArray(ManaBarColor[1]),
            [0] = ColorArray(ManaBarColor[0]),
        },
    },
}

local normalColor = defaults.profile.normalColor
local lowColor = defaults.profile.lowColor
local maxColor = defaults.profile.maxColor

local tickerEnabled
local twEnabled
local twEnabledCappedOnly = true
local twStart = 0.9
local twLength = 0.4
local twCrossfade = 0.15
local twChangeColor = true
-- local twPlaySound


-- local function SetupDefaults(t, defaults)
--     for k,v in pairs(defaults) do
--         if type(v) == "table" then
--             if t[k] == nil then
--                 t[k] = CopyTable(v)
--             else
--                 SetupDefaults(t[k], v)
--             end
--         else
--             if t[k] == nil then t[k] = v end
--         end
--     end
-- end

-- local function RemoveDefaults(t, defaults)
--     if not defaults then return end
--     for k, v in pairs(defaults) do
--         if type(t[k]) == 'table' and type(v) == 'table' then
--             ns.RemoveDefaults(t[k], v)
--             if next(t[k]) == nil then
--                 t[k] = nil
--             end
--         elseif t[k] == v then
--             t[k] = nil
--         end
--     end
--     return t
-- end


function NugEnergy.PLAYER_LOGIN(self,event,arg1)
    NugEnergyDB = NugEnergyDB or {}
    db = LibStub("AceDB-3.0"):New("NugEnergyDB", defaults, "Default") -- Create a DB using defaults and using a shared default profile
    self.db = db
    -- SetupDefaults(db, defaults)

    twEnabled = db.profile.twEnabled

    NugEnergy:Create()
    NugEnergy:Initialize()

    SLASH_NUGENERGY1= "/nugenergy"
    SLASH_NUGENERGY2= "/nen"
    SlashCmdList["NUGENERGY"] = self.SlashCmd
end

-- function NugComboBar:PLAYER_LOGOUT(event)
-- 	RemoveDefaults(db, defaults)
-- end




-- Ticker
local lastEnergyTickTime = GetTime()
local lastEnergyValue = 0
local heartbeatPlayed = false
local GetPower_ClassicRogueTicker = function(shineZone, cappedZone, minLimit, throttleText)
    return function(unit)
        local p = GetTime() - lastEnergyTickTime
        local p2 = UnitMana(unit)
        local pmax = UnitManaMax(unit)
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
        local cA = db.profile.twColor
        self:SetColor(GetGradientColor(cN, cA, fp))
    elseif tp > twStart then
        local fp = twCrossfade > 0 and  ((twStart + twCrossfade - tp) / twCrossfade) or 0
        if fp < 0 then fp = 0 end
        local cN = prevColor
        local cA = db.profile.twColor
        self:SetColor(GetGradientColor(cA, cN, fp))
    elseif tp >= 0 then
        local cN = prevColor
        self:SetColor(unpack(cN))
    end
end


local ClassicTickerFrame = CreateFrame("Frame")

local maxEnergy = 100
local tickFiltering = true
local ClassicTickerOnUpdate = function(self)
    local currentEnergy = UnitMana("player")
    local now = GetTime()
    local possibleTick = false
    if currentEnergy > lastEnergyValue then
        -- Mana tick
        if PowerTypeIndex == 0 then
            local replenished = currentEnergy - lastEnergyValue
            local deviation = currentEnergy - lastEnergyValue - manaPerTick
            -- Actual mana tick is always integer so there are deviations
            if (deviation > -1.5) and (deviation < 1.5) then
                possibleTick = true
            end
        else
            if tickFiltering then
                local diff = currentEnergy - lastEnergyValue
                if  (diff > 18 and diff < 22) or -- normal tick
                    (diff > 38 and diff < 42) or -- adr rush
                    (diff < 42 and currentEnergy == maxEnergy) -- including tick to cap, but excluding thistle tea
                then
                    possibleTick = true
                end
            else
                possibleTick = true
            end
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
ClassicTickerFrame.Enable = function(self)
    self:SetScript("OnUpdate", ClassicTickerOnUpdate)
    tickerEnabled = true
    self.isEnabled = true
end
ClassicTickerFrame.Disable = function(self)
    self:SetScript("OnUpdate", nil)
    tickerEnabled = false
    self.isEnabled = false
end
local UNIT_MAXPOWER_ClassicTicker = function(self)
    maxEnergy = UnitManaMax("player")
    self:SetMinMaxValues(0, 2)
end



-- Power Getter Gen
local RageBarGetPower = function(shineZone, cappedZone, minLimit, throttleText)
    return function(unit)
        local p = UnitMana(unit)
        local pmax = UnitManaMax(unit)
        local shine = shineZone and (p >= pmax-shineZone)
        -- local state
        -- if p >= pmax-10 then state = "CAPPED" end
        -- if GetSpecialization() == 3  p < 60 pmax-10
        local capped = p >= pmax-cappedZone
        local p2 = throttleText and math_modf(p/5)*5
        return p, p2, execute, shine, capped, (minLimit and p < minLimit)
    end
end


do
    local timerFrame
    function NugEnergy:RunTimer(timerDuration, func)
        timerFrame = timerFrame or CreateFrame("Frame")
        local startTime = GetTime()
        timerFrame:Show()
        timerFrame:SetScript("OnUpdate", function()
            -- local elapsed = arg1
            local now = GetTime()
            if now - startTime > timerDuration then
                func()
                this:Hide()
                this:SetScript("OnUpdate", nil)
            end
        end)
        return timerFrame
    end
    function NugEnergy:CancelTimer()
        if timerFrame then
            timerFrame:Hide()
            timerFrame:SetScript("OnUpdate", nil)
        end
    end
end

function NugEnergy.Initialize(self)
    self.UNIT_ENERGY = self.UNIT_POWER
    self.UNIT_MAXENERGY = self.UNIT_MAXPOWER
    self.UNIT_RAGE = self.UNIT_POWER
    self.UNIT_MAXRAGE = self.UNIT_MAXPOWER
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.PLAYER_REGEN_ENABLED = self.UPDATE_STEALTH
    self.PLAYER_REGEN_DISABLED = self.UPDATE_STEALTH

    local _, class = UnitClass("player")
    if class == "ROGUE" then
        PowerFilter = PowerTypeEnum.ENERGY
        -- self:SetNormalColor()
        -- twEnabled = NugEnergyDB.twEnabled
        shouldBeFull = true
        self:RegisterEvent("UPDATE_STEALTH")
        self:RegisterEvent("UNIT_AURA")
        self:RegisterEvent("UNIT_ENERGY")
        self:RegisterEvent("UNIT_MAXENERGY")

        if true then
            GetPower = GetPower_ClassicRogueTicker(nil, 19, 0, false)
            ClassicTickerFrame:Enable()
            self:SetScript("OnUpdate",function() NugEnergy:UpdateEnergy() end)
            NugEnergy.UNIT_MAXENERGY = UNIT_MAXPOWER_ClassicTicker
            NugEnergy.UNIT_MAXPOWER = UNIT_MAXPOWER_ClassicTicker
        end
        self:UNIT_MAXPOWER()
    elseif class == "DRUID" then
        self:RegisterEvent("UNIT_DISPLAYPOWER")
        self:RegisterEvent("UPDATE_STEALTH")
        self:RegisterEvent("UNIT_AURA")
        local switchFromEnergyTimestamp = GetTime()
        local energyInHumanFormTimer

        local disable = function()
            PowerFilter = nil
            ForcedToShow = nil
            self:UnregisterEvent("UNIT_RAGE")
            self:UnregisterEvent("UNIT_MAXRAGE")
            self:UnregisterEvent("UNIT_ENERGY")
            self:UnregisterEvent("UNIT_MAXENERGY")
            self:UnregisterEvent("PLAYER_REGEN_DISABLED")
            self:SetScript("OnUpdate", nil)
            self:UPDATE_STEALTH()
        end

        self:SetScript("OnUpdate",function() NugEnergy:UpdateEnergy() end)
        -- self.UNIT_DISPLAYPOWER = function(self)
        --     if UnitPowerType("player") == PowerTypeEnum.ENERGY then
        --         PowerFilter = PowerTypeEnum.ENERGY
        --     elseif db.profile.rage then
        --         PowerFilter = PowerTypeEnum.RAGE
        --     end
        --     self:UPDATE_STEALTH()
        -- end
        -- self:UNIT_DISPLAYPOWER()

        self.UNIT_DISPLAYPOWER = function(self)
            local newPowerType = UnitPowerType("player")
            shouldBeFull = false

            if newPowerType == PowerTypeEnum.ENERGY and db.profile.energy then
                PowerFilter = PowerTypeEnum.ENERGY
                -- twEnabled = db.profile.twEnabled
                self:SetNormalColor()
                shouldBeFull = true
                self:RegisterEvent("UNIT_ENERGY")
                self:RegisterEvent("UNIT_MAXENERGY")
                self.PLAYER_REGEN_ENABLED = self.UPDATE_STEALTH
                self.PLAYER_REGEN_DISABLED = self.UPDATE_STEALTH

                if true then
                    GetPower = GetPower_ClassicRogueTicker(nil, 19, 0, false)
                    NugEnergy.UNIT_MAXPOWER = UNIT_MAXPOWER_ClassicTicker
                    NugEnergy.UNIT_MAXENERGY = UNIT_MAXPOWER_ClassicTicker
                    self:SetScript("OnUpdate", function() NugEnergy:UpdateEnergy() end)
                    ClassicTickerFrame:Enable()
                end
                if energyInHumanFormTimer then
                    NugEnergy:CancelTimer()
                    energyInHumanFormTimer = nil
                end
                self:UNIT_MAXPOWER()
                self:RegisterEvent("PLAYER_REGEN_DISABLED")
                self:UPDATE_STEALTH()
            elseif newPowerType == PowerTypeEnum.RAGE and db.profile.rage then
                PowerFilter = PowerTypeEnum.RAGE
                self:SetNormalColor()
                shouldBeFull = false
                self:RegisterEvent("UNIT_RAGE")
                self:RegisterEvent("UNIT_MAXRAGE")
                NugEnergy.UNIT_MAXPOWER = NugEnergy.NORMAL_UNIT_MAXPOWER
                NugEnergy.UNIT_MAXRAGE = NugEnergy.NORMAL_UNIT_MAXPOWER
                self.PLAYER_REGEN_ENABLED = self.UPDATE_STEALTH
                self.PLAYER_REGEN_DISABLED = self.UPDATE_STEALTH
                if energyInHumanFormTimer then
                    NugEnergy:CancelTimer()
                    energyInHumanFormTimer = nil
                end
                GetPower = RageBarGetPower(30, 10, nil, nil)
                self:RegisterEvent("PLAYER_REGEN_DISABLED")
                self:SetScript("OnUpdate", nil)
                self:UNIT_MAXPOWER()
                self:UPDATE_STEALTH()
            elseif newPowerType == PowerTypeEnum.MANA then
                shouldBeFull = true
                local druidPowershifting = true
                if PowerFilter == PowerTypeEnum.ENERGY and druidPowershifting then
                    if not energyInHumanFormTimer then
                        switchFromEnergyTimestamp = GetTime()
                        energyInHumanFormTimer = NugEnergy:RunTimer(10, function()
                            NugEnergy:UNIT_DISPLAYPOWER()
                        end)
                    end
                    if GetTime() - switchFromEnergyTimestamp > 9 then
                        disable()
                    end
                    return
                else
                    disable()
                end
            else
                disable()
            end
            self:UpdateEnergy()
        end
        self:UNIT_DISPLAYPOWER()
    elseif class == "WARRIOR" and db.profile.rage then
        PowerFilter = PowerTypeEnum.RAGE
        self:RegisterEvent("UNIT_RAGE")
        self:RegisterEvent("UNIT_MAXRAGE")


        GetPower = RageBarGetPower(30, 10, nil, nil)
        -- if IsAnySpellKnown(20662, 20661, 20660, 20658, 5308) then
        --     execute_range = 0.2
        --     self:RegisterUnitEvent("UNIT_HEALTH", "target")
        --     self:RegisterEvent("PLAYER_TARGET_CHANGED")
        -- end
    else
        self:UnregisterAllEvents()
        self:SetScript("OnUpdate", nil)
        self:Hide()
        return false
    end

    self:UPDATE_STEALTH()
    self:UNIT_POWER(nil, "player", PowerFilter)
    return true
end



function FindUnitAuraByIcon(unit, searchIcon)
	for i=1,32 do
        local icon, id = UnitBuff(unit, i)
        if not icon then return false end
		if icon == searchIcon then
			return true
		end
	end
end
local _, pclass = UnitClass("player")
local IsStealthed
if pclass == "ROGUE" then
    IsStealthed = function()
        return FindUnitAuraByIcon("player", "Interface\\Icons\\Ability_Stealth")
    end
elseif pclass == "DRUID" then
    IsStealthed = function()
        return FindUnitAuraByIcon("player", "Interface\\Icons\\Ability_Ambush")
    end
else
    IsStealthed = function()
        return false
    end
end



function NugEnergy.UNIT_POWER(self,event,unit,powertype)
    self:UpdateEnergy()
    if not shouldBeFull then
        self:UPDATE_STEALTH()
    end
end
function NugEnergy.UpdateEnergy(self)
    -- print(this:GetName(), this.text.SetText)
    -- local p, p2 = GetPower("player")
    -- p2 = p2 or p
    -- this.text:SetText(p2)
    -- if not onlyText then
    --     this:SetValue(p)
    -- end


    local p, p2, _, shine, capped, insufficient = GetPower("player")
    local wasFull = isFull
    isFull = p == GetPowerMax("player", PowerTypeIndex)
    local wasEmpty = isEmpty
    isEmpty = p == 0
    if isFull ~= wasFull or isEmpty ~= wasEmpty then
        NugEnergy:UPDATE_STEALTH(nil, true)
    end

    p2 = p2 or p
    if p2 > 200 then p2 = "" end
    self.text:SetText(p2)
    if not onlyText then
        -- if shine and upvalueInCombat then
        --     -- self.glow:Show()
        --     if not self.glow:IsPlaying() then self.glow:Play() end
        -- else
        --     -- self.glow:Hide()
        --     self.glow:Stop()
        -- end
        local c
        if capped then
            c = maxColor
        -- elseif execute then
        --     c = NugEnergy.db.profile.altColor
        elseif insufficient then
            c = lowColor
        else
            c = normalColor
        end

        self:SetColor(unpack(c))

        if twEnabled and tickerEnabled and (not twEnabledCappedOnly or capped) and GetTickProgress() > twStart then

            -- if twPlaySound then
            --     local now = GetTime()
            --     heartbeatEligible = IsStealthed() and UnitExists("target") and not UnitIsFriend("target", "player") and GetUnitSpeed("player") > 0
            --     if heartbeatEligible then
            --         heartbeatEligibleLastTime = now
            --     end

            --     if not heartbeatPlayed and now - heartbeatEligibleLastTime < heartbeatEligibleTimeout then
            --         heartbeatPlayed = true
            --         self:PlaySound()
            --     end
            -- end

            if twChangeColor then
                ClassicTickerColorUpdate(self, GetTickProgress(), c)
            end
        end

        self:SetValue(p)
    end
end
function NugEnergy.UNIT_MAXPOWER(self)
    self:SetMinMaxValues(0,GetPowerMax("player"))
end
NugEnergy.NORMAL_UNIT_MAXPOWER = NugEnergy.UNIT_MAXPOWER

function NugEnergy.UPDATE_STEALTH(self)
    -- print("Update Stealth", IsStealthed() or UnitAffectingCombat("player"), (not isEmpty and not shouldBeFull), PowerFilter)
    if (IsStealthed() or UnitAffectingCombat("player") or ForcedToShow or (not isEmpty and not shouldBeFull)) and PowerFilter then
        self:UNIT_MAXPOWER()
        self:UpdateEnergy()
        self:Show()
        -- print("Showing")
    else
        self:Hide()
        -- print("Hiding")
    end
end
NugEnergy.UNIT_AURA = NugEnergy.UPDATE_STEALTH


function NugEnergy:UpdateFrameBorder()
    local borderType = NugEnergy.db.profile.borderType

    if self.border then self.border:Hide() end
    if self.backdrop then self.backdrop:Hide() end

    if borderType == "2PX" then
        self.backdrop = self.backdrop or self:CreateTexture(nil, "BACKGROUND", nil, -2)
        local backdrop = self.backdrop
        local offset = 2
        backdrop:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        backdrop:SetVertexColor(0,0,0, 0.5)
        backdrop:SetPoint("TOPLEFT", -offset, offset)
        backdrop:SetPoint("BOTTOMRIGHT", offset, -offset)
        backdrop:Show()

    elseif borderType == "1PX" then
        self.backdrop = self.backdrop or self:CreateTexture(nil, "BACKGROUND", nil, -2)
        local backdrop = self.backdrop
        local offset = 1
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

function NugEnergy:ResizeText()
    local text = self.text
    -- local font = getFont()
    local fontSize = NugEnergy.db.profile.fontSize
    text:SetFont(font,fontSize, NugEnergy.db.profile.textOutline)
    -- local r,g,b,a = unpack(NugEnergy.db.profile.textColor)
    local r,g,b,a = 1,1,1,0.7
    text:SetTextColor(r,g,b)
    text:SetAlpha(a)
    if NugEnergy.db.profile.hideText then
        text:Hide()
    else
        text:Show()
    end
end

function NugEnergy.Create(self)
    local f = self
    f:SetWidth(width)
    f:SetHeight(height)

    if not onlyText then
        -- local backdrop = {
        --     bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 0,
        --     insets = {left = -2, right = -2, top = -2, bottom = -2},
        -- }
        -- f:SetBackdrop(backdrop)
        -- f:SetBackdropColor(0,0,0,0.5)
        f:SetStatusBarTexture(tex)
        f:SetStatusBarColor(unpack(color))

        self:UpdateFrameBorder()

        local bg = f:CreateTexture(nil,"BACKGROUND")
        bg:SetTexture(tex)
        bg:SetVertexColor(color[1]/2,color[3]/2,color[3]/2)
        bg:SetAllPoints(f)
        f.bg = bg
        f:UNIT_MAXPOWER()
    end

    local text = f:CreateFontString(nil, "OVERLAY")
    -- text:SetFont(font,fontSize)
    text:SetPoint("TOPLEFT",f,"TOPLEFT",0,0)
    text:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-10,0)
    text:SetJustifyH("RIGHT")
    -- text:SetTextColor(unpack(textcolor))
    f.text = text
    NugEnergy:ResizeText()

    f.SetColor = function(self, r,g,b,a)
        self:SetStatusBarColor(r,g,b,a)
        self.bg:SetVertexColor(r*0.3,g*0.3,b*0.3)
    end

    f:SetPoint(db.profile.point, UIParent, db.profile.point, db.profile.x, db.profile.y)

    local oocA = db.profile.outOfCombatAlpha
    if oocA > 0 then
        f:SetAlpha(oocA)
    else
        f:Hide()
    end

    f:EnableMouse(false)
    f:RegisterForDrag("LeftButton")
    f:SetMovable(true)
    f:SetScript("OnDragStart",function() this:StartMoving() end)
    f:SetScript("OnDragStop",function()
        this:StopMovingOrSizing();
        _,_, NugEnergy.db.profile.point, NugEnergy.db.profile.x, NugEnergy.db.profile.y = this:GetPoint(1)
    end)
end

local ParseOpts = function(str)
    local fields = {}
    for opt,args in string.gfind(str,"(%w*)%s*=%s*([%w%,%-%_%.%:%\\%']+)") do
        fields[opt:lower()] = tonumber(args) or args
    end
    return fields
end
function NugEnergy.SlashCmd(msg)
    local _,_,k,v = string.find(msg, "([%w%+%-%=]+) ?(.*)")
    if not k or k == "help" then print([[Usage:
      |cff00ff00/nen lock|r
      |cff00ff00/nen unlock|r
      |cff00ff00/nen rage|r
      |cff00ff00/nen energy|r
      |cff00ff00/nen powerTypeColor|r
      |cff00ff00/nen tickWindow|r
      |cff00ff00/nen reset|r]]
    )end
    if k == "unlock" then
        NugEnergy:EnableMouse(true)
        ForcedToShow = true
        NugEnergy:UPDATE_STEALTH()
    end
    if k == "lock" then
        NugEnergy:EnableMouse(false)
        ForcedToShow = nil
        NugEnergy:UPDATE_STEALTH()
    end
    if k == "reset" then
        NugEnergy:SetPoint("CENTER",UIParent,"CENTER",0,0)
    end
    if k == "tickWindow" then
        db.profile.twEnabled = not db.profile.twEnabled
        twEnabled = db.profile.twEnabled
    end
    if k == "powerTypeColor" then
        db.profile.enableColorByPowerType = not db.profile.enableColorByPowerType
        NugEnergy:SetNormalColor()
    end

    if k == "rage" then
        db.profile.rage = not db.profile.rage
        NugEnergy:Initialize()
    end

    if k == "energy" then
        db.profile.energy = not db.profile.energy
        NugEnergy:Initialize()
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
    local rem = math.mod(i, 6)
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

function hsv_shift(src, hm,sm,vm)
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
end