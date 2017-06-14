local textoutline = false
local vertical = false
local spenderFeedback = true
-- local outOfCombatAlpha = false
local doFadeOut = true
local fadeAfter = 3
local onlyText = false

if vertical then
    fontSize = 15
    width = 80
    tex = [[Interface\AddOns\NugEnergy\vstatusbar.tga]]
end


NugEnergy = CreateFrame("StatusBar","NugEnergy",UIParent)

NugEnergy:SetScript("OnEvent", function(self, event, ...)
    -- print(event, unpack{...})
	return self[event](self, event, ...)
end)

local LSM = LibStub("LibSharedMedia-3.0")

LSM:Register("statusbar", "Glamour7", [[Interface\AddOns\NugEnergy\statusbar.tga]])
LSM:Register("font", "Emblem", [[Interface\AddOns\NugEnergy\Emblem.ttf]])

local getStatusbar = function() return LSM:Fetch("statusbar", NugEnergyDB.textureName) end
local getFont = function() return LSM:Fetch("font", NugEnergyDB.fontName) end

-- local getStatusbar = function() return [[Interface\AddOns\NugEnergy\statusbar.tga]] end
-- local getFont = function() return [[Interface\AddOns\NugEnergy\Emblem.ttf]] end


NugEnergy:RegisterEvent("PLAYER_LOGIN")
NugEnergy:RegisterEvent("PLAYER_LOGOUT")
local UnitPower = UnitPower
local math_modf = math.modf

local PowerFilter
local ForcedToShow
local GetPower = UnitPower
local GetPowerMax = UnitPowerMax

local defaults = {
    point = "CENTER",
    x = 0, y = 0,
    marks = {},
    focus = true,
    rage = true,
    energy = true,
    fury = true,
    shards = false,
    runic = true,
    balance = true,
    insanity = true,
    maelstrom = true,

    width = 100,
    height = 30,
    normalColor = { 0.9, 0.1, 0.1 }, --1
    altColor = { .9, 0.1, 0.4 }, -- for dispatch and meta 2 
    maxColor = { 131/255, 0.2, 0.2 }, --max color 3
    lowColor = { 141/255, 31/255, 62/255 }, --low color 4

    textureName = "Glamour7",
    fontName = "Emblem",
    fontSize = 25,
    textColor = {1,1,1,1},
    spenderColor = {1,.6,.6},
    outOfCombatAlpha = 0,
}

local free_marks = {} -- for unused mark frames

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
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED") -- for mark swaps

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


local GetPowerBy5 = function(unit)
    local p = UnitPower(unit)
    local pmax = UnitPowerMax(unit)
    -- p, p2, execute, shine, capped, insufficient
    return p, math_modf(p/5)*5, nil, nil, p == pmax, nil
end
function NugEnergy.Initialize(self)
    self:RegisterEvent("UNIT_POWER")
    self:RegisterEvent("UNIT_MAXPOWER")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.PLAYER_REGEN_ENABLED = self.UPDATE_STEALTH
    self.PLAYER_REGEN_DISABLED = self.UPDATE_STEALTH

    if not self.initialized then
        self:Create()
        self.initialized = true
    end

    local RageBarGetPower = function(shineZone, cappedZone, minLimit, throttleText)
        return function(unit)
            local p = UnitPower(unit)
            local pmax = UnitPowerMax(unit)
            local shine = p >= pmax-shineZone
            -- local state
            -- if p >= pmax-10 then state = "CAPPED" end
            -- if GetSpecialization() == 3  p < 60 pmax-10
            local capped = p >= pmax-cappedZone
            local p2 = throttleText and math_modf(p/5)*5
            return p, p2, execute, shine, capped, (minLimit and p < minLimit)
        end
    end

    local class = select(2,UnitClass("player"))
    if class == "ROGUE" and NugEnergyDB.energy then
        PowerFilter = "ENERGY"
        self:RegisterEvent("UPDATE_STEALTH")
        self:SetScript("OnUpdate",self.UpdateEnergy)
        GetPower = GetPowerBy5
        -- self:RegisterEvent("PLAYER_TARGET_CHANGED")


    elseif class == "PRIEST" and NugEnergyDB.insanity then
        local voidform = false
        local voidformCost = 100
        local InsanityBarGetPower = function(unit)
            local p = UnitPower(unit)
            -- local pmax = UnitPowerMax(unit)
            local shine = p >= voidformCost
            if voidform then shine = nil end
            -- local state
            -- if p >= pmax-10 then state = "CAPPED" end
            -- if GetSpecialization() == 3  p < 60 pmax-10
            local capped = shine
            return p, nil, voidform, shine, capped
        end
        self.UNIT_AURA = function(self, event, unit)
            if unit ~= "player" then return end
            voidform = ( UnitAura("player", GetSpellInfo(194249), nil, "HELPFUL") ~= nil)
            self:UpdateEnergy()
        end
        GetPower = InsanityBarGetPower

        self:RegisterEvent("SPELLS_CHANGED")
        self.SPELLS_CHANGED = function(self)
            if GetSpecialization() == 3 then
                PowerFilter = "INSANITY"
                voidformCost = IsPlayerSpell(193225) and 70 or 100 -- Legacy of the Void
                self:RegisterEvent("UNIT_MAXPOWER")
                self:RegisterEvent("UNIT_POWER_FREQUENT");
                self:RegisterEvent("UNIT_AURA");
                self:RegisterEvent("PLAYER_REGEN_DISABLED")
                self:RegisterEvent("PLAYER_REGEN_ENABLED")
            else
                PowerFilter = nil
                self:UnregisterEvent("UNIT_MAXPOWER")
                self:UnregisterEvent("UNIT_POWER_FREQUENT");
                self:UnregisterEvent("UNIT_AURA");
                self:UnregisterEvent("PLAYER_REGEN_DISABLED")
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                self:Hide()
                self:SetScript("OnUpdate", nil)
            end
        end
        self:SPELLS_CHANGED()
    elseif class == "DRUID" then
        self:RegisterEvent("UNIT_DISPLAYPOWER")
        self:RegisterEvent("UPDATE_STEALTH")

        self:SetScript("OnUpdate",self.UpdateEnergy)
        self.UNIT_DISPLAYPOWER = function(self)
            local newPowerType = select(2,UnitPowerType("player"))
            if newPowerType == "ENERGY" and NugEnergyDB.energy then
                PowerFilter = "ENERGY"
                self:RegisterEvent("UNIT_POWER")
                self:RegisterEvent("UNIT_MAXPOWER")
                self.PLAYER_REGEN_ENABLED = self.UPDATE_STEALTH
                self.PLAYER_REGEN_DISABLED = self.UPDATE_STEALTH
                -- self.UPDATE_STEALTH = self.__UPDATE_STEALTH
                -- self.UpdateEnergy = self.__UpdateEnergy
                GetPower = GetPowerBy5
                self:RegisterEvent("PLAYER_REGEN_DISABLED")
                self:SetScript("OnUpdate",self.UpdateEnergy)
                self:UPDATE_STEALTH()
            elseif newPowerType =="RAGE" and NugEnergyDB.rage then
                PowerFilter = "RAGE"
                self:RegisterEvent("UNIT_POWER")
                self:RegisterEvent("UNIT_MAXPOWER")
                self.PLAYER_REGEN_ENABLED = self.UPDATE_STEALTH
                self.PLAYER_REGEN_DISABLED = self.UPDATE_STEALTH
                -- self.UPDATE_STEALTH = self.__UPDATE_STEALTH
                -- self.UpdateEnergy = self.__UpdateEnergy
                GetPower = RageBarGetPower(30, 10, 45)
                self:RegisterEvent("PLAYER_REGEN_DISABLED")
                self:SetScript("OnUpdate", nil)
                self:UPDATE_STEALTH()
            elseif GetSpecialization() == 1 and NugEnergyDB.balance then
                self:RegisterEvent("UNIT_POWER")
                self:RegisterEvent("UNIT_MAXPOWER")
                PowerFilter = "LUNAR_POWER"
                self.PLAYER_REGEN_ENABLED = self.UPDATE_STEALTH
                self.PLAYER_REGEN_DISABLED = self.UPDATE_STEALTH
                -- self.UPDATE_STEALTH = self.__UPDATE_STEALTH
                -- self.UpdateEnergy = self.__UpdateEnergy
                GetPower = UnitPower
                self:RegisterEvent("PLAYER_REGEN_DISABLED")
                self:SetScript("OnUpdate", nil)
                self:UPDATE_STEALTH()
            else
                PowerFilter = nil
                self:UnregisterEvent("UNIT_POWER")
                self:UnregisterEvent("UNIT_MAXPOWER")
                self:UnregisterEvent("PLAYER_REGEN_DISABLED")
                self:SetScript("OnUpdate", nil)
                self:UPDATE_STEALTH()
            end
        end
        self:UNIT_DISPLAYPOWER()

        self.SPELLS_CHANGED = self.UNIT_DISPLAYPOWER
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("SPELLS_CHANGED")
        self.PLAYER_ENTERING_WORLD = function(self)
            C_Timer.After(2, function() self:UNIT_DISPLAYPOWER() end)
        end

    elseif class == "DEMONHUNTER" and NugEnergyDB.fury then
        self.UNIT_POWER_FREQUENT = self.UNIT_POWER

        self:RegisterEvent("UNIT_DISPLAYPOWER")
        self.UNIT_DISPLAYPOWER = function(self)
            GetPower = RageBarGetPower(30, 10)
            self:RegisterEvent("UNIT_POWER_FREQUENT")
            local newPowerType = select(2,UnitPowerType("player"))
            if newPowerType == "FURY" then
                PowerFilter = "FURY"
            else
                PowerFilter = "PAIN"
            end
        end
        self:UNIT_DISPLAYPOWER()

    elseif class == "MONK" and NugEnergyDB.energy then
        self:RegisterEvent("UNIT_DISPLAYPOWER")
        self:SetScript("OnUpdate",self.UpdateEnergy)
        self.UNIT_DISPLAYPOWER = function(self)
            local newPowerType = select(2,UnitPowerType("player"))
            if newPowerType == "ENERGY" then
                PowerFilter = "ENERGY"
                -- GetPower = GetPowerBy5
                -- GetPower = function(unit)
                --     local p, p2 = GetPowerBy5(unit)
                --     local pmax = UnitPowerMax(unit)
                --     -- local shine = p >= pmax-30
                --     local capped = p == pmax
                --     local insufficient
                --     if p < 50 and GetSpecialization() == 3 then insufficient = true end
                --     return p, p2, execute, shine, capped, insufficient
                -- end
                if GetSpecialization() == 3 then
                    GetPower = RageBarGetPower(-1, 5, 50, true)
                else
                    GetPower = RageBarGetPower(10, 5, 25, true)
                end

                self:RegisterEvent("PLAYER_REGEN_DISABLED")
                self:SetScript("OnUpdate",self.UpdateEnergy)
            else
                self:UnregisterEvent("PLAYER_REGEN_DISABLED")
                PowerFilter = nil
                self:SetScript("OnUpdate", nil)
                self:Hide()
            end
            self:UPDATE_STEALTH()
        end
        self:UNIT_DISPLAYPOWER()

    elseif class == "WARLOCK" and NugEnergyDB.shards then
        self:RegisterEvent("SPELLS_CHANGED")
        self.SPELLS_CHANGED = function(self)
            local spec = GetSpecialization()
            -- GetPower = function(unit) return UnitPower(unit, SPELL_POWER_SOUL_SHARDS) end
            GetPower = function(unit)
                local p = UnitPower(unit, SPELL_POWER_SOUL_SHARDS, true)
                local pmax = UnitPowerMax(unit, SPELL_POWER_SOUL_SHARDS, true)
                -- p, p2, execute, shine, capped, insufficient
                return p, math_modf(p/10), nil, nil, p == pmax, nil
            end
            GetPowerMax = function(unit) return UnitPowerMax(unit, SPELL_POWER_SOUL_SHARDS, true) end
            PowerFilter = "SOUL_SHARDS"
        end
        self:SPELLS_CHANGED()
    elseif class == "DEATHKNIGHT" and NugEnergyDB.runic then
        PowerFilter = "RUNIC_POWER"
        local execute = false
        GetPower = function(unit)
            local p = UnitPower(unit)
            local pmax = UnitPowerMax(unit)
            local shine = p >= pmax-30
            local capped = p >= pmax-10
            return p, nil, execute, shine, capped
        end
        self.UNIT_HEALTH = function(self, event, unit)
            if unit ~= "target" then return end
            local uhm = UnitHealthMax(unit)
            if uhm == 0 then uhm = 1 end
            execute = UnitHealth(unit)/uhm < 0.35
            self:UpdateEnergy()
        end
        self.PLAYER_TARGET_CHANGED = function(self,event) self.UNIT_HEALTH(self,event,"target") end
        self:RegisterEvent("UNIT_HEALTH"); self:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif class == "WARRIOR" and NugEnergyDB.rage then
        PowerFilter = "RAGE"
        local execute = false
        local GetSpecialization = GetSpecialization
        local GetShapeshiftForm = GetShapeshiftForm
        GetPower = function(unit)
            local p = UnitPower(unit)
            local pmax = UnitPowerMax(unit)
            local shine = p >= pmax-30
            local capped = p >= pmax-10
            local insufficient
            -- local state
            -- if p >= pmax-10 then state = "CAPPED" end
            if p < 20 and GetSpecialization() == 3 then insufficient = true end
            return p, nil, execute, shine, capped, insufficient
        end
        self.UNIT_HEALTH = function(self, event, unit)
            if unit ~= "target" then return end
            local uhm = UnitHealthMax(unit)
            if uhm == 0 then uhm = 1 end
            execute = GetSpecialization() ~= 3 and UnitHealth(unit)/uhm < 0.2
            self:UpdateEnergy()
        end
        self.PLAYER_TARGET_CHANGED = function(self,event)
            if UnitExists('target') then
                self.UNIT_HEALTH(self,event,"target")
            end
        end
        self:RegisterEvent("UNIT_HEALTH"); self:RegisterEvent("PLAYER_TARGET_CHANGED")

    elseif class == "HUNTER" and NugEnergyDB.focus then
        PowerFilter = "FOCUS"
        self:SetScript("OnUpdate",self.UpdateEnergy)
        GetPower = GetPowerBy5

    elseif class == "SHAMAN" and NugEnergyDB.maelstrom then
        PowerFilter = "MAELSTROM"
        GetPower = RageBarGetPower(30, 10)

        self:RegisterEvent("SPELLS_CHANGED")
        self.SPELLS_CHANGED = function(self)
            local spec = GetSpecialization()
            if spec == 1 or spec == 2 then
                self:RegisterEvent("UNIT_MAXPOWER")
                self:RegisterEvent("UNIT_POWER_FREQUENT");
                self:RegisterEvent("PLAYER_REGEN_DISABLED")
            else
                self:UnregisterEvent("UNIT_MAXPOWER")
                self:UnregisterEvent("UNIT_POWER_FREQUENT");
                self:UnregisterEvent("PLAYER_REGEN_DISABLED")
            end
        end
        self:SPELLS_CHANGED()
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



