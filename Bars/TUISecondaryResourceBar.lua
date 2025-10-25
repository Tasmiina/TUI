---@class TUISecondaryResourceBar
TUISecondaryResourceBar = {}
TUISecondaryResourceBar.__index = TUISecondaryResourceBar

function TUISecondaryResourceBar:new(name, parent)
    local self = setmetatable({}, TUISecondaryResourceBar)

    -- Main frame
    self.frame = CreateFrame("Frame", name or "TUISecondaryResourceBarFrame", parent or UIParent)
    self.frame:SetSize(200, 16)
    self.frame:SetPoint("CENTER", 0, -255)

    -- Variables
    self.unit = "player"
    self.powerType = nil
    self.powerToken = nil
    self.maxPower = 0
    self.segments = {}  -- fill textures
    self.borders = {}   -- border frames

    -- Layout
    self.segmentWidth = 0
    self.segmentHeight = 0
    self.borderThickness = 1  -- thickness of each border

    -- Event registration
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)
    self.eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    self.eventFrame:RegisterEvent("UNIT_MAXPOWER")
    self.eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

    self.elapsedSinceLastUpdate = 0
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdate(elapsed)
    end)

    return self
end

-- Handle events
function TUISecondaryResourceBar:OnEvent(event, unit, powerType)
    if unit and unit ~= self.unit then return end

    if event == "PLAYER_ENTERING_WORLD" or event == "UNIT_DISPLAYPOWER" or event == "UNIT_MAXPOWER" then
        self:UpdatePowerType()
        self:BuildSegments()
        self:UpdateValue()
    elseif event == "UNIT_POWER_UPDATE" then
        self:UpdateValue()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        self:UpdatePowerType()
    end
end

function TUISecondaryResourceBar:GetSecondaryPowerType()
    local _, class = UnitClass("player")
    local specIndex = GetSpecialization()
    if not class or not specIndex then return nil end

    local secondaryByClass = {
        DEATHKNIGHT = {
            [1] = Enum.PowerType.Runes,  -- Blood
            [2] = Enum.PowerType.Runes,  -- Frost
            [3] = Enum.PowerType.Runes,  -- Unholy
        },
        DRUID = {
            [1] = nil,  -- Balance (Astral Power)
            [2] = Enum.PowerType.ComboPoints, -- Feral
            [3] = nil,                        -- Guardian
            [4] = Enum.PowerType.ComboPoints, -- Restoration (should possibly be updated to be form dependent)
        },
        HUNTER = {
            [1] = nil, -- Beast Mastery
            [2] = nil, -- Marksmanship
            [3] = nil, -- Survival
        },
        MAGE = {
            [1] = Enum.PowerType.ArcaneCharges, -- Arcane
            [2] = nil,                          -- Fire
            [3] = nil,                          -- Frost
        },
        MONK = {
            [1] = Enum.PowerType.Chi, -- Brewmaster
            [2] = Enum.PowerType.Chi, -- Mistweaver
            [3] = Enum.PowerType.Chi, -- Windwalker
        },
        PALADIN = {
            [1] = Enum.PowerType.HolyPower, -- Holy
            [2] = Enum.PowerType.HolyPower, -- Protection
            [3] = Enum.PowerType.HolyPower, -- Retribution
        },
        PRIEST = {
            [1] = nil, -- Discipline
            [2] = nil, -- Holy
            [3] = nil, -- Shadow
        },
        ROGUE = {
            [1] = Enum.PowerType.ComboPoints, -- Assassination
            [2] = Enum.PowerType.ComboPoints, -- Outlaw
            [3] = Enum.PowerType.ComboPoints, -- Subtlety
        },
        SHAMAN = {
            [1] = nil, -- Elemental
            [2] = nil, -- Enhancement
            [3] = nil, -- Restoration
        },
        WARLOCK = {
            [1] = Enum.PowerType.SoulShards, -- Affliction
            [2] = Enum.PowerType.SoulShards, -- Demonology
            [3] = Enum.PowerType.SoulShards, -- Destruction
        },
        WARRIOR = {
            [1] = nil, -- Arms
            [2] = nil, -- Fury
            [3] = nil, -- Protection
        },
        EVOKER = {
            [1] = Enum.PowerType.Essence, -- Devastation
            [2] = Enum.PowerType.Essence, -- Preservation
            [3] = Enum.PowerType.Essence, -- Augmentation
        },
    }

    local classTable = secondaryByClass[class]
    if not classTable then return nil end

    return classTable[specIndex]
end

local SECONDARY_POWER_COLORS = {
    [Enum.PowerType.ComboPoints] = { r = 1, g = 0.9, b = 0.1 },
    [Enum.PowerType.HolyPower]   = { r = 1, g = 0.96, b = 0.41 },
    [Enum.PowerType.Runes]       = { r = 0, g = 0.5, b = 1 },
    [Enum.PowerType.Chi]         = { r = 0, g = 1, b = 0.6 },
    [Enum.PowerType.SoulShards]  = { r = 0.55, g = 0, b = 0.55 },
    [Enum.PowerType.ArcaneCharges] = { r = 0.2, g = 0.6, b = 1 },
    [Enum.PowerType.Essence]     = { r = 0.8, g = 0.2, b = 0.8 },
    [Enum.PowerType.LunarPower]     = { r = 0.3,  g = 0.6,  b = 1.0  },
}

function TUISecondaryResourceBar:UpdatePowerType()
    local secondaryPowerType = self:GetSecondaryPowerType()
    if not secondaryPowerType then
        self.frame:Hide()
        return
    end

    self.powerType = secondaryPowerType
    self.color = SECONDARY_POWER_COLORS[self.powerType] or { r = 1, g = 1, b = 1 }

    -- if self.powerType == Enum.PowerType.Runes then
    --     self.maxPower = 6
    -- else
    -- end
    self.maxPower = UnitPowerMax(self.unit, self.powerType)

    if self.maxPower <= 0 then
        self.frame:Hide()
        return
    end

    self.frame:Show()
