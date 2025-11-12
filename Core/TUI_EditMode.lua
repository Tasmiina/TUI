local COOLDOWN_FRAME_LABELS = {
    cooldowns_1 = "Cooldowns 1",
    cooldowns_2 = "Cooldowns 2",
    cooldowns_3 = "Cooldowns 3",
    cooldowns_4 = "Cooldowns 4",
    cooldowns_5 = "Cooldowns 5",
    cooldowns_6 = "Cooldowns 6",
}

local function IterateCooldownFrames(callback)
    if not TUI or not TUI.cooldown_frames then
        return
    end

    for key, frame in pairs(TUI.cooldown_frames) do
        if frame then
            local configKey = TUI.cooldown_frame_configs and TUI.cooldown_frame_configs[key] or key
            local label = (TUI.cooldown_frame_names and TUI.cooldown_frame_names[key]) or COOLDOWN_FRAME_LABELS[key] or key
            callback(key, frame, configKey, label)
        end
    end
end

-- TUI Edit Mode Module
-- Handles all edit mode functionality including dragging, indicators, and grid

---@class TUI_EditMode
TUI_EditMode = {}

-- Edit Mode Functions
function TUI_EditMode:ToggleEditMode()
    TUI.editModeEnabled = not TUI.editModeEnabled
    
    if TUI.editModeEnabled then
        TUI_EditMode:EnterEditMode()
    else
        TUI_EditMode:ExitEditMode()
    end
end

function TUI_EditMode:EnterEditMode()
    print("|cff88ff88TUI:|r Entering edit mode. Drag elements to reposition them.")
    
    -- Apply database anchor settings to all frames when entering edit mode
    TUI_Layout:ApplyDatabaseAnchorSettingsToAllFrames()
    
    -- Wait a frame for layout to complete, then continue with edit mode setup
    local continueFrame = CreateFrame("Frame")
    continueFrame:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        TUI_EditMode:ContinueEditModeSetup()
    end)
end

