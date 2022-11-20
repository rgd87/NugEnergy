local _, ns = ...

local NugEnergy = _G.NugEnergy

-- Libraries
local LSM = LibStub("LibSharedMedia-3.0")

-- Constants
local BTM = BackdropTemplateMixin

-- API functions
local unpack = unpack
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_modf = math.modf

-- Component factories
local _createStatusBar = function(nen, config)
    local statusBar = CreateFrame("StatusBar", "NugEnergyStatusBar", UIParent)

    -- fields
    statusBar.overrides = {}
    statusBar.config = setmetatable(statusBar.overrides, {__index = config}) -- this allows overriding but defaults to config

    function statusBar:IsVertical()
        return self:GetOrientation() == "VERTICAL"
    end

    function statusBar:ResetPosition()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        -- update config NOT self.config
        _, _, config.point, config.offsetX, config.offsetY = self:GetPoint(1)
    end

    function statusBar:Update()
        local statusBarTexture = LSM:Fetch("statusbar", self.config.texture)
        self:SetStatusBarTexture(statusBarTexture)
        self:SetFrameStrata(self.config.strata)
        self:SetFrameLevel(self.config.level)
        self:SetOrientation(self.config.orientation)
        self:SetScale(self.config.scale)
        self:SetWidth(self.config.width)
        self:SetHeight(self.config.height)
        local r, g, b, a = unpack(self.config.color)
        self:SetStatusBarColor(r, g, b)
        self:SetAlpha(self.config.alpha or a)
        self:SetPoint(self.config.point, UIParent, self.config.point, self.config.offsetX, self.config.offsetY)

        if (self.config.show) then
            self:Show()
        else
            self:Hide()
        end
    end

    -- init
    statusBar:Update()

    -- Add logic for dragging to reposition
    statusBar:SetMovable(true)
    statusBar:EnableMouse(false)
    statusBar:RegisterForDrag("LeftButton")
    statusBar:SetScript("OnDragStart", statusBar.StartMoving)
    statusBar:SetScript(
        "OnDragStop",
        function(self)
            self:StopMovingOrSizing()
            _, _, config.point, config.offsetX, config.offsetY = self:GetPoint(1)
        end
    )

    return statusBar
end

local _createBackground = function(nen, config)
    local statusBar = nen.statusBar

    local background = statusBar:CreateTexture(statusBar:GetName() .. "BackgroundTexture", "BACKGROUND")
    local texture = statusBar:GetStatusBarTexture()
    background:SetTexture(texture:GetTextureFilePath())
    background:SetAllPoints(statusBar)

    function background:Update()
        -- handle color
        local r, g, b = statusBar:GetStatusBarColor()
        local f = config.scaleFactor
        self:SetVertexColor(r * f, g * f, b * f)

        -- handle show
        if (config.show) then
            self:Show()
        else
            self:Hide()
        end
    end

    -- init
    background:Update()

    -- hooks
    hooksecurefunc(
        statusBar,
        "SetStatusBarTexture",
        function(_, texture)
            if (type(texture) == "table" and texture.GetTextureFilePath) then
                background:SetTexture(texture:GetTextureFilePath())
            else
                background:SetTexture(texture)
            end
        end
    )

    hooksecurefunc(
        statusBar,
        "SetStatusBarColor",
        function(_, r, g, b)
            local f = config.scaleFactor
            background:SetVertexColor(r * f, g * f, b * f)
        end
    )

    return background
end