end

-- Build segments with borders
function TUISecondaryResourceBar:BuildSegments()
    for _, seg in ipairs(self.segments) do
        seg:Hide()
    end
    wipe(self.segments)

    for _, border in ipairs(self.borders) do
        border:Hide()
    end
    wipe(self.borders)

    if not self.maxPower or self.maxPower <= 0 then return end

    local frameWidth = self.frame:GetWidth()
    local frameHeight = self.frame:GetHeight()
    self.segmentWidth = frameWidth / self.maxPower
    self.segmentHeight = frameHeight

    if self.powerType == Enum.PowerType.LunarPower then
        local fill = self.frame:CreateTexture(nil, "OVERLAY")
        fill:SetAllPoints(self.frame)
        fill:SetColorTexture(self.color.r, self.color.g, self.color.b, 0.8)
        table.insert(self.segments, fill)
        return
    end

    -- Inside BuildSegments
    for i = 1, self.maxPower do
        -- Create border texture
        local border = self.frame:CreateTexture(nil, "BACKGROUND")
        border:SetSize(self.segmentWidth, self.segmentHeight)
        if i == 1 then
            border:SetPoint("LEFT", self.frame, "LEFT", 0, 0)
        else
            border:SetPoint("LEFT", self.borders[i - 1], "RIGHT", 0, 0)
        end
        border:SetColorTexture(0, 0, 0, 1)  -- solid black border
        table.insert(self.borders, border)

        -- Create fill texture inset slightly to show border
        local segment = self.frame:CreateTexture(nil, "OVERLAY")
        segment:SetSize(self.segmentWidth - 2, self.segmentHeight - 2) -- 1px inset on each side
        segment:SetPoint("LEFT", border, "LEFT")
        segment:SetColorTexture(0, 0, 0, 0.5) -- inactive fill
        table.insert(self.segments, segment)
    end
end

-- Update filled segments
function TUISecondaryResourceBar:UpdateValue()
    if not self.powerType or not self.segments then return end

    if self.powerType == Enum.PowerType.LunarPower then
        local current = UnitPower(self.unit, self.powerType)
        local max = UnitPowerMax(self.unit, self.powerType)
        local fill = (max > 0) and (current / max) or 0

        local segment = self.segments[1]
        segment:ClearAllPoints()
        segment:SetPoint("LEFT", self.frame, "LEFT")
        segment:SetWidth(self.frame:GetWidth() * fill)
        segment:SetColorTexture(self.color.r, self.color.g, self.color.b, 0.9)
        return
    end

    if self.powerType == Enum.PowerType.Runes then
        local runeCount = #self.segments
        local runes = {}

        -- Gather rune cooldowns
        for i = 1, runeCount do
            local start, duration, ready = GetRuneCooldown(i)
            local remaining = 0
            if duration > 0 then
                remaining = math.max(duration - (GetTime() - start), 0)
            end
            table.insert(runes, { index = i, remaining = remaining })
        end

        -- Sort runes: available first (remaining == 0), then by remaining time ascending
        table.sort(runes, function(a, b)
            if a.remaining == 0 and b.remaining ~= 0 then
                return true
            elseif a.remaining ~= 0 and b.remaining == 0 then
                return false
            else
                return a.remaining < b.remaining
            end
        end)

        -- Update segments left-to-right based on sorted runes
        for i, segment in ipairs(self.segments) do
            local rune = runes[i]
            local start, duration, ready = GetRuneCooldown(rune.index)
            local fill = 1
            if duration > 0 then
                local elapsed = GetTime() - start
                fill = math.min(elapsed / duration, 1)
            end

            if fill < 0 then
                fill = 0
            end

            segment:SetWidth((self.segmentWidth - 2) * fill)
            segment:SetColorTexture(self.color.r, self.color.g, self.color.b, 1)
        end
    else
        local current = UnitPower(self.unit, self.powerType, true)

        if self.powerType == Enum.PowerType.SoulShards then
            current = current / 10
        end

        -- print(current)

        for i, segment in ipairs(self.segments) do
            local fill = 0

            if i <= math.floor(current) then
                fill = 1
            elseif i == math.ceil(current) then
                fill = current % 1
            else
                fill = 0
            end

            segment:SetWidth((self.segmentWidth - 2) * fill)
            segment:SetColorTexture(self.color.r, self.color.g, self.color.b, 1)
        end
    end
end


-- Resize segments & borders
function TUISecondaryResourceBar:SetSize(width, height)
    self.frame:SetSize(width, height)
    if self.maxPower and self.maxPower > 0 then
        self.segmentWidth = width / self.maxPower
        self.segmentHeight = height
    end
    self:BuildSegments()
    self:UpdateValue()
end

-- Position
function TUISecondaryResourceBar:SetPoint(point, relativeTo, relativePoint, x, y)
    self.frame:ClearAllPoints()
    self.frame:SetPoint(point, relativeTo or UIParent, relativePoint or point, x or 0, y or 0)
end

function TUISecondaryResourceBar:OnUpdate(elapsed)
    self.elapsedSinceLastUpdate = self.elapsedSinceLastUpdate + elapsed
    if self.elapsedSinceLastUpdate >= 0.025 then -- ~40 FPS
        self:UpdateValue()
        self.elapsedSinceLastUpdate = 0
    end
end

-- Show/hide
function TUISecondaryResourceBar:Show() self.frame:Show() end
function TUISecondaryResourceBar:Hide() self.frame:Hide() end
