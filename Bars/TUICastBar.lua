---@class TUICastBar
TUICastBar = {}
TUICastBar.__index = TUICastBar

function TUICastBar:new(name, parent)
    local self = setmetatable({}, TUICastBar)

    self.frame = CreateFrame("StatusBar", name or "TUICastBarFrame", parent or UIParent)
    self.frame:SetSize(200, 20)
    self.frame:SetPoint("CENTER", 0, -200)
    self.frame:SetStatusBarTexture("Interface\\AddOns\\TUI\\Media\\Flat.tga")
    self.frame:SetStatusBarColor(0.2, 0.6, 1)
    self.frame:Hide()

    self.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.bg:SetAllPoints(true)
    self.bg:SetColorTexture(0, 0, 0, 0.5)

    self.spellText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.spellText:SetPoint("BOTTOMLEFT", self.frame, "TOPLEFT", 0, -4)
    self.spellText:SetFont("Interface\\AddOns\\NaowhUI\\Core\\Media\\Fonts\\Naowh.ttf", 14, "OUTLINE")

    self.durationText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.durationText:SetPoint("BOTTOMRIGHT", self.frame, "TOPRIGHT", 0, -4)
    self.durationText:SetFont("Interface\\AddOns\\NaowhUI\\Core\\Media\\Fonts\\Naowh.ttf", 14, "OUTLINE")

    self.startTime, self.endTime, self.isChanneling, self.spellName = nil, nil, false, nil

    self.frame:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdate(elapsed)
    end)

    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, unit)
        self:OnEvent(event, unit)
    end)

    self.eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    self.eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    self.eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    self.eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    self.eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

    return self
end

function TUICastBar:OnEvent(event, unit)
    if unit ~= "player" then return end

    if event == "UNIT_SPELLCAST_START" then
        self.spellName, _, _, self.startTime, self.endTime = UnitCastingInfo("player")
        if self.spellName then
            self.startTime = self.startTime / 1000
            self.endTime = self.endTime / 1000
            self.isChanneling = false
            self.frame:SetMinMaxValues(0, 1)
            self.frame:SetValue(0)
            self.spellText:SetText(self.spellName)
            self.durationText:SetText(string.format("%.1f", (self.endTime - self.startTime)))
            self.frame:Show()
        end

    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        self.spellName, _, _, self.startTime, self.endTime = UnitChannelInfo("player")
        if self.spellName then
            self.startTime = self.startTime / 1000
            self.endTime = self.endTime / 1000
            self.isChanneling = true
            self.frame:SetMinMaxValues(0, 1)
            self.frame:SetValue(1)
            self.spellText:SetText(self.spellName)
            self.durationText:SetText(string.format("%.1f", (self.endTime - self.startTime)))
            self.frame:Show()
        end

    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        self.frame:Hide()
    end
end

function TUICastBar:OnUpdate(elapsed)
    if not self.startTime or not self.endTime or not self.frame:IsShown() then return end
    local now = GetTime()
    if now >= self.endTime then
        self.frame:Hide()
        return
    end
    local progress = self.isChanneling and (self.endTime - now) / (self.endTime - self.startTime)
        or (now - self.startTime) / (self.endTime - self.startTime)

        
    self.durationText:SetText(string.format("%.1f", (self.endTime - now)))
    self.frame:SetValue(progress)
end

function TUICastBar:SetPoint(point, relativeTo, relativePoint, x, y)
    self.frame:ClearAllPoints()
    self.frame:SetPoint(point, relativeTo or UIParent, relativePoint or point, x or 0, y or 0)
end

-- NEW: Set width & height dynamically
function TUICastBar:SetSize(width, height)
    self.frame:SetSize(width, height)
    self.bg:SetAllPoints(true)
    -- self.spellText:SetPoint("BOTTOMLEFT", self.frame, "TOPLEFT", 0, 0)
end

function TUICastBar:Hide() self.frame:Hide() end
function TUICastBar:Show() self.frame:Show() end