function TUI_EditMode:ContinueEditModeSetup()
    -- Ensure cast bar and secondary resource bar are visible
    TUI.cast_bar:Show()
    TUI.secondary_resource_bar.frame:Show()
    
    -- Force visibility in edit mode by temporarily overriding their visibility logic
    TUI.cast_bar.tuiEditModeForced = true
    TUI.secondary_resource_bar.tuiEditModeForced = true
    
    -- Add temporary children to frames with less than 3 children
    TUI_EditMode:AddTemporaryChildrenForEditMode()
    
    TUI_EditMode:CreateEditModeOverlay()
    
    -- Enable dragging for all elements
    TUI_EditMode:EnableElementDragging()
    
    
    IterateCooldownFrames(function(_, frame)
        frame.tuiEditModeForced = true
        frame:SetShown(true)

        if frame.tuiEditModeUpdateFrame then
            frame.tuiEditModeUpdateFrame:SetScript("OnUpdate", nil)
        end

        frame.tuiEditModeUpdateFrame = CreateFrame("Frame")
        frame.tuiEditModeUpdateFrame:SetScript("OnUpdate", function(self)
            if TUI.editModeEnabled and frame and frame.tuiEditModeForced then
                frame:Layout()
                frame:SetShown(true)

                local indicator = rawget(frame, "tuiEditIndicator")
                if indicator then
                    local visualWidth, visualHeight = TUI_Layout:GetFrameVisualBounds(frame)
                    indicator:SetSize(visualWidth, visualHeight)

                    local border = rawget(frame, "tuiEditBorder")
                    if border then
                        border.top:SetSize(visualWidth + 4, 2)
                        border.bottom:SetSize(visualWidth + 4, 2)
                        border.left:SetSize(2, visualHeight + 4)
                        border.right:SetSize(2, visualHeight + 4)
                    end
                end
            else
                self:SetScript("OnUpdate", nil)
            end
        end)
    end)
    
    -- Force aura buffs to update its layout periodically in edit mode
    if TUI.aura_buffs then
        TUI.aura_buffs.tuiEditModeForced = true
        TUI.aura_buffs:SetShown(true)
        
        TUI.aura_buffs.tuiEditModeUpdateFrame = CreateFrame("Frame")
        TUI.aura_buffs.tuiEditModeUpdateFrame:SetScript("OnUpdate", function(self)
            if TUI.editModeEnabled and TUI.aura_buffs and TUI.aura_buffs.tuiEditModeForced then
                -- Force layout update every few frames
                TUI.aura_buffs:Layout()
                TUI.aura_buffs:SetShown(true)
                
                -- Also refresh the edit mode indicator size
                if TUI.aura_buffs.tuiEditIndicator then
                    local visualWidth, visualHeight = TUI_Layout:GetFrameVisualBounds(TUI.aura_buffs)
                    TUI.aura_buffs.tuiEditIndicator:SetSize(visualWidth, visualHeight)
                    
                    -- Update border sizes too
                    if TUI.aura_buffs.tuiEditBorder then
                        TUI.aura_buffs.tuiEditBorder.top:SetSize(visualWidth + 4, 2)
                        TUI.aura_buffs.tuiEditBorder.bottom:SetSize(visualWidth + 4, 2)
                        TUI.aura_buffs.tuiEditBorder.left:SetSize(2, visualHeight + 4)
                        TUI.aura_buffs.tuiEditBorder.right:SetSize(2, visualHeight + 4)
                    end
                end
            else
                -- Clean up when edit mode is disabled
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
    
    -- Force bars to update its layout periodically in edit mode
    if TUI.bars then
        TUI.bars.tuiEditModeForced = true
        TUI.bars:SetShown(true)
        
        TUI.bars.tuiEditModeUpdateFrame = CreateFrame("Frame")
        TUI.bars.tuiEditModeUpdateFrame:SetScript("OnUpdate", function(self)
            if TUI.editModeEnabled and TUI.bars and TUI.bars.tuiEditModeForced then
                -- Force layout update every few frames
                TUI.bars:Layout()
                TUI.bars:SetShown(true)
                
                -- Also refresh the edit mode indicator size
                if TUI.bars.tuiEditIndicator then
                    local visualWidth, visualHeight = TUI_Layout:GetFrameVisualBounds(TUI.bars)
                    TUI.bars.tuiEditIndicator:SetSize(visualWidth, visualHeight)
                    
                    -- Update border sizes too
                    if TUI.bars.tuiEditBorder then
                        TUI.bars.tuiEditBorder.top:SetSize(visualWidth + 4, 2)
                        TUI.bars.tuiEditBorder.bottom:SetSize(visualWidth + 4, 2)
                        TUI.bars.tuiEditBorder.left:SetSize(2, visualHeight + 4)
                        TUI.bars.tuiEditBorder.right:SetSize(2, visualHeight + 4)
                    end
                end
            else
                -- Clean up when edit mode is disabled
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
    
    -- Show grid if enabled
    if TUI.db.profile.edit_mode.show_grid then
        TUI_EditMode:ShowGrid()
    end
end

function TUI_EditMode:AddTemporaryChildrenForEditMode()
    -- Add temporary children to frames that have less than 3 children
    local framesToCheck = {}
    IterateCooldownFrames(function(key, frame, _, label)
        table.insert(framesToCheck, { frame = frame, name = label or key, childCount = 3 })
    end)
    table.insert(framesToCheck, { frame = TUI.aura_buffs, name = "Aura Buffs", childCount = 3 })
    table.insert(framesToCheck, { frame = TUI.bars, name = "Bars", childCount = 3 })
    
    for _, frameInfo in ipairs(framesToCheck) do
        local frame = frameInfo.frame
        if frame then
            
            -- Ensure frame is visible
            frame:Show()
            frame:SetShown(true)
            
            local children = {frame:GetChildren()}
            local visibleChildren = 0
            
            -- Count only visible children
            for _, child in ipairs(children) do
                if child:IsVisible() and not child.tuiTemporaryChild then
                    visibleChildren = visibleChildren + 1
                end
            end
            
            
            -- Add temporary children if needed
            if visibleChildren < frameInfo.childCount then
                local needed = frameInfo.childCount - visibleChildren
                
                for i = 1, needed do
                    local tempChild = CreateFrame("Frame", nil, frame)
                    tempChild.tuiTemporaryChild = true
                    
                    -- Set appropriate size based on frame type
                    if frameInfo.name == "Bars" then
                        tempChild:SetSize(frame.childSizeX or 220, frame.childSizeY or 20)
                    elseif frameInfo.name == "Aura Buffs" then
                        tempChild:SetSize(frame.childSizeX or 40, frame.childSizeY or 40)
                    else -- Cooldowns
                        tempChild:SetSize(frame.firstRowSizeX or 38, frame.firstRowSizeY or 32)
                    end
                    
                    -- Add a visible background to make the temporary child visible
                    local bg = tempChild:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    bg:SetColorTexture(0.5, 0.5, 0.5, 0.3) -- Semi-transparent gray
                    
                    -- Add a border to make it more visible
                    local border = tempChild:CreateTexture(nil, "BORDER")
                    border:SetAllPoints()
                    border:SetColorTexture(1, 1, 0, 0.5) -- Semi-transparent yellow
                    
                    -- Make it a proper layout child by setting layoutIndex
                    tempChild.layoutIndex = 999 + i -- High index to place at end
                    tempChild.includeInLayout = true -- Ensure it's included
                    
                    tempChild:Show()
                    
                end
                
                -- Force layout update to position all children properly
                frame:Layout()
            end
        else
        end
    end
end

function TUI_EditMode:RemoveTemporaryChildren()
    -- Remove all temporary children from frames
    local framesToCheck = {}
    IterateCooldownFrames(function(_, frame)
        table.insert(framesToCheck, frame)
    end)
    table.insert(framesToCheck, TUI.aura_buffs)
    table.insert(framesToCheck, TUI.bars)
    
    for _, frame in ipairs(framesToCheck) do
        if frame then
            local children = {frame:GetChildren()}
            for _, child in ipairs(children) do
                if child.tuiTemporaryChild then
                    child:Hide()
                    child:SetParent(nil)
                end
            end
        end
    end
end

function TUI_EditMode:ExitEditMode()
    print("|cff88ff88TUI:|r Exiting edit mode.")
    
    -- Clear forced visibility flags
    if TUI.cast_bar then
        TUI.cast_bar.tuiEditModeForced = false
    end
    if TUI.secondary_resource_bar then
        TUI.secondary_resource_bar.tuiEditModeForced = false
    end
    
    IterateCooldownFrames(function(_, frame)
        frame.tuiEditModeForced = false
        if frame.tuiEditModeUpdateFrame then
            frame.tuiEditModeUpdateFrame:SetScript("OnUpdate", nil)
            frame.tuiEditModeUpdateFrame = nil
        end
    end)
    
    -- Clear aura buffs forced visibility and update frame
    if TUI.aura_buffs then
        TUI.aura_buffs.tuiEditModeForced = false
        if TUI.aura_buffs.tuiEditModeUpdateFrame then
            TUI.aura_buffs.tuiEditModeUpdateFrame:SetScript("OnUpdate", nil)
            TUI.aura_buffs.tuiEditModeUpdateFrame = nil
        end
    end
    
    -- Clear bars forced visibility and update frame
    if TUI.bars then
        TUI.bars.tuiEditModeForced = false
        if TUI.bars.tuiEditModeUpdateFrame then
            TUI.bars.tuiEditModeUpdateFrame:SetScript("OnUpdate", nil)
            TUI.bars.tuiEditModeUpdateFrame = nil
        end
    end
    
    -- Remove temporary children added for edit mode
    TUI_EditMode:RemoveTemporaryChildren()
    
    -- Disable dragging for all elements
    TUI_EditMode:DisableElementDragging()
    
    -- Hide grid
    TUI_EditMode:HideGrid()
    
    -- Remove edit mode overlay
    TUI_EditMode:RemoveEditModeOverlay()
    
    -- Update layout to apply any changes
    TUI_Layout:UpdateLayout()
    
    -- Note: We don't hide the frames here because UpdateLayout() will handle their visibility
    -- based on their normal logic (e.g., main_cooldowns may be hidden if no cooldowns are active)
end

function TUI_EditMode:CreateEditModeOverlay()
    if TUI.editModeOverlay then return end
    
    TUI.editModeOverlay = CreateFrame("Frame", "TUI_EditModeOverlay", UIParent)
    TUI.editModeOverlay:SetAllPoints()
    TUI.editModeOverlay:SetFrameStrata("TOOLTIP")
    TUI.editModeOverlay:SetFrameLevel(1000)
    TUI.editModeOverlay:EnableMouse(false)
    
    -- Add instructions text
    local instructions = TUI.editModeOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    instructions:SetPoint("TOP", UIParent, "TOP", 0, -50)
    instructions:SetText("|cffffffffTUI Edit Mode|r - Drag elements to reposition them")
    instructions:SetTextColor(1, 1, 0)
    
    -- Add right-click instructions
    local rightClickInstructions = TUI.editModeOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rightClickInstructions:SetPoint("TOP", instructions, "BOTTOM", 0, -10)
    rightClickInstructions:SetText("Right-click any frame for additional settings")
    rightClickInstructions:SetTextColor(0.8, 0.8, 0.8)
    
    -- Add exit instructions
    local exitInstructions = TUI.editModeOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    exitInstructions:SetPoint("TOP", rightClickInstructions, "BOTTOM", 0, -10)
    exitInstructions:SetText("Type |cffffffff/tui edit|r to exit edit mode")
    exitInstructions:SetTextColor(0.8, 0.8, 0.8)
end

function TUI_EditMode:RemoveEditModeOverlay()
    if TUI.editModeOverlay then
        TUI.editModeOverlay:Hide()
        TUI.editModeOverlay = nil
    end
end

function TUI_EditMode:ShowGrid()
    if TUI.gridFrame then return end
    
    TUI.gridFrame = CreateFrame("Frame", "TUI_GridFrame", UIParent)
    TUI.gridFrame:SetAllPoints()
    TUI.gridFrame:SetFrameStrata("BACKGROUND")
    TUI.gridFrame:SetFrameLevel(1)
    TUI.gridFrame:EnableMouse(false)
    
    local gridSize = TUI.db.profile.edit_mode.grid_size
    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    
    -- Vertical lines
    local numVerticalLines = math.ceil(screenWidth / gridSize) + 1
    for i = 0, numVerticalLines do
        local x = i * gridSize
        local line = TUI.gridFrame:CreateTexture(nil, "BACKGROUND")
        line:SetTexture("Interface\\AddOns\\TUI\\Media\\Flat.tga")
        line:SetColorTexture(0.3, 0.3, 0.3, 0.3)
        line:SetPoint("TOPLEFT", TUI.gridFrame, "TOPLEFT", x, 0)
        line:SetPoint("BOTTOMLEFT", TUI.gridFrame, "BOTTOMLEFT", x, 0)
        line:SetWidth(1)
    end
    
    -- Horizontal lines
    local numHorizontalLines = math.ceil(screenHeight / gridSize) + 1
    for i = 0, numHorizontalLines do
        local y = i * gridSize
        local line = TUI.gridFrame:CreateTexture(nil, "BACKGROUND")
        line:SetTexture("Interface\\AddOns\\TUI\\Media\\Flat.tga")
        line:SetColorTexture(0.3, 0.3, 0.3, 0.3)
        line:SetPoint("TOPLEFT", TUI.gridFrame, "TOPLEFT", 0, -y)
        line:SetPoint("TOPRIGHT", TUI.gridFrame, "TOPRIGHT", 0, -y)
        line:SetHeight(1)
    end
end

function TUI_EditMode:HideGrid()
    if TUI.gridFrame then
        TUI.gridFrame:Hide()
        TUI.gridFrame = nil
    end
end

function TUI_EditMode:EnableElementDragging()
    -- Enable dragging for all UI elements with user-friendly names
    IterateCooldownFrames(function(key, frame, configKey, label)
        TUI_EditMode:EnableDraggingForElement(frame, configKey, label)
    end)
    TUI_EditMode:EnableDraggingForElement(TUI.aura_buffs, "aura_buffs", "Aura Buffs")
    TUI_EditMode:EnableDraggingForElement(TUI.bars, "bar_buffs", "Bar Buffs")
    TUI_EditMode:EnableDraggingForElement(TUI.cast_bar.frame, "cast_bar", "Cast Bar")
    TUI_EditMode:EnableDraggingForElement(TUI.resource_bar.frame, "resource_bar", "Resource Bar")
    TUI_EditMode:EnableDraggingForElement(TUI.secondary_resource_bar.frame, "secondary_resource_bar", "Secondary Resource Bar")
end

function TUI_EditMode:DisableElementDragging()
    -- Disable dragging for all UI elements
    IterateCooldownFrames(function(_, frame)
        TUI_EditMode:DisableDraggingForElement(frame)
    end)
    TUI_EditMode:DisableDraggingForElement(TUI.aura_buffs)
    TUI_EditMode:DisableDraggingForElement(TUI.bars)
    TUI_EditMode:DisableDraggingForElement(TUI.cast_bar.frame)
    TUI_EditMode:DisableDraggingForElement(TUI.resource_bar.frame)
    TUI_EditMode:DisableDraggingForElement(TUI.secondary_resource_bar.frame)
end

function TUI_EditMode:EnableDraggingForElement(element, configKey, elementName)
    if not element or not configKey then return end
    
    local frame = element.frame or element
    
    -- Store original state
    frame.tuiOriginalMovable = frame:IsMovable()
    frame.tuiOriginalMouseEnabled = frame:IsMouseEnabled()
    
    -- Enable dragging
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    
    -- Add visual indicator with name
    TUI_EditMode:AddEditModeIndicator(frame, elementName)
    
    -- Add anchor indicator
    TUI_EditMode:AddAnchorIndicator(frame, elementName)
    
    frame:SetScript("OnDragStart", function(self)
        -- Don't use StartMoving() - we'll handle positioning manually
        self.tuiIsDragging = true
        
        -- Store initial mouse position and frame position
        self.tuiDragStartX, self.tuiDragStartY = GetCursorPosition()
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
        self.tuiDragStartPoint = {point, relativeTo, relativePoint, xOfs, yOfs}
        
        -- Add visual feedback during drag
        if self.tuiEditIndicator then
            self.tuiEditIndicator:SetColorTexture(1, 0.5, 0, 0.5) -- Orange tint while dragging
        end
        
        self.tuiAnchorDisplay = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        self.tuiAnchorDisplay:SetPoint("TOP", self, "BOTTOM", 0, -5)
        self.tuiAnchorDisplay:SetTextColor(1, 1, 0, 1) -- Yellow text
        self.tuiAnchorDisplay:SetShadowColor(0, 0, 0, 1)
        self.tuiAnchorDisplay:SetShadowOffset(1, -1)
        
        -- Update anchor display
        TUI_EditMode:UpdateAnchorDisplay(self)
        
        -- Add update handler to refresh anchor display and position during drag
        self.tuiDragUpdateFrame = CreateFrame("Frame")
        self.tuiDragUpdateFrame:SetScript("OnUpdate", function()
            if self.tuiIsDragging then
                TUI_EditMode:UpdateFramePositionDuringDrag(self)
                TUI_EditMode:UpdateAnchorDisplay(self)
            else
                self.tuiDragUpdateFrame:SetScript("OnUpdate", nil)
            end
        end)
    end)
    
    frame:SetScript("OnDragStop", function(self)
        self.tuiIsDragging = false
        
        -- Restore visual indicator color
        if self.tuiEditIndicator then
            self.tuiEditIndicator:SetColorTexture(1, 1, 0, 0.3) -- Back to yellow tint
        end
        
        -- Remove anchor display
        if self.tuiAnchorDisplay then
            self.tuiAnchorDisplay:Hide()
            self.tuiAnchorDisplay = nil
        end
        
        -- Clean up update frame
        if self.tuiDragUpdateFrame then
            self.tuiDragUpdateFrame:SetScript("OnUpdate", nil)
            self.tuiDragUpdateFrame = nil
        end
        
        -- Save new position
        TUI_EditMode:SaveElementPosition(self, configKey)
    end)
end

function TUI_EditMode:DisableDraggingForElement(element)
    if not element then return end
    
    local frame = element.frame or element
    
    -- Restore original state
    if frame.tuiOriginalMovable ~= nil then
        frame:SetMovable(frame.tuiOriginalMovable)
    end
    if frame.tuiOriginalMouseEnabled ~= nil then
        frame:EnableMouse(frame.tuiOriginalMouseEnabled)
    end
    
    -- Remove drag handlers
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
    
    -- Remove visual indicator
    TUI_EditMode:RemoveEditModeIndicator(frame)
end

function TUI_EditMode:AddAnchorIndicator(frame, elementName)
    if frame.tuiAnchorIndicator then return end
    
    -- Create a small indicator showing the anchor point
    local indicator = frame:CreateTexture(nil, "OVERLAY")
    indicator:SetSize(8, 8)
    indicator:SetColorTexture(1, 1, 0, 0.8) -- Bright yellow
    indicator:SetDrawLayer("OVERLAY", 7)
    
    frame.tuiAnchorIndicator = indicator
    
    -- Update the indicator position
    TUI_EditMode:UpdateAnchorIndicator(frame)
end

function TUI_EditMode:UpdateAnchorIndicator(frame)
    if not frame.tuiAnchorIndicator then return end
    
    local configKey = TUI_EditMode:GetConfigKeyForFrame(frame)
    if not configKey then return end
    
    local config = TUI.db.profile[configKey]
    if not config then return end
    
    local anchorPoint = config.anchor or "CENTER"
    
    -- Position the indicator at the anchor point relative to the frame
    frame.tuiAnchorIndicator:ClearAllPoints()
    
    -- Position the indicator at the appropriate anchor point on the frame
    if anchorPoint == "TOPLEFT" then
        frame.tuiAnchorIndicator:SetPoint("CENTER", frame, "TOPLEFT", 0, 0)
    elseif anchorPoint == "TOP" then
        frame.tuiAnchorIndicator:SetPoint("CENTER", frame, "TOP", 0, 0)
    elseif anchorPoint == "TOPRIGHT" then
        frame.tuiAnchorIndicator:SetPoint("CENTER", frame, "TOPRIGHT", 0, 0)
    elseif anchorPoint == "LEFT" then
        frame.tuiAnchorIndicator:SetPoint("CENTER", frame, "LEFT", 0, 0)
    elseif anchorPoint == "CENTER" then
        frame.tuiAnchorIndicator:SetPoint("CENTER", frame, "CENTER", 0, 0)
    elseif anchorPoint == "RIGHT" then
        frame.tuiAnchorIndicator:SetPoint("CENTER", frame, "RIGHT", 0, 0)
    elseif anchorPoint == "BOTTOMLEFT" then
        frame.tuiAnchorIndicator:SetPoint("CENTER", frame, "BOTTOMLEFT", 0, 0)
    elseif anchorPoint == "BOTTOM" then
        frame.tuiAnchorIndicator:SetPoint("CENTER", frame, "BOTTOM", 0, 0)
    elseif anchorPoint == "BOTTOMRIGHT" then
        frame.tuiAnchorIndicator:SetPoint("CENTER", frame, "BOTTOMRIGHT", 0, 0)
    end
end

function TUI_EditMode:RemoveAnchorIndicator(frame)
    if frame.tuiAnchorIndicator then
        frame.tuiAnchorIndicator:Hide()
        frame.tuiAnchorIndicator = nil
    end
end

function TUI_EditMode:AddEditModeIndicator(frame, elementName)
    if frame.tuiEditIndicator then return end
    
    -- Calculate the actual visual bounds of the frame
    local visualWidth, visualHeight = TUI_Layout:GetFrameVisualBounds(frame)
    
    frame.tuiEditIndicator = frame:CreateTexture(nil, "OVERLAY")
    frame.tuiEditIndicator:SetSize(visualWidth, visualHeight)
    frame.tuiEditIndicator:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.tuiEditIndicator:SetTexture("Interface\\AddOns\\TUI\\Media\\Flat.tga")
    frame.tuiEditIndicator:SetColorTexture(1, 1, 0, 0.3) -- Yellow tint
    frame.tuiEditIndicator:SetBlendMode("ADD")
    
    frame.tuiEditBorder = {}
    
    -- Top border
    frame.tuiEditBorder.top = frame:CreateTexture(nil, "OVERLAY")
    frame.tuiEditBorder.top:SetTexture("Interface\\AddOns\\TUI\\Media\\Flat.tga")
    frame.tuiEditBorder.top:SetColorTexture(1, 1, 0, 0.8)
    frame.tuiEditBorder.top:SetSize(visualWidth + 4, 2)
    frame.tuiEditBorder.top:SetPoint("TOP", frame.tuiEditIndicator, "TOP", 0, 2)
    
    -- Bottom border
    frame.tuiEditBorder.bottom = frame:CreateTexture(nil, "OVERLAY")
    frame.tuiEditBorder.bottom:SetTexture("Interface\\AddOns\\TUI\\Media\\Flat.tga")
    frame.tuiEditBorder.bottom:SetColorTexture(1, 1, 0, 0.8)
    frame.tuiEditBorder.bottom:SetSize(visualWidth + 4, 2)
    frame.tuiEditBorder.bottom:SetPoint("BOTTOM", frame.tuiEditIndicator, "BOTTOM", 0, -2)
    
    -- Left border
    frame.tuiEditBorder.left = frame:CreateTexture(nil, "OVERLAY")
    frame.tuiEditBorder.left:SetTexture("Interface\\AddOns\\TUI\\Media\\Flat.tga")
    frame.tuiEditBorder.left:SetColorTexture(1, 1, 0, 0.8)
    frame.tuiEditBorder.left:SetSize(2, visualHeight + 4)
    frame.tuiEditBorder.left:SetPoint("LEFT", frame.tuiEditIndicator, "LEFT", -2, 0)
    
    -- Right border
    frame.tuiEditBorder.right = frame:CreateTexture(nil, "OVERLAY")
    frame.tuiEditBorder.right:SetTexture("Interface\\AddOns\\TUI\\Media\\Flat.tga")
    frame.tuiEditBorder.right:SetColorTexture(1, 1, 0, 0.8)
    frame.tuiEditBorder.right:SetSize(2, visualHeight + 4)
    frame.tuiEditBorder.right:SetPoint("RIGHT", frame.tuiEditIndicator, "RIGHT", 2, 0)
    
    if elementName then
        frame.tuiEditLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame.tuiEditLabel:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.tuiEditLabel:SetText(elementName)
        frame.tuiEditLabel:SetTextColor(1, 1, 0, 1) -- Yellow text
        frame.tuiEditLabel:SetShadowColor(0, 0, 0, 1)
        frame.tuiEditLabel:SetShadowOffset(1, -1)
    end
    
    frame.tuiEditRightClickOverlay = CreateFrame("Button", nil, frame)
    frame.tuiEditRightClickOverlay:SetAllPoints(frame)
    frame.tuiEditRightClickOverlay:SetFrameStrata("TOOLTIP")
    frame.tuiEditRightClickOverlay:SetFrameLevel(frame:GetFrameLevel() + 10)
    frame.tuiEditRightClickOverlay:EnableMouse(true)
    frame.tuiEditRightClickOverlay:RegisterForClicks("RightButtonUp")
    frame.tuiEditRightClickOverlay:RegisterForDrag("LeftButton")
    
    -- Store element name and config key for settings
    frame.tuiEditRightClickOverlay.elementName = elementName
    frame.tuiEditRightClickOverlay.configKey = TUI_EditMode:GetConfigKeyForFrame(frame)
    
    -- Add right-click handler
    frame.tuiEditRightClickOverlay:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            TUI_Config:OpenFrameSettings(self.elementName, self.configKey)
        end
    end)
    
    -- Pass drag events to the parent frame
    frame.tuiEditRightClickOverlay:SetScript("OnDragStart", function(self)
        local parent = self:GetParent()
        if parent and parent:GetScript("OnDragStart") then
            parent:GetScript("OnDragStart")(parent)
        end
    end)
    
    frame.tuiEditRightClickOverlay:SetScript("OnDragStop", function(self)
        local parent = self:GetParent()
        if parent and parent:GetScript("OnDragStop") then
            parent:GetScript("OnDragStop")(parent)
        end
    end)
    
    -- Add tooltip
    frame.tuiEditRightClickOverlay:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText("Right-click to open settings for " .. (self.elementName or "this element"))
        GameTooltip:AddLine("Left-click and drag to move", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    
    frame.tuiEditRightClickOverlay:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

function TUI_EditMode:RemoveEditModeIndicator(frame)
    if frame.tuiEditIndicator then
        frame.tuiEditIndicator:Hide()
        frame.tuiEditIndicator = nil
    end
    if frame.tuiEditBorder then
        -- Hide and clean up all border textures
        for _, borderTexture in pairs(frame.tuiEditBorder) do
            borderTexture:Hide()
        end
        frame.tuiEditBorder = nil
    end
    if frame.tuiEditLabel then
        frame.tuiEditLabel:Hide()
        frame.tuiEditLabel = nil
    end
    if frame.tuiEditRightClickOverlay then
        frame.tuiEditRightClickOverlay:Hide()
        frame.tuiEditRightClickOverlay = nil
    end
    
    -- Remove anchor indicator
    TUI_EditMode:RemoveAnchorIndicator(frame)
end

function TUI_EditMode:GetConfigKeyForFrame(frame)
    -- Map frame names to their configuration keys
    local frameName = frame:GetName()
    
    if TUI and TUI.cooldown_frames then
        for key, cooldownFrame in pairs(TUI.cooldown_frames) do
            local expectedName = cooldownFrame and cooldownFrame.GetName and cooldownFrame:GetName()
            if frame == cooldownFrame or (expectedName and frameName == expectedName) then
                return TUI.cooldown_frame_configs and TUI.cooldown_frame_configs[key] or key
            end
        end
    end

    if frameName == "TUI_AuraBuffs" then
        return "aura_buffs"
    elseif frameName == "TUI_Bars" then
        return "bar_buffs"
    elseif frameName == "TUI_AuraBuffs" then
        return "aura_buffs"
    elseif frameName == "TUI_Bars" then
        return "bar_buffs"
    elseif frameName == "TUI_Castbar" then
        return "cast_bar"
    elseif frameName == "TUI_ResourceBar" then
        return "resource_bar"
    elseif frameName == "TUI_SecondaryResourceBar" then
        return "secondary_resource_bar"
    end
    
    -- If no specific mapping found, try to match by checking if it's one of our known frames
    if TUI.cast_bar and frame == TUI.cast_bar.frame then
        return "cast_bar"
    elseif TUI.resource_bar and frame == TUI.resource_bar.frame then
        return "resource_bar"
    elseif TUI.secondary_resource_bar and frame == TUI.secondary_resource_bar.frame then
        return "secondary_resource_bar"
    end
    
    return nil
end

function TUI_EditMode:UpdateFramePositionDuringDrag(frame)
    if not frame or not frame.tuiIsDragging or not frame.tuiDragStartPoint then return end
    
    -- Get current mouse position in UI coordinates
    local currentX, currentY = GetCursorPosition()
    currentX = currentX / UIParent:GetEffectiveScale()
    currentY = currentY / UIParent:GetEffectiveScale()
    
    -- Convert stored start position to UI coordinates
    local startX = frame.tuiDragStartX / UIParent:GetEffectiveScale()
    local startY = frame.tuiDragStartY / UIParent:GetEffectiveScale()
    
    -- Calculate mouse movement
    local deltaX = currentX - startX
    local deltaY = currentY - startY
    
    -- Get the anchor frame
    local anchorFrame = frame.tuiDragStartPoint[2]
    
    -- Calculate new position relative to anchor
    local newX = frame.tuiDragStartPoint[4] + deltaX
    local newY = frame.tuiDragStartPoint[5] + deltaY
    
    -- Set the new position while maintaining the anchor relationship
    frame:SetPoint(frame.tuiDragStartPoint[1], anchorFrame, frame.tuiDragStartPoint[3], newX, newY)
end

function TUI_EditMode:UpdateAnchorDisplay(frame)
    if not frame or not frame.tuiAnchorDisplay then return end
    
    -- Get current anchor information
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
    
    -- Format the anchor display
    local anchorText = string.format("Anchor: %s to %s.%s (%.0f, %.0f)", 
        point or "NONE",
        relativeTo and relativeTo:GetName() or "NONE", 
        relativePoint or "NONE",
        xOfs or 0, 
        yOfs or 0
    )
    
    frame.tuiAnchorDisplay:SetText(anchorText)
end

function TUI_EditMode:SaveElementPosition(frame, configKey)
    if not frame or not configKey then return end
    
    -- Get current position
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
    local anchorFrameName = "UIParent"
    if relativeTo and relativeTo.GetName then
        anchorFrameName = relativeTo:GetName() or anchorFrameName
    end
    local anchorConfigKey = TUI_EditMode:GetConfigKeyForFrame(relativeTo or frame)
    if anchorConfigKey and TUI and TUI.cooldown_frame_configs then
        for key, configName in pairs(TUI.cooldown_frame_configs) do
            if configName == anchorConfigKey and TUI.cooldown_frames and relativeTo == TUI.cooldown_frames[key] then
                anchorFrameName = relativeTo:GetName()
                break
            end
        end
    end
    
    -- Update database - preserve existing anchor settings, only update position
    local config = TUI.db.profile[configKey]
    if not config then
        config = {}
        TUI.db.profile[configKey] = config
    end
    
    config.anchor = point or config.anchor or "CENTER"
    config.anchor_to = relativePoint or config.anchor_to or config.anchor or "CENTER"
    config.anchor_frame = anchorFrameName or config.anchor_frame or "UIParent"
    if config then
        config.pos_x = xOfs
        config.pos_y = yOfs
    end
end

