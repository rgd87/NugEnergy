local tex = [[Interface\AddOns\NugEnergy\statusbar.tga]]
local width = 100
local height = 30
local font = [[Interface\AddOns\NugEnergy\Emblem.ttf]]
local fontSize = 25
local color = { 0.9,0.1,0.1 }
local textcolor = { 1,1,1 }
local onlyText = false

NugEnergy = CreateFrame("StatusBar","NugEnergy",UIParent)

NugEnergy:SetScript("OnEvent", function(self, event, ...)
	self[event](self, event, ...)
end)

NugEnergy:RegisterEvent("ADDON_LOADED")
local UnitPower = UnitPower
local math_modf = math.modf
local ptypes = {
    --[1] = function(p) return p end, --rage
    [3] = function(p) return math_modf(p/5)*5 end, --energy
}
local truncate = ptypes[3]
function NugEnergy.ADDON_LOADED(self,event,arg1)
    if arg1 ~= "NugEnergy" then return end
    local class = select(2,UnitClass("player"))
    if class ~= "ROGUE" and class ~= "DRUID" and class ~= "WARRIOR" then return end
    NugEnergyDB = NugEnergyDB or {}
    NugEnergyDB.x = NugEnergyDB.x or 0
    NugEnergyDB.y = NugEnergyDB.y or 0
    NugEnergyDB.point = NugEnergyDB.point or "CENTER"
    self:Create()
    self:SetScript("OnUpdate",self.UpdateEnergy)
    self:RegisterEvent("UNIT_ENERGY")
    if ptypes[1] then self:RegisterEvent("UNIT_RAGE") end
    self.UNIT_ENERGY = self.UpdateEnergy
    self.UNIT_RAGE = self.UpdateEnergy
    
    self:RegisterEvent("UPDATE_STEALTH")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.PLAYER_REGEN_ENABLED = self.UPDATE_STEALTH
    self.PLAYER_REGEN_DISABLED = self.UPDATE_STEALTH
    
    self:RegisterEvent("UNIT_DISPLAYPOWER")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.PLAYER_ENTERING_WORLD = self.UNIT_DISPLAYPOWER
    
    SLASH_NUGENERGY1= "/nugenergy"
    SLASH_NUGENERGY2= "/nen"
    SlashCmdList["NUGENERGY"] = self.SlashCmd
end
function NugEnergy.UpdateEnergy(self)
    local p = UnitPower("player")
    local p5 = truncate(p)
    self.text:SetText(p5)
    if not onlyText then self:SetValue(p) end
end
function NugEnergy.UNIT_DISPLAYPOWER(self)
    truncate = ptypes[UnitPowerType("player")] or function(p) return p end
    self:UPDATE_STEALTH()
end
function NugEnergy.UNIT_MAXENERGY(self)
    self:SetMinMaxValues(0,UnitPowerMax("player"))
end
function NugEnergy.UPDATE_STEALTH(self)
    if (IsStealthed() or UnitAffectingCombat("player")) and ptypes[UnitPowerType("player")] then
        self:UNIT_MAXENERGY()
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
    f:SetBackdrop{
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 0,
        insets = {left = -2, right = -2, top = -2, bottom = -2},
    }
    f:SetBackdropColor(0,0,0,0.5)
    f:SetStatusBarTexture(tex)
    f:SetStatusBarColor(unpack(color))
    
    local bg = f:CreateTexture(nil,"BACKGROUND")
    bg:SetTexture(tex)
    bg:SetVertexColor(color[1]/2,color[3]/2,color[3]/2)
    bg:SetAllPoints(f)
    f.bg = bg
    f:UNIT_MAXENERGY()
    end
    
    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetFont(font,fontSize)
    text:SetPoint("TOPLEFT",f,"TOPLEFT",0,0)
    text:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-10,0)
    text:SetJustifyH("RIGHT")
    text:SetTextColor(unpack(textcolor))
    text:SetVertexColor(1,1,1)
    f.text = text
    
    f:UPDATE_STEALTH()
    
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
      |cff00ff00/nen reset|r]]
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
end