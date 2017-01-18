local tex = [[Interface\AddOns\NugEnergy\statusbar.tga]]
-- local tex = "Interface\\TargetingFrame\\UI-StatusBar"
local width = 100
local height = 30
local font = [[Interface\AddOns\NugEnergy\Emblem.ttf]]
local fontSize = 25
local color = { 0.9, 0.1, 0.1 }
local color2 = { .9, 0.1, 0.4 } -- for dispatch and meta
local color3 = { 131/255, 0.2, 0.2 } --max color
local color4 = { 141/255, 31/255, 62/255 } --low color
local lunar = { 0.6, 0, 1 }
local solar = {1,66/255,0}
local textcolor = {1,1,1}
local textoutline = false
local vertical = false
local spenderFeedback = true
local spenderColor = {1,.6,.6}
local outOfCombatAlpha = false
local doFadeOut = true
local fadeAfter = 3

if vertical then
    fontSize = 15
    width = 80
    tex = [[Interface\AddOns\NugEnergy\vstatusbar.tga]]
end
local onlyText = false

NugEnergy = CreateFrame("StatusBar","NugEnergy",UIParent)

NugEnergy:SetScript("OnEvent", function(self, event, ...)
    -- print(event, unpack{...})
	return self[event](self, event, ...)
end)

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
    monk = true,
    fury = true,
    shards = false,
    runic = true,
    balance = true,
    insanity = true,
    maelstrom = true
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
    if class == "ROGUE" then
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
            if newPowerType == "ENERGY" then
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

    elseif class == "MONK" and NugEnergyDB.monk then
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
            GetPower = function(unit) return UnitPower(unit, SPELL_POWER_SOUL_SHARDS) end
            GetPowerMax = function(unit) return UnitPowerMax(unit, SPELL_POWER_SOUL_SHARDS) end
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
            self:SetStatusBarColor(unpack(color3))
            self.bg:SetVertexColor(color3[1]*.5,color3[2]*.5,color3[3]*.5)
            self.glowanim:SetDuration(0.15)
        elseif execute then
            self:SetStatusBarColor(unpack(color2))
            self.bg:SetVertexColor(color2[1]*.5,color2[2]*.5,color2[3]*.5)
            self.glowanim:SetDuration(0.3)
        elseif insufficient then
            self:SetStatusBarColor(unpack(color4))
            self.bg:SetVertexColor(color4[1]*.5,color4[2]*.5,color4[3]*.5)
            self.glowanim:SetDuration(0.3)
        else
            self:SetStatusBarColor(unpack(color))
            self.bg:SetVertexColor(color[1]*.5,color[2]*.5,color[3]*.5)
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
    local a = fadeTime - ((self.OnUpdateCounter - fadeAfter) / fadeTime)
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
    elseif outOfCombatAlpha and PowerFilter then
        self:SetAlpha(outOfCombatAlpha)
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

function NugEnergy.Create(self)
    local f = self
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
    f:SetStatusBarTexture(tex)
    f:SetStatusBarColor(unpack(color))



    local spentBar = f:CreateTexture(nil, "ARTWORK", 5)
    spentBar:SetTexture([[Interface\AddOns\NugEnergy\white.tga]])
    spentBar:SetVertexColor(unpack(spenderColor))
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
    text:SetFont(font,fontSize, textoutline and "OUTLINE")
    if vertical then
        text:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -10)
        text:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0,0)
        text:SetJustifyH("CENTER")
        text:SetJustifyV("TOP")
    else
        text:SetPoint("TOPLEFT",f,"TOPLEFT",0,0)
        text:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-10,0)
        text:SetJustifyH("RIGHT")
    end
    text:SetTextColor(unpack(textcolor))
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

local ParseOpts = function(str)
    local fields = {}
    for opt,args in string.gmatch(str,"(%w*)%s*=%s*([%w%,%-%_%.%:%\\%']+)") do
        fields[opt:lower()] = tonumber(args) or args
    end
    return fields
end
function NugEnergy.SlashCmd(msg)
    k,v = string.match(msg, "([%w%+%-%=]+) ?(.*)")
    if not k or k == "help" then print([[Usage:
      |cff00ff00/nen lock|r
      |cff00ff00/nen unlock|r
      |cff00ff00/nen reset|r
      |cff00ff00/nen focus|r
      |cff00ff00/nen monk|r
      |cff00ff00/nen fury|r
      |cff00ff00/nen insanity|r
      |cff00ff00/nen runic|r
      |cff00ff00/nen balance|r
      |cff00ff00/nen shards|r]]
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
    if k == "markadd" then
        local p = ParseOpts(v)
        local at = p["at"]
        if at then
            NugEnergyDB_Character.marks[GetSpecialization() or 0][at] = true
            NugEnergy:CreateMark(at)
        end
    end
    if k == "markdel" then
        local p = ParseOpts(v)
        local at = p["at"]
        if at then
            NugEnergyDB_Character.marks[GetSpecialization() or 0][at] = nil
            NugEnergy:ReconfigureMarks()
            -- NugEnergy.marks[at]:Hide()
            -- NugEnergy.marks[at] = nil
        end
    end
    if k == "marklist" then
        print("Current marks:")
        for p in pairs(NugEnergyDB.marks) do
            print(string.format("    @%d",p))
        end
    end
    if k == "reset" then
        NugEnergy:SetPoint("CENTER",UIParent,"CENTER",0,0)
    end
    if k == "rage" then
        NugEnergyDB.rage = not NugEnergyDB.rage
        NugEnergy:Initialize()
    end
    if k == "monk" then
        NugEnergyDB.monk = not NugEnergyDB.monk
        NugEnergy:Initialize()
    end
    if k == "focus" then
        NugEnergyDB.focus = not NugEnergyDB.focus
        NugEnergy:Initialize()
    end
    if k == "shards" then
        NugEnergyDB.shards = not NugEnergyDB.shards
        NugEnergy:Initialize()
    end
    if k == "runic" then
        NugEnergyDB.runic = not NugEnergyDB.runic
        NugEnergy:Initialize()
    end
    if k == "balance" then
        NugEnergyDB.balance = not NugEnergyDB.balance
        NugEnergy:Initialize()
    end
    if k == "insanity" then
        NugEnergyDB.insanity = not NugEnergyDB.insanity
        NugEnergy:Initialize()
    end
    if k == "fury" then
        NugEnergyDB.fury = not NugEnergyDB.fury
        NugEnergy:Initialize()
    end
    if k == "maelstrom" then
        NugEnergyDB.maelstrom = not NugEnergyDB.maelstrom
        NugEnergy:Initialize()
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