function NugEnergy.UNIT_POWER(self,event,unit,powertype)
    if powertype == PowerFilter then self:UpdateEnergy() end
end
NugEnergy.UNIT_POWER_FREQUENT = NugEnergy.UNIT_POWER
function NugEnergy.UpdateEnergy(self)
    local p, p2, execute, shine, capped, insufficient = GetPower("player")
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
        if capped then
            local c = NugEnergyDB.maxColor
            self:SetStatusBarColor(unpack(c))
            self.bg:SetVertexColor(c[1]*.5,c[2]*.5,c[3]*.5)
            self.glowanim:SetDuration(0.15)
        elseif execute then
            local c = NugEnergyDB.altColor
            self:SetStatusBarColor(unpack(c))
            self.bg:SetVertexColor(c[1]*.5,c[2]*.5,c[3]*.5)
            self.glowanim:SetDuration(0.3)
        elseif insufficient then
            local c = NugEnergyDB.lowColor
            self:SetStatusBarColor(unpack(c))
            self.bg:SetVertexColor(c[1]*.5,c[2]*.5,c[3]*.5)
            self.glowanim:SetDuration(0.3)
        else
            local c = NugEnergyDB.normalColor
            self:SetStatusBarColor(unpack(c))
            self.bg:SetVertexColor(c[1]*.5,c[2]*.5,c[3]*.5)
            self.glowanim:SetDuration(0.3)
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
-- end




function NugEnergy.UNIT_MAXPOWER(self)
    self:SetMinMaxValues(0,GetPowerMax("player"))
    if not self.marks then return end
    for _, mark in pairs(self.marks) do
        mark:Update()
    end
end

local fadeTime = 1
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
    local a = p
    nen:SetAlpha(a)
    if self.OnUpdateCounter >= fadeAfter + fadeTime then
        self:SetScript("OnUpdate",nil)
        nen:Hide()
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

function NugEnergy.UPDATE_STEALTH(self)
    if (IsStealthed() or UnitAffectingCombat("player") or ForcedToShow) and PowerFilter then
        self:UNIT_MAXPOWER()
        self:UpdateEnergy()
        self:SetAlpha(1)
        self:Show()
    elseif doFadeOut and PowerFilter then
        self:StartHiding()
    elseif NugEnergyDB.outOfCombatAlpha > 0 and PowerFilter then
        self:SetAlpha(NugEnergyDB.outOfCombatAlpha)
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

function NugEnergy:Resize()
    local f = self
    local width = NugEnergyDB.width
    local height = NugEnergyDB.height
    if vertical then
        height, width = width, height
        f:SetOrientation("VERTICAL")
    end

    f:SetWidth(width)
    f:SetHeight(height)

    local tex = getStatusbar()
    f:SetStatusBarTexture(tex)
    f.bg:SetTexture(tex)

    f.spentBar:SetWidth(width)
    f.spentBar:SetHeight(height*1)
    f.spentBar:SetVertexColor(unpack(NugEnergyDB.spenderColor))

    local hmul,vmul = 1.5, 1.8
    if vertical then hmul, vmul = vmul, hmul end
    f.alertFrame:SetWidth(width*hmul)
    f.alertFrame:SetHeight(height*vmul)
end

function NugEnergy:ResizeText()
    local text = self.text
    local font = getFont()
    local fontSize = NugEnergyDB.fontSize
    text:SetFont(font,fontSize, textoutline and "OUTLINE")
    local r,g,b,a = unpack(NugEnergyDB.textColor)
    text:SetTextColor(r,g,b)
    text:SetAlpha(a)
end

function NugEnergy.Create(self)
    local f = self
    local width = NugEnergyDB.width
    local height = NugEnergyDB.height
    if vertical then
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
    local color = NugEnergyDB.normalColor
    f:SetStatusBarColor(unpack(color))



    local spentBar = f:CreateTexture(nil, "ARTWORK", 5)
    spentBar:SetTexture([[Interface\AddOns\NugEnergy\white.tga]])
    spentBar:SetVertexColor(unpack(NugEnergyDB.spenderColor))
    spentBar:SetHeight(height*1)
    spentBar:SetWidth(width)
    spentBar:SetPoint("LEFT", f, "LEFT",0,0)
    spentBar:SetAlpha(0)
    f.spentBar = spentBar

    f._SetValue = f._SetValue or f.SetValue

    f.SetValue = function(self, new)
        if spenderFeedback then
            local cur = self:GetValue()
            local min, max = self:GetMinMaxValues()
            local diff = new - cur
            if diff < 0 and math.abs(diff)/max > 0.1 then
                local fwidth = self:GetWidth()
                local lpos = (new/max)*fwidth
                local len = (-diff/max)*fwidth
                self.spentBar:SetPoint("LEFT", self, "LEFT",lpos,0)
                self.spentBar:SetWidth(len)
                if self.trail:IsPlaying() then self.trail:Stop() end
                self.trail:Play()
                self.spentBar.currentValue = cur
            -- else
                -- if self.trail:IsPlaying() then
            end
        end
        self:_SetValue(new)
    end


    local trail = spentBar:CreateAnimationGroup()
    local sa1 = trail:CreateAnimation("Alpha")
    sa1:SetFromAlpha(0)
    sa1:SetToAlpha(0.4)
    sa1:SetDuration(0.25)
    sa1:SetOrder(1)

    local sa2 = trail:CreateAnimation("Alpha")
    sa2:SetFromAlpha(0.4)
    sa2:SetToAlpha(0)
    sa2:SetDuration(0.5)
    sa2:SetOrder(2)

    local bg = f:CreateTexture(nil,"BACKGROUND")
    bg:SetTexture(tex)
    bg:SetVertexColor(color[1]/2,color[3]/2,color[3]/2)
    bg:SetAllPoints(f)

    f.bg = bg
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

    local at = f:CreateTexture(nil,"BACKGROUND", nil, -1)
    at:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    at:SetVertexColor(unpack(color))
    at:SetTexCoord(0.00781250,0.50781250,0.27734375,0.52734375)
    --at:SetTexture([[Interface\AchievementFrame\UI-Achievement-IconFrame]])
    --at:SetTexCoord(0,0.5625,0,0.5625)
    local hmul,vmul = 1.5, 1.8
    if vertical then hmul, vmul = vmul, hmul end
    at:SetWidth(width*hmul)
    at:SetHeight(height*vmul)
    at:SetPoint("CENTER",self,"CENTER",0,0)
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
    self.glowtex = glow





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
    if vertical then
        text:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -10)
        text:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0,0)
        text:SetJustifyH("CENTER")
        text:SetJustifyV("TOP")
    else
        -- text:SetPoint("TOPLEFT",f,"TOPLEFT",0,0)
        -- text:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-10,0)
        text:SetPoint("LEFT",f,"LEFT",0, -2)
        text:SetPoint("RIGHT",f,"RIGHT",-7, -2)
        text:SetJustifyH("RIGHT")
    end
    local r,g,b,a = unpack(NugEnergyDB.textColor)
    text:SetTextColor(r,g,b)
    text:SetAlpha(a)
    f.text = text

    f:SetPoint(NugEnergyDB.point, UIParent, NugEnergyDB.point, NugEnergyDB.x, NugEnergyDB.y)

    f:Hide()

    f:EnableMouse(false)
    f:RegisterForDrag("LeftButton")
    f:SetMovable(true)
    f:SetScript("OnDragStart",function(self) self:StartMoving() end)
    f:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing();
        _,_, NugEnergyDB.point, NugEnergyDB.x, NugEnergyDB.y = self:GetPoint(1)
    end)
end

local ParseOpts = function(str)
    local fields = {}
    for opt,args in string.gmatch(str,"(%w*)%s*=%s*([%w%,%-%_%.%:%\\%']+)") do
        fields[opt:lower()] = tonumber(args) or args
    end
    return fields
end

NugEnergy.Commands = {
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
    ["rage"] = function(v)
        NugEnergyDB.rage = not NugEnergyDB.rage
        NugEnergy:Initialize()
    end,
    ["energy"] = function(v)
        NugEnergyDB.energy = not NugEnergyDB.energy
        NugEnergy:Initialize()
    end,
    ["focus"] = function(v)
        NugEnergyDB.focus = not NugEnergyDB.focus
        NugEnergy:Initialize()
    end,
    ["shards"] = function(v)
        NugEnergyDB.shards = not NugEnergyDB.shards
        NugEnergy:Initialize()
    end,
    ["runic"] = function(v)
        NugEnergyDB.runic = not NugEnergyDB.runic
        NugEnergy:Initialize()
    end,
    ["balance"] = function(v)
        NugEnergyDB.balance = not NugEnergyDB.balance
        NugEnergy:Initialize()
    end,
    ["insanity"] = function(v)
        NugEnergyDB.insanity = not NugEnergyDB.insanity
        NugEnergy:Initialize()
    end,
    ["fury"] = function(v)
        NugEnergyDB.fury = not NugEnergyDB.fury
        NugEnergy:Initialize()
    end,
    ["maelstrom"] = function(v)
        NugEnergyDB.maelstrom = not NugEnergyDB.maelstrom
        NugEnergy:Initialize()
    end,
}

local helpMessage = {
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
    k,v = string.match(msg, "([%w%+%-%=]+) ?(.*)")
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
        a1:SetChange(1)
        a1:SetDuration(0.2)
        a1:SetOrder(1)
        local a2 = ag:CreateAnimation("Alpha")
        a2:SetChange(-1)
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
                name = "Unlock",
                type = "execute",
                desc = "Unlock anchor for dragging",
                func = function() NugEnergy.Commands.unlock() end,
                order = 1,
            },
            lock = {
                name = "Lock",
                type = "execute",
                desc = "Lock anchor",
                func = function() NugEnergy.Commands.lock() end,
                order = 2,
            },
            resetToDefault = {
                name = "Restore Defaults",
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
                                name = "Normal Color",
                                type = 'color',
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
                                name = "Alt Color",
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
                                name = "Max Color",
                                type = 'color',
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
                                name = "Insufficient Color",
                                type = 'color',
                                order = 4,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergyDB.lowColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergyDB.lowColor = {r,g,b}
                                end,
                            },
                            spenderColor = {
                                name = "Spender effect Color",
                                type = 'color',
                                order = 5,
                                get = function(info)
                                    local r,g,b = unpack(NugEnergyDB.spenderColor)
                                    return r,g,b
                                end,
                                set = function(info, r, g, b)
                                    NugEnergyDB.spenderColor = {r,g,b}
                                end,
                            },
                            textColor = {
                                name = "Text Color & Alpha",
                                type = 'color',
                                hasAlpha = true,
                                order = 5,
                                get = function(info)
                                    local r,g,b,a = unpack(NugEnergyDB.textColor)
                                    return r,g,b,a
                                end,
                                set = function(info, r, g, b, a)
                                    NugEnergyDB.textColor = {r,g,b, a}
                                end,
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
                                name = "Texture",
                                order = 10,
                                desc = "Set the statusbar texture.",
                                get = function(info) return NugEnergyDB.textureName end,
                                set = function(info, value)
                                    NugEnergyDB.textureName = value
                                    NugEnergy:Resize()
                                end,
                                values = LSM:HashTable("statusbar"),
                                dialogControl = "LSM30_Statusbar",
                            },
                            width = {
                                name = "Width",
                                type = "range",
                                get = function(info) return NugEnergyDB.width end,
                                set = function(info, v)
                                    NugEnergyDB.width = tonumber(v)
                                    NugEnergy:Resize()
                                end,
                                min = 30,
                                max = 300,
                                step = 1,
                                order = 7,
                            },
                            height = {
                                name = "Height",
                                type = "range",
                                get = function(info) return NugEnergyDB.height end,
                                set = function(info, v)
                                    NugEnergyDB.height = tonumber(v)
                                    NugEnergy:Resize()
                                end,
                                min = 10,
                                max = 60,
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

                    textGroup = {
                        type = "group",
                        name = "",
                        order = 3,
                        args = {
                            font = {
                                type = "select",
                                name = "Font",
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
                                name = "Font Size",
                                type = "range",
                                order = 2,
                                get = function(info) return NugEnergyDB.fontSize end,
                                set = function(info, v)
                                    NugEnergyDB.fontSize = tonumber(v)
                                    NugEnergy:ResizeText()
                                end,
                                min = 5,
                                max = 50,
                                step = 1,
                                order = 11,
                            },
                        },
                    },
                    classResourceGroup = {
                        type = "group",
                        name = "",
                        order = 4,
                        args = {
                            energy = {
                                name = "Energy",
                                type = "toggle",
                                order = 1,
                                get = function(info) return NugEnergyDB.energy end,
                                set = function(info, v) NugEnergy.Commands.energy() end
                            },
                            rage = {
                                name = "Rage",
                                type = "toggle",
                                order = 2,
                                get = function(info) return NugEnergyDB.rage end,
                                set = function(info, v) NugEnergy.Commands.rage() end
                            },
                            focus = {
                                name = "Focus",
                                type = "toggle",
                                order = 3,
                                get = function(info) return NugEnergyDB.focus end,
                                set = function(info, v) NugEnergy.Commands.focus() end
                            },
                            fury = {
                                name = "Fury & Vengeance",
                                type = "toggle",
                                order = 4,
                                get = function(info) return NugEnergyDB.fury end,
                                set = function(info, v) NugEnergy.Commands.fury() end
                            },
                            runic = {
                                name = "Runic Power",
                                type = "toggle",
                                order = 5,
                                get = function(info) return NugEnergyDB.runic end,
                                set = function(info, v) NugEnergy.Commands.runic() end
                            },
                            shards = {
                                name = "Shards",
                                type = "toggle",
                                order = 6,
                                get = function(info) return NugEnergyDB.shards end,
                                set = function(info, v) NugEnergy.Commands.shards() end
                            },
                            insanity = {
                                name = "Insanity",
                                type = "toggle",
                                order = 7,
                                get = function(info) return NugEnergyDB.insanity end,
                                set = function(info, v) NugEnergy.Commands.insanity() end
                            },
                            balance = {
                                name = "Balance",
                                type = "toggle",
                                order = 8,
                                get = function(info) return NugEnergyDB.balance end,
                                set = function(info, v) NugEnergy.Commands.balance() end
                            },
                            maelstrom = {
                                name = "Maelstrom",
                                type = "toggle",
                                order = 9,
                                get = function(info) return NugEnergyDB.maelstrom end,
                                set = function(info, v) NugEnergy.Commands.maelstrom() end
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