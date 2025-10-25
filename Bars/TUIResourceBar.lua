---@class TUIResourceBar
TUIResourceBar = {}
TUIResourceBar.__index = TUIResourceBar

function TUIResourceBar:new(name, parent)
    local self = setmetatable({}, TUIResourceBar)

    self.frame = CreateFrame("StatusBar", name or "TUIResourceBarFrame", parent or UIParent)
    self.frame:SetSize(200, 20)
    self.frame:SetPoint("CENTER", 0, -230)
    self.frame:SetStatusBarTexture("Interface\\AddOns\\SharedMedia\\statusbar\\Melli.tga")
    self.frame:SetStatusBarColor(0.0, 0.6, 1.0)
    self.frame:SetMinMaxValues(0, 100)
    self.frame:SetValue(0)

    self.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.bg:SetAllPoints(true)
    self.bg:SetColorTexture(0, 0, 0, 0.5)

    self.text = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    
    self.text:SetFont("Interface\\AddOns\\NaowhUI\\Core\\Media\\Fonts\\Naowh.ttf", 16, "OUTLINE")
    self.text:SetPoint("CENTER", self.frame, "CENTER", 0, 0)

    self.unit = "player"
    self.powerType = nil
    self.powerName = nil

    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)
    self.eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    self.eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    self.elapsedSinceLastUpdate = 0
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdate(elapsed)
    end)

    return self
end

function TUIResourceBar:OnUpdate(elapsed)
    self.elapsedSinceLastUpdate = (self.elapsedSinceLastUpdate or 0) + elapsed
    if self.elapsedSinceLastUpdate >= 0.025 then -- update every 25ms
        self:UpdateValue()
        self.elapsedSinceLastUpdate = 0
    end
end

function TUIResourceBar:OnEvent(event, unit, powerType)
    if unit and unit ~= self.unit then return end
    if event == "PLAYER_ENTERING_WORLD" or event == "UNIT_DISPLAYPOWER" then
        self:UpdatePowerType()
        self:UpdateValue()
    elseif event == "UNIT_POWER_UPDATE" then
        self:UpdateValue()
    end
end

function TUIResourceBar:UpdatePowerType()
    local powerType, powerToken = UnitPowerType(self.unit)
    self.powerType = powerType
    self.color = PowerBarColor[powerToken] or PowerBarColor["MANA"]
    if self.color then
        self.frame:SetStatusBarColor(self.color.r, self.color.g, self.color.b)
    end
end

function TUIResourceBar:UpdateValue()
    local current = UnitPower(self.unit, self.powerType)
    
    local max = UnitPowerMax(self.unit, self.powerType)
    if max == 0 then return end
    self.frame:SetMinMaxValues(0, max)
    self.frame:SetValue(current)
    if current == 0 then
        self.text:SetText("")
    else
        local string_val = ""

        if math.abs(current) >= 10^6 then
            string_val = string.format("%.1fM", current / 10^6)
        elseif math.abs(current) >= 10^3 then
            string_val = string.format("%dk", current / 10^3)
        else
            string_val = string.format("%d", current)
        end
        self.text:SetText(string_val)
    end
end

function TUIResourceBar:OnUpdate(elapsed)
    self.elapsedSinceLastUpdate = self.elapsedSinceLastUpdate + elapsed
    if self.elapsedSinceLastUpdate >= 0.025 then  -- ~40 FPS
        self:UpdateValue()
        self.elapsedSinceLastUpdate = 0
    end
end

function TUIResourceBar:SetPoint(point, relativeTo, relativePoint, x, y)
    self.frame:ClearAllPoints()
    self.frame:SetPoint(point, relativeTo or UIParent, relativePoint or point, x or 0, y or 0)
end

-- NEW: Set width & height dynamically
function TUIResourceBar:SetSize(width, height)
    self.frame:SetSize(width, height)
    self.bg:SetAllPoints(true)
    self.text:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
end

function TUIResourceBar:Hide() self.frame:Hide() end
function TUIResourceBar:Show() self.frame:Show() end