local _createBorder = function(nen, config)
    local statusBar = nen.statusBar

    -- Backdrop texture
    local backdrop = statusBar:CreateTexture(statusBar:GetName() .. "Backdrop", "BACKGROUND", nil, -2)
    function backdrop:Update()
        local borderType = config.type
        if (borderType == "1PX" or borderType == "2PX") then
            local value = borderType == "1PX" and 1 or 2
            local offset = ns.utils.pixelPerfect(value)
            self:SetTexture([[Interface\BUTTONS\WHITE8X8]])
            self:SetVertexColor(0, 0, 0, 1 / value)
            self:SetPoint("TOPLEFT", -offset, offset)
            self:SetPoint("BOTTOMRIGHT", offset, -offset)
            if (config.show) then
                self:Show()
            else
                self:Hide()
            end
        else
            self:Hide()
        end
    end

    -- Border frame
    local border = CreateFrame("Frame", statusBar:GetName() .. "Border", statusBar, BTM and "BackdropTemplate")
    function border:Update()
        local borderType = config.type
        if (borderType == "3PX") then
            self:SetPoint("TOPLEFT", -2, 2)
            self:SetPoint("BOTTOMRIGHT", 2, -2)
            self:SetBackdrop(
                {
                    edgeFile = [[Interface\AddOns\NugEnergy\media\textures\border_3px.tga]],
                    edgeSize = 8,
                    tileEdge = false
                }
            )
            self:SetBackdropBorderColor(0.4, 0.4, 0.4)
            if (config.show) then
                self:Show()
            else
                self:Hide()
            end
        elseif (borderType == "TOOLTIP") then
            self:SetPoint("TOPLEFT", -3, 3)
            self:SetPoint("BOTTOMRIGHT", 3, -3)
            self:SetBackdrop(
                {
                    edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
                    edgeSize = 16
                }
            )
            self:SetBackdropBorderColor(0.55, 0.55, 0.55)
            if (config.show) then
                self:Show()
            else
                self:Hide()
            end
        elseif (borderType == "STATUSBAR") then
            self:SetPoint("TOPLEFT", -2, 3)
            self:SetPoint("BOTTOMRIGHT", 2, -3)
            self:SetBackdrop(
                {
                    edgeFile = [[Interface\AddOns\NugEnergy\media\textures\border_statusbar.tga]],
                    edgeSize = 8,
                    tileEdge = false
                }
            )
            self:SetBackdropBorderColor(1, 1, 1)
            if (config.show) then
                self:Show()
            else
                self:Hide()
            end
        else
            self:Hide()
        end
    end

    local borderHandler = {}
    function borderHandler:Update()
        backdrop:Update()
        border:Update()
    end

    -- Initialize
    borderHandler:Update()

    return borderHandler
end

local _createSpark = function(nen, config)
    local statusBar = nen.statusBar

    local spark = statusBar:CreateTexture(statusBar:GetName() .. "Spark", "ARTWORK", nil, 4)
    spark:SetBlendMode("ADD")
    spark:SetTexture([[Interface\AddOns\NugEnergy\media\textures\spark.tga]])
    spark:SetVertexColor(statusBar:GetStatusBarColor())
    spark:SetPoint("CENTER", statusBar, "TOP", 0, 0)

    -- fields
    spark.minValue, spark.maxValue = statusBar:GetMinMaxValues()
    spark.totalDiff = spark.maxValue - spark.minValue

    function spark:Resize()
        local width, height = statusBar:GetSize()
        self:ClearAllPoints()
        self:SetWidth(width * 0.125)
        self:SetHeight(height)
        if (statusBar:IsVertical()) then
            self:SetTexCoord(1, 1, 0, 1, 1, 0, 0, 0)
        else
            self:SetTexCoord(0, 1, 0, 1)
        end
    end

    function spark:UpdatePosition(value)
        local p = 0
        if (self.totalDiff > 0) then
            p = math_min(1, (value - self.minValue) / self.totalDiff)
            -- hide spark when it's close to left border
            self:SetAlpha(1 - (p >= 0.90 and p or 0))
        end

        if (statusBar:IsVertical()) then
            local height = statusBar:GetHeight()
            self:SetPoint("CENTER", statusBar, "BOTTOM", 0, p * height)
        else
            local width = statusBar:GetWidth()
            self:SetPoint("CENTER", statusBar, "LEFT", p * width, 0)
        end
    end

    function spark:Update()
        self:Resize()
        self:UpdatePosition(statusBar:GetValue())

        if (config.show) then
            self:Show()
        else
            self:Hide()
        end
    end

    -- init
    spark:Update()

    -- hooks
    hooksecurefunc(
        statusBar,
        "SetStatusBarColor",
        function(_, r, g, b, a)
            spark:SetVertexColor(r, g, b)
        end
    )

    hooksecurefunc(
        statusBar,
        "SetMinMaxValues",
        function(_, minValue, maxValue)
            spark.minValue, spark.maxValue = minValue, maxValue
            spark.totalDiff = maxValue - minValue
        end
    )

    hooksecurefunc(
        statusBar,
        "SetValue",
        function(_, value)
            spark:UpdatePosition(value)
        end
    )

    hooksecurefunc(
        statusBar,
        "SetOrientation",
        function()
            spark:Update()
        end
    )

    return spark
end

local _createText = function(nen, config)
    local statusBar = nen.statusBar

    local fontFrame = CreateFrame("Frame", statusBar:GetName() .. "FontFrame")
    local text = fontFrame:CreateFontString("NugEnergyText", "OVERLAY")

    -- fields
    text.overrides = {}
    text.config = setmetatable(text.overrides, {__index = config})

    function fontFrame:Update()
        self:SetFrameLevel(text.config.level)
        self:SetFrameStrata(text.config.strata)
        if (text.config.show) then
            self:Show()
        else
            self:Hide()
        end
    end

    do
        local transform = nil
        function text:SetTransform(newTransform)
            transform = newTransform
        end

        local originalSetText = text.SetText
        function text:SetText(value)
            originalSetText(self, transform and transform(value) or value)
        end
    end

    function text:UpdateFont()
        local font = LSM:Fetch("font", self.config.fontName)
        self:SetFont(font, self.config.fontSize, self.config.fontFlags)
        local r, g, b, a = unpack(self.config.color)
        self:SetTextColor(r, g, b)
        self:SetAlpha(self.config.alpha or a)
    end

    function text:UpdatePosition()
        self:ClearAllPoints()
        self:SetPoint(self.config.point, statusBar, self.config.point, self.config.offsetX, self.config.offsetY)
        self:SetJustifyH(self.config.justifyH)
        self:SetJustifyV(self.config.justifyV)
    end

    function text:Update()
        fontFrame:Update()
        self:UpdateFont()
        self:UpdatePosition()
        self:SetText(statusBar:GetValue())
    end

    -- init
    text:Update()

    -- hooks
    hooksecurefunc(
        statusBar,
        "SetValue",
        function(_, value)
            text:SetText(value)
        end
    )

    hooksecurefunc(
        statusBar,
        "SetOrientation",
        function()
            text:UpdatePosition()
        end
    )

    return text
end

local _createMark = function(nen, position)
    local statusBar = nen.statusBar

    local mark = CreateFrame("Frame", statusBar:GetName() .. "MarkFrame" .. tostring(position), statusBar)
    mark:SetWidth(2)
    mark:SetHeight(statusBar:GetHeight())
    mark:SetFrameLevel(4)
    mark:SetAlpha(0.6)

    local texture = mark:CreateTexture(mark:GetName() .. "OverlayTexture", "OVERLAY")
    texture:SetTexture([[Interface\AddOns\NugEnergy\media\textures\mark]])
    texture:SetVertexColor(1, 1, 1, 0.3)
    texture:SetAllPoints(mark)
    mark.texture = texture

    local spark = mark:CreateTexture(mark:GetName() .. "OverlaySpark", "OVERLAY")
    spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
    spark:SetAlpha(0)
    spark:SetWidth(20)
    spark:SetHeight(mark:GetHeight() * 2.7)
    spark:SetPoint("CENTER", mark)
    spark:SetBlendMode("ADD")
    mark.spark = spark

    local sparkShine = spark:CreateAnimationGroup()

    local animation1 = sparkShine:CreateAnimation("Alpha")
    animation1:SetDuration(0.7)
    animation1:SetOrder(1)
    animation1:SetFromAlpha(0)
    animation1:SetToAlpha(1)

    local animation2 = sparkShine:CreateAnimation("Alpha")
    animation2:SetDuration(0.7)
    animation2:SetOrder(2)
    animation1:SetFromAlpha(1)
    animation1:SetToAlpha(0)

    -- fields
    mark.shine = sparkShine
    mark.position = position

    function mark:Update()
        local _, maxValue = statusBar:GetMinMaxValues()
        local pos = (self.position / maxValue) * statusBar:GetWidth()
        self:ClearAllPoints()
        self:SetPoint("CENTER", statusBar, "LEFT", pos, 0)
    end

    function mark:SetPosition(newPos)
        self.position = newPos
        self:Update()
    end

    mark:Update()

    hooksecurefunc(
        statusBar,
        "SetMinMaxValues",
        function()
            if (mark:IsShown()) then
                mark:Update()
            end
        end
    )

    hooksecurefunc(
        statusBar,
        "SetValue",
        function(_, value)
            if (mark:IsShown() and mark.position == value) then
                mark.shine:Play()
            end
        end
    )

    return mark
end

local _createMarkHandler = function(nen, profile)
    local markHandler = {}
    markHandler.marks = {}
    markHandler.markPool = {}

    function markHandler:AddMark(position)
        if (self.marks[position]) then
            return false
        end

        if (#self.markPool > 0) then
            local mark = tremove(self.markPool, 1)
            mark:SetPosition(position)
            mark:Show()
            self.marks[position] = mark
        else
            self.marks[position] = _createMark(nen, position)
        end

        return true
    end

    function markHandler:DeleteMark(position)
        local mark = self.marks[position]
        if (mark) then
            mark:Hide()
            self.marks[position] = nil
            tinsert(self.markPool, mark)
            return true
        end
        return false
    end

    -- Initialize
    local marks = profile.marks
    if (marks) then
        for k, _ in pairs(marks) do
            markHandler:AddMark(k)
        end
    end

    return markHandler
end

-- Behaviors

local _createFader = function(nen, config)
    local statusBar = nen.statusBar
    local text = nen.text

    local fader = CreateFrame("Frame", "NugEnergyFader")

    -- upvalues
    fader.isEnabled = config.isEnabled
    fader.fadeBar = config.fadeBar
    fader.fadeText = config.fadeText
    fader.outOfCombatAlpha = config.outOfCombatAlpha
    fader.delay = config.delay
    fader.duration = config.duration

    -- fields
    fader.isFading = false
    fader.totalElapsed = 0

    local _updateFadeBar = function(enabledChanged)
        local fadeBarChanged = fader.fadeBar ~= config.fadeBar
        fader.fadeBar = config.fadeBar
        if (enabledChanged or fadeBarChanged) then
            if (fader.isEnabled and fader.fadeBar) then
                if (not nen:IsActive() and not fader.isFading) then
                    statusBar:SetAlpha(fader.outOfCombatAlpha)
                end
            else
                local a = statusBar.config.color[4]
                statusBar:SetAlpha(a)
            end
        end
    end

    local _updateFadeText = function(enabledChanged)
        local fadeTextChanged = fader.fadeText ~= config.fadeText
        fader.fadeText = config.fadeText
        if (enabledChanged or fadeTextChanged) then
            if (fader.isEnabled and fader.fadeText) then
                if (not nen:IsActive() and not fader.isFading) then
                    text:SetAlpha(fader.outOfCombatAlpha)
                end
            else
                local a = text.config.color[4]
                text:SetAlpha(a)
            end
        end
    end

    function fader:Update()
        local enabledChanged = self.isEnabled ~= config.isEnabled
        self.isEnabled = config.isEnabled
        self.outOfCombatAlpha = config.outOfCombatAlpha
        self.delay = config.delay
        self.duration = config.duration

        if (enabledChanged and not self.isEnabled and self.isFading) then
            self:EndFade()
        end

        _updateFadeBar(enabledChanged)
        _updateFadeText(enabledChanged)
    end

    function fader:OnUpdateInternal(elapsed)
        if (nen:IsActive()) then
            return self:EndFade()
        end

        self.totalElapsed = self.totalElapsed + elapsed

        -- only start fading after waiting delay
        if (self.totalElapsed < self.delay) then
            return
        end

        local elapsedFade = self.totalElapsed - self.delay
        local percentComplete = 1 - (elapsedFade / self.duration)
        -- clamp the percent complete to a positive value or 0 because its possible that
        -- elapsedFade > self.duration which indicates we are done fading
        percentComplete = math_max(0, percentComplete)
        -- The limit of percent tends towards 0, thus alpha tends towards outOfCombatAlpha
        local maxRemainingAlpha = 1 - self.outOfCombatAlpha
        local alpha = self.outOfCombatAlpha + (percentComplete * maxRemainingAlpha)

        -- Update statusBar if configured
        if (self.fadeBar) then
            statusBar:SetAlpha(alpha)
        end

        -- Update text if configured
        if (self.fadeText) then
            text:SetAlpha(alpha)
        end

        if (percentComplete == 0) then
            self:EndFade()
        end
    end

    function fader:StartFade()
        if (not self.isEnabled or self.isFading) then
            return
        end

        self.isFading = true
        self.totalElapsed = 0
        self:SetScript("OnUpdate", self.OnUpdateInternal)
    end

    function fader:EndFade()
        if (not self.isFading) then
            return
        end
        self:SetScript("OnUpdate", nil)
        self.totalElapsed = 0
        self.isFading = false
    end

    function fader:HasFaded()
        if (not self.isEnabled) then
            return true
        end
        local hasBarFaded = not self.fadeBar or statusBar:GetAlpha() == self.outOfCombatAlpha
        local hasTextFaded = not self.fadeText or text:GetAlpha() == self.outOfCombatAlpha
        return hasBarFaded and hasTextFaded
    end

    return fader
end

local _createSpentBar = function(nen, config)
    local statusBar = nen.statusBar

    local spentBar = statusBar:CreateTexture(statusBar:GetName() .. "SpentBar", "ARTWORK", nil, 7)
    local texture = statusBar:GetStatusBarTexture()
    spentBar:SetTexture(texture:GetTextureFilePath())
    spentBar:SetWidth(statusBar:GetWidth())
    spentBar:SetHeight(statusBar:GetHeight())
    spentBar:SetVertexColor(statusBar:GetStatusBarColor())
    spentBar:SetAlpha(0)

    -- upvalues
    spentBar.isEnabled = config.isEnabled
    spentBar.duration = config.duration

    -- fields
    spentBar.previous = statusBar:GetValue()
    spentBar.parentWidth = statusBar:GetWidth()
    spentBar.parentHeight = statusBar:GetHeight()
    spentBar.parentMinValue, spentBar.parentMaxValue = statusBar:GetMinMaxValues()

    spentBar.trail = spentBar:CreateAnimationGroup()
    spentBar.animation = spentBar.trail:CreateAnimation("Alpha")
    spentBar.animation:SetFromAlpha(1)
    spentBar.animation:SetToAlpha(0)
    spentBar.animation:SetDuration(config.duration)
    spentBar.animation:SetOrder(1)

    -- functions
    function spentBar:UpdateUpvalues()
        self.isEnabled = config.isEnabled
        self.duration = config.duration
    end

    function spentBar:UpdatePoint()
        self:ClearAllPoints()
        if (statusBar:IsVertical()) then
            self:SetPoint("BOTTOM", statusBar, "BOTTOM", 0, 0)
        else
            self:SetPoint("LEFT", statusBar, "LEFT", 0, 0)
        end
    end

    function spentBar:Update()
        self:UpdateUpvalues()
        self:UpdatePoint()
        self.animation:SetDuration(self.duration)
    end

    -- init
    spentBar:Update()

    -- hooks
    hooksecurefunc(
        statusBar,
        "SetStatusBarTexture",
        function(_, texture)
            if (type(texture) == "table" and texture.GetTextureFilePath) then
                spentBar:SetTexture(texture:GetTextureFilePath())
            else
                spentBar:SetTexture(texture)
            end
        end
    )

    hooksecurefunc(
        statusBar,
        "SetStatusBarColor",
        function(_, r, g, b)
            spentBar:SetVertexColor(r, g, b)
        end
    )

    hooksecurefunc(
        statusBar,
        "SetWidth",
        function()
            spentBar.parentWidth = statusBar:GetWidth()
        end
    )

    hooksecurefunc(
        statusBar,
        "SetHeight",
        function()
            spentBar.parentHeight = statusBar:GetHeight()
        end
    )

    hooksecurefunc(
        statusBar,
        "SetSize",
        function()
            spentBar.parentWidth = statusBar:GetWidth()
            spentBar.parentHeight = statusBar:GetHeight()
        end
    )

    hooksecurefunc(
        statusBar,
        "SetMinMaxValues",
        function()
            spentBar.parentMinValue, spentBar.parentMaxValue = statusBar:GetMinMaxValues()
        end
    )

    hooksecurefunc(
        statusBar,
        "SetOrientation",
        function()
            spentBar:UpdatePoint()
        end
    )

    hooksecurefunc(
        statusBar,
        "SetValue",
        function(_, value)
            if (spentBar.isEnabled) then
                local diff = value - spentBar.previous
                if (diff < 0 and (math_abs(diff) / spentBar.parentMaxValue) > 0.1) then
                    local startPercentage = value / spentBar.parentMaxValue
                    local lenPercentage = math_abs(diff) / spentBar.parentMaxValue

                    if (statusBar:IsVertical()) then
                        local startPosition = startPercentage * spentBar.parentHeight
                        local length = lenPercentage * spentBar.parentHeight
                        spentBar:SetPoint("BOTTOM", statusBar, "BOTTOM", 0, startPosition)
                        spentBar:SetWidth(spentBar.parentWidth)
                        spentBar:SetHeight(length)
                    else
                        local startPosition = startPercentage * spentBar.parentWidth
                        local length = lenPercentage * spentBar.parentWidth
                        spentBar:SetPoint("LEFT", statusBar, "LEFT", startPosition, 0)
                        spentBar:SetWidth(length)
                        spentBar:SetHeight(spentBar.parentHeight)
                    end

                    if (spentBar.trail:IsPlaying()) then
                        spentBar.trail:Stop()
                    end

                    spentBar.trail:Play()
                end
            end
            spentBar.previous = value
        end
    )

    return spentBar
end

local _createAlert = function(nen, config)
    local statusBar = nen.statusBar

    local alert =
        CreateFrame(
        "Frame",
        statusBar:GetName() .. "AlertFrame",
        statusBar,
        BackdropTemplateMixin and "BackdropTemplate"
    )
    alert:SetBackdrop(
        {
            edgeFile = [[Interface\AddOns\NugEnergy\media\textures\glow.tga]],
            tileEdge = true,
            edgeSize = 16
        }
    )
    alert:SetFrameStrata("BACKGROUND")
    alert:SetBackdropBorderColor(1, 0, 0)
    alert:SetPoint("TOPLEFT", -16, 16)
    alert:SetPoint("BOTTOMRIGHT", 16, -16)
    alert:SetAlpha(0)

    local glow = alert:CreateAnimationGroup()
    glow:SetLooping("BOUNCE")

    local glowAnimation = glow:CreateAnimation("Alpha")
    glowAnimation:SetFromAlpha(0)
    glowAnimation:SetToAlpha(1)
    glowAnimation:SetDuration(0.3)
    glowAnimation:SetOrder(1)

    function alert:Update()
    end

    return alert
end

local _createPLC = function(nen, config)
    local statusBar = nen.statusBar

    local plc = {}

    plc.isEnabled = config.isEnabled
    plc.lowThreshold = config.lowThreshold
    plc.lowColor = config.lowColor
    plc.highThreshold = config.highThreshold
    plc.highColor = config.highColor

    _, plc.maxValue = statusBar:GetMinMaxValues()

    local _onValueUpdate = function(v)
        if (plc.isEnabled and plc.lowThreshold ~= 0 and (v / plc.maxValue) <= plc.lowThreshold) then
            local r, g, b = unpack(plc.lowColor)
            statusBar.overrides.color = {r, g, b, 1}
            statusBar:SetStatusBarColor(r, g, b)
        elseif (plc.isEnabled and plc.highThreshold ~= 1 and (v / plc.maxValue) >= plc.highThreshold) then
            local r, g, b = unpack(plc.highColor)
            statusBar.overrides.color = {r, g, b, 1}
            statusBar:SetStatusBarColor(r, g, b)
        else
            statusBar.overrides.color = nil
            local r, g, b = unpack(statusBar.config.color)
            statusBar:SetStatusBarColor(r, g, b)
        end
    end

    function plc:Update()
        self.isEnabled = config.isEnabled
        self.lowThreshold = config.lowThreshold
        self.lowColor = config.lowColor
        self.highThreshold = config.highThreshold
        self.highColor = config.highColor
        _onValueUpdate(statusBar:GetValue())
    end

    -- init
    plc:Update()

    -- hooks
    hooksecurefunc(
        statusBar,
        "SetMinMaxValues",
        function()
            _, plc.maxValue = statusBar:GetMinMaxValues()
        end
    )

    hooksecurefunc(
        statusBar,
        "SetValue",
        function(_, v)
            if (plc.isEnabled) then
                _onValueUpdate(v)
            end
        end
    )

    return plc
end

local _createTextThrottler = function(nen, config)
    local statusBar = nen.statusBar
    local text = nen.text

    local textThrottler = {
        isEnabled = config.isEnabled,
        throttleFactor = config.throttleFactor
    }

    function textThrottler:CreateTransform()
        local tf = self.throttleFactor
        return function(value)
            return math_modf(value / tf) * tf
        end
    end

    function textThrottler:Update()
        self.isEnabled = config.isEnabled
        self.throttleFactor = self.isEnabled and config.throttleFactor or 1
        text:SetTransform(self:CreateTransform())
        text:SetText(statusBar:GetValue())
    end

    -- init
    textThrottler:Update()

    return textThrottler
end

function NugEnergy:CreateComponents()
    local profile = self.db.profile

    -- Create all widgets
    self.statusBar = self.statusBar or _createStatusBar(self, profile.appearance.bar)
    self.background = self.background or _createBackground(self, profile.appearance.bar.background)
    self.border = self.border or _createBorder(self, profile.appearance.bar.border)
    self.spark = self.spark or _createSpark(self, profile.appearance.bar.spark)
    self.text = _createText(self, profile.appearance.text)
    self.markHandler = self.markHandler or _createMarkHandler(self, profile)

    -- Create behaviors, which at root are widgets but control a specific behavior
    self.plc = self.plc or _createPLC(self, profile.behaviors.plc)
    self.fader = self.fader or _createFader(self, profile.behaviors.fader)
    self.spentBar = self.spentBar or _createSpentBar(self, profile.behaviors.spenderFeedback)
    self.alert = self.alert or _createAlert(self, profile.behaviors.alert)
    self.textThrottler = self.textThrottler or _createTextThrottler(self, profile.behaviors.textThrottler)
end
