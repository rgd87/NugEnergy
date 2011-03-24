local tex = [[Interface\AddOns\NugEnergy\statusbar.tga]]
local width = 100
local height = 30
local font = [[Interface\AddOns\NugEnergy\Emblem.ttf]]
local fontSize = 25
local color = { 0.9,0.1,0.1 }
local textcolor = { 1,1,1 }
local onlyText = false
local classMarks = {}
--[energy] = <spellid>,
--classMarks["ROGUE"] = {
--    [35] = 2098, -- Eviscerate (http://www.wowhead.com/spell=2098)
--}
--classMarks["DRUID"] = {
--    [35] = 22568, -- Ferocious Bite
--}

NugEnergy = CreateFrame("StatusBar","NugEnergy",UIParent)

NugEnergy:SetScript("OnEvent", function(self, event, ...)
	self[event](self, event, ...)
end)

NugEnergy:RegisterEvent("ADDON_LOADED")
local UnitPower = UnitPower
local math_modf = math.modf
local ptypes = {
    ["RAGE"] = function(p) return p end,
    ["FOCUS"] = function(p) return p end,
    ["ENERGY"] = function(p) return math_modf(p/5)*5 end,
}

local truncate = ptypes["ENERGY"]
function NugEnergy.ADDON_LOADED(self,event,arg1)
    if arg1 ~= "NugEnergy" then return end
    local class = select(2,UnitClass("player"))
    if class ~= "ROGUE" and class ~= "DRUID" and class ~= "WARRIOR" and class ~= "HUNTER" then return end
    NugEnergyDB = NugEnergyDB or {}
    NugEnergyDB.x = NugEnergyDB.x or 0
    NugEnergyDB.y = NugEnergyDB.y or 0
    if not NugEnergyDB.rage then ptypes["RAGE"] = nil end
    if not NugEnergyDB.focus then ptypes["RAGE"] = nil end
    NugEnergyDB.point = NugEnergyDB.point or "CENTER"
    self.marks = classMarks[class] or {}
    self:Create()
    self:UPDATE_STEALTH()
    self:PLAYER_TALENT_UPDATE()
    self:RegisterEvent("UNIT_POWER")
    self:RegisterEvent("UNIT_MAXPOWER")
    self:SetScript("OnUpdate",self.UpdateEnergy)
    
    self:RegisterEvent("UPDATE_STEALTH")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.PLAYER_REGEN_ENABLED = self.UPDATE_STEALTH
    self.PLAYER_REGEN_DISABLED = self.UPDATE_STEALTH
    
    self:RegisterEvent("UNIT_DISPLAYPOWER")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.PLAYER_ENTERING_WORLD = self.UNIT_DISPLAYPOWER
    
    if not onlyText then
    self:RegisterEvent("PLAYER_TALENT_UPDATE")
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    self.ACTIVE_TALENT_GROUP_CHANGED = self.PLAYER_TALENT_UPDATE
    self.PLAYER_TARGET_CHANGED = function(self,event) self.UNIT_HEALTH(self,event,"target") end
    end
    
    SLASH_NUGENERGY1= "/nugenergy"
    SLASH_NUGENERGY2= "/nen"
    SlashCmdList["NUGENERGY"] = self.SlashCmd
end
function NugEnergy.UNIT_POWER(self,event,unit,powertype)
    if ptypes[powertype] then self:UpdateEnergy() end
end
function NugEnergy.UpdateEnergy(self)
    local p = UnitPower("player")
    local p5 = truncate(p)
    self.text:SetText(p5)
    if not onlyText then
        self:SetValue(p)
        --if self.marks[p] then self:PlaySpell(self.marks[p]) end
    end
end
function NugEnergy.UNIT_DISPLAYPOWER(self)
    truncate = ptypes[select(2,UnitPowerType("player"))] or function(p) return p end
    self:UPDATE_STEALTH()
end
function NugEnergy.UNIT_MAXPOWER(self)
    self:SetMinMaxValues(0,UnitPowerMax("player"))
end
function NugEnergy.UPDATE_STEALTH(self)
    if (IsStealthed() or UnitAffectingCombat("player")) and ptypes[select(2,UnitPowerType("player"))] then
        self:UNIT_MAXPOWER()
        self:UpdateEnergy()
        self:Show()
    else
        self:Hide()
    end
end

function NugEnergy.Create(self)
    local f = self
    f:SetWidth(width)
    f:SetHeight(height)
    
    if not onlyText then
    local backdrop = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 0,
        insets = {left = -2, right = -2, top = -2, bottom = -2},
    }
    f:SetBackdrop(backdrop)
    f:SetBackdropColor(0,0,0,0.5)
    f:SetStatusBarTexture(tex)
    f:SetStatusBarColor(unpack(color))
    
    local bg = f:CreateTexture(nil,"BACKGROUND")
    bg:SetTexture(tex)
    bg:SetVertexColor(color[1]/2,color[3]/2,color[3]/2)
    bg:SetAllPoints(f)
    f.bg = bg
    f:UNIT_MAXPOWER()
    
    
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
    text:SetFont(font,fontSize)
    text:SetPoint("TOPLEFT",f,"TOPLEFT",0,0)
    text:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-10,0)
    text:SetJustifyH("RIGHT")
    text:SetTextColor(unpack(textcolor))
    text:SetVertexColor(1,1,1)
    f.text = text
    
    f:SetPoint(NugEnergyDB.point, UIParent, NugEnergyDB.point, NugEnergyDB.x, NugEnergyDB.y)
    
    f:EnableMouse(false)
    f:RegisterForDrag("LeftButton")
    f:SetMovable(true)
    f:SetScript("OnDragStart",function(self) self:StartMoving() end)
    f:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing();
        _,_, NugEnergyDB.point, NugEnergyDB.x, NugEnergyDB.y = self:GetPoint(1)
    end)
end

function NugEnergy.SlashCmd(msg)
    k,v = string.match(msg, "([%w%+%-%=]+) ?(.*)")
    if not k or k == "help" then print([[Usage:
      |cff00ff00/nen lock|r
      |cff00ff00/nen unlock|r
      |cff00ff00/nen reset|r
      |cff00ff00/nen rage|r
      |cff00ff00/nen focus|r]]
    )end
    if k == "unlock" then
        NugEnergy:EnableMouse(true)
    end
    if k == "lock" then
        NugEnergy:EnableMouse(false)
    end
    if k == "reset" then
        NugEnergy:SetPoint("CENTER",UIParent,"CENTER",0,0)
    end
    if k == "rage" then
        NugEnergyDB.rage = not NugEnergyDB.rage
        ptypes["RAGE"] = NugEnergyDB.rage and function(p) return p end or nil
        NugEnergy:UPDATE_STEALTH()
    end
    if k == "focus" then
        NugEnergyDB.focus = not NugEnergyDB.focus
        ptypes["FOCUS"] = NugEnergyDB.focus and function(p) return p end or nil
        NugEnergy:UPDATE_STEALTH()
    end
end

function NugEnergy.PLAYER_TALENT_UPDATE(self,event)
    if IsSpellKnown(1329) -- mutilate
    then self:RegisterEvent("UNIT_HEALTH"); self:RegisterEvent("PLAYER_TARGET_CHANGED");
    else self:UnregisterEvent("UNIT_HEALTH"); self:UnregisterEvent("PLAYER_TARGET_CHANGED");
    end
end

function NugEnergy.UNIT_HEALTH(self,event,unit)
    if unit ~= "target" then return end
    if UnitHealth(unit)/UnitHealthMax(unit) < 0.35 then
        self:SetStatusBarColor(.9,0.1,0.4)
        self.bg:SetVertexColor(.9*.5,.1*.5,.4*.5)
    else
        self:SetStatusBarColor(unpack(color))
        self.bg:SetVertexColor(color[1]*.5,color[2]*.5,color[3]*.5)
    end
end