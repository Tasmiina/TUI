-- TUI Layout Module
-- Handles layout management, positioning, and frame management

---@class TUI_Layout
TUI_Layout = {}

function TUI_Layout:ClearAnchors()
    TUI.main_cooldowns:ClearAllPoints()
    TUI.util_cooldowns:ClearAllPoints()
    TUI.aura_buffs:ClearAllPoints()
    TUI.bars:ClearAllPoints()
    TUI.cast_bar.frame:ClearAllPoints()
    TUI.resource_bar.frame:ClearAllPoints()
    TUI.secondary_resource_bar.frame:ClearAllPoints()
end

function TUI_Layout:DisableBlizz()
    -- The player casting bar is part of PlayerCastingBarFrame, not CastingBarFrame in modern WoW
    if PlayerCastingBarFrame then
        PlayerCastingBarFrame:UnregisterAllEvents()
        PlayerCastingBarFrame:Hide()
    end

    -- Optional: disable pet cast bar
    if PetCastingBarFrame then
        PetCastingBarFrame:UnregisterAllEvents()
        PetCastingBarFrame:Hide()
    end
end

function TUI_Layout:GetAnchorFrame(anchorFrameName)
    -- Convert anchor frame name to actual frame object
    if anchorFrameName == "UIParent" then
        return UIParent
    elseif anchorFrameName == "TUI_MainCooldowns" then
        return TUI.main_cooldowns
    elseif anchorFrameName == "TUI_UtilCooldowns" then
        return TUI.util_cooldowns
    elseif anchorFrameName == "TUI_AuraBuffs" then
        return TUI.aura_buffs
    elseif anchorFrameName == "TUI_Bars" then
        return TUI.bars
    elseif anchorFrameName == "TUI_Castbar" then
        return TUI.cast_bar.frame
    elseif anchorFrameName == "TUI_ResourceBar" then
        return TUI.resource_bar.frame
    elseif anchorFrameName == "TUI_SecondaryResourceBar" then
        return TUI.secondary_resource_bar.frame
    else
        -- Fallback to UIParent if anchor frame is not found
        return UIParent
    end
end

function TUI_Layout:GetFrameVisualBounds(frame)
    -- Get the frame's current bounds
    local left, bottom, width, height = frame:GetRect()
    
    -- If the frame has no meaningful size, try to calculate bounds from children
    if width <= 1 or height <= 1 then
        local minLeft, minBottom, maxRight, maxTop = math.huge, math.huge, -math.huge, -math.huge
        local hasChildren = false
        
        -- Check all children to find the actual visual bounds
        local children = {frame:GetChildren()}
        for _, child in ipairs(children) do
            if child:IsVisible() then
                local childLeft, childBottom, childWidth, childHeight = child:GetRect()
                if childWidth and childHeight and childWidth > 0 and childHeight > 0 then
                    minLeft = math.min(minLeft, childLeft)
                    minBottom = math.min(minBottom, childBottom)
                    maxRight = math.max(maxRight, childLeft + childWidth)
                    maxTop = math.max(maxTop, childBottom + childHeight)
                    hasChildren = true
                end
            end
        end
        
        if hasChildren then
            width = maxRight - minLeft
            height = maxTop - minBottom
        else
            -- Fallback to a reasonable default
            width, height = 200, 100
        end
    end
    
    return width, height
end

function TUI_Layout:RefreshEditModeIndicators()
    if not TUI.editModeEnabled then return end
    
    -- Use a delayed refresh to ensure frames have finished updating their size
    local refreshFrame = CreateFrame("Frame")
    local attempts = 0
    refreshFrame:SetScript("OnUpdate", function(self)
        attempts = attempts + 1
        
        -- Refresh edit mode indicators for all frames to match their current size
        if TUI.main_cooldowns and TUI.main_cooldowns.tuiEditIndicator then
            local visualWidth, visualHeight = TUI_Layout:GetFrameVisualBounds(TUI.main_cooldowns)
            TUI.main_cooldowns.tuiEditIndicator:SetSize(visualWidth, visualHeight)
            
            -- Also update the border sizes
            if TUI.main_cooldowns.tuiEditBorder then
                TUI.main_cooldowns.tuiEditBorder.top:SetSize(visualWidth + 4, 2)
                TUI.main_cooldowns.tuiEditBorder.bottom:SetSize(visualWidth + 4, 2)
                TUI.main_cooldowns.tuiEditBorder.left:SetSize(2, visualHeight + 4)
                TUI.main_cooldowns.tuiEditBorder.right:SetSize(2, visualHeight + 4)
            end
        end
        if TUI.util_cooldowns and TUI.util_cooldowns.tuiEditIndicator then
            local visualWidth, visualHeight = TUI_Layout:GetFrameVisualBounds(TUI.util_cooldowns)
            TUI.util_cooldowns.tuiEditIndicator:SetSize(visualWidth, visualHeight)
            
            -- Also update the border sizes
            if TUI.util_cooldowns.tuiEditBorder then
                TUI.util_cooldowns.tuiEditBorder.top:SetSize(visualWidth + 4, 2)
                TUI.util_cooldowns.tuiEditBorder.bottom:SetSize(visualWidth + 4, 2)
                TUI.util_cooldowns.tuiEditBorder.left:SetSize(2, visualHeight + 4)
                TUI.util_cooldowns.tuiEditBorder.right:SetSize(2, visualHeight + 4)
            end
        end
        if TUI.aura_buffs and TUI.aura_buffs.tuiEditIndicator then
            local visualWidth, visualHeight = TUI_Layout:GetFrameVisualBounds(TUI.aura_buffs)
            TUI.aura_buffs.tuiEditIndicator:SetSize(visualWidth, visualHeight)
            
            -- Also update the border sizes
            if TUI.aura_buffs.tuiEditBorder then
                TUI.aura_buffs.tuiEditBorder.top:SetSize(visualWidth + 4, 2)
                TUI.aura_buffs.tuiEditBorder.bottom:SetSize(visualWidth + 4, 2)
                TUI.aura_buffs.tuiEditBorder.left:SetSize(2, visualHeight + 4)
                TUI.aura_buffs.tuiEditBorder.right:SetSize(2, visualHeight + 4)
            end
        end
        if TUI.bars and TUI.bars.tuiEditIndicator then
            local visualWidth, visualHeight = TUI_Layout:GetFrameVisualBounds(TUI.bars)
            TUI.bars.tuiEditIndicator:SetSize(visualWidth, visualHeight)
            
            -- Also update the border sizes
            if TUI.bars.tuiEditBorder then
                TUI.bars.tuiEditBorder.top:SetSize(visualWidth + 4, 2)
                TUI.bars.tuiEditBorder.bottom:SetSize(visualWidth + 4, 2)
                TUI.bars.tuiEditBorder.left:SetSize(2, visualHeight + 4)
                TUI.bars.tuiEditBorder.right:SetSize(2, visualHeight + 4)
            end
        end
        if TUI.cast_bar and TUI.cast_bar.tuiEditIndicator then
            TUI.cast_bar.tuiEditIndicator:SetAllPoints()
        end
        if TUI.resource_bar and TUI.resource_bar.tuiEditIndicator then
            TUI.resource_bar.tuiEditIndicator:SetAllPoints()
        end
        if TUI.secondary_resource_bar and TUI.secondary_resource_bar.tuiEditIndicator then
            TUI.secondary_resource_bar.tuiEditIndicator:SetAllPoints()
        end
        
        -- Refresh anchor indicators for all frames
        local framesToRefresh = {
            TUI.main_cooldowns, TUI.util_cooldowns, TUI.aura_buffs, TUI.bars,
            TUI.cast_bar, TUI.resource_bar, TUI.secondary_resource_bar
        }
        
        for _, frame in ipairs(framesToRefresh) do
            if frame and frame.tuiAnchorIndicator then
                TUI_EditMode:UpdateAnchorIndicator(frame)
            end
        end
        
        -- Clean up the refresh frame
        self:SetScript("OnUpdate", nil)
    end)
end

function TUI_Layout:UpdateLayout()
    TUI_Layout:ClearAnchors()

    -- Update MainCooldowns according to settings
    local mainCooldownsAnchor = TUI_Layout:GetAnchorFrame(TUI.db.profile.main_cooldowns.anchor_frame)
    TUI.main_cooldowns:SetPoint(TUI.db.profile.main_cooldowns.anchor, mainCooldownsAnchor, TUI.db.profile.main_cooldowns.anchor_to, TUI.db.profile.main_cooldowns.pos_x, TUI.db.profile.main_cooldowns.pos_y)

    TUI.main_cooldowns.firstRowLimit = TUI.db.profile.main_cooldowns.first_row_limit
    TUI.main_cooldowns.firstRowSizeX = TUI.db.profile.main_cooldowns.first_row_size_x
    TUI.main_cooldowns.firstRowSizeY = TUI.db.profile.main_cooldowns.first_row_size_y
    
    TUI.main_cooldowns.rowLimit = TUI.db.profile.main_cooldowns.row_limit
    TUI.main_cooldowns.rowSizeX = TUI.db.profile.main_cooldowns.row_size_x
    TUI.main_cooldowns.rowSizeY = TUI.db.profile.main_cooldowns.row_size_y

    TUI.main_cooldowns.spacingX = TUI.db.profile.main_cooldowns.spacing_x
    TUI.main_cooldowns.spacingY = TUI.db.profile.main_cooldowns.spacing_y
    TUI.main_cooldowns.growDirectionUp = TUI.db.profile.main_cooldowns.grow_direction_up

    TUI.main_cooldowns.alwaysUpdateLayout = true

    TUI.main_cooldowns:Layout()
    TUI.main_cooldowns:Show()
    
    -- Force the frame to be visible and ensure it stays visible
    TUI.main_cooldowns:SetShown(true)

    -- Update UtilCooldowns according to settings
    local utilCooldownsAnchor = TUI_Layout:GetAnchorFrame(TUI.db.profile.util_cooldowns.anchor_frame)
    TUI.util_cooldowns:SetPoint(TUI.db.profile.util_cooldowns.anchor, utilCooldownsAnchor, TUI.db.profile.util_cooldowns.anchor_to, TUI.db.profile.util_cooldowns.pos_x, TUI.db.profile.util_cooldowns.pos_y)

    TUI.util_cooldowns.firstRowLimit = TUI.db.profile.util_cooldowns.first_row_limit
    TUI.util_cooldowns.firstRowSizeX = TUI.db.profile.util_cooldowns.first_row_size_x
    TUI.util_cooldowns.firstRowSizeY = TUI.db.profile.util_cooldowns.first_row_size_y
    
    TUI.util_cooldowns.rowLimit = TUI.db.profile.util_cooldowns.row_limit
    TUI.util_cooldowns.rowSizeX = TUI.db.profile.util_cooldowns.row_size_x
    TUI.util_cooldowns.rowSizeY = TUI.db.profile.util_cooldowns.row_size_y

    TUI.util_cooldowns.spacingX = TUI.db.profile.util_cooldowns.spacing_x
    TUI.util_cooldowns.spacingY = TUI.db.profile.util_cooldowns.spacing_y
    TUI.util_cooldowns.growDirectionUp = TUI.db.profile.util_cooldowns.grow_direction_up

    TUI.util_cooldowns.alwaysUpdateLayout = true

    TUI.util_cooldowns:Layout()
    TUI.util_cooldowns:Show()
    
    -- Force the frame to be visible and ensure it stays visible
    TUI.util_cooldowns:SetShown(true)

    -- Update AuraBuffs according to settings
    local auraBuffsAnchor = TUI_Layout:GetAnchorFrame(TUI.db.profile.aura_buffs.anchor_frame)
    TUI.aura_buffs:SetPoint(TUI.db.profile.aura_buffs.anchor, auraBuffsAnchor, TUI.db.profile.aura_buffs.anchor_to, TUI.db.profile.aura_buffs.pos_x, TUI.db.profile.aura_buffs.pos_y)

    TUI.aura_buffs.childSizeX = TUI.db.profile.aura_buffs.child_width
    TUI.aura_buffs.childSizeY = TUI.db.profile.aura_buffs.child_height
    TUI.aura_buffs.spacing = TUI.db.profile.aura_buffs.child_spacing

    TUI.aura_buffs:Layout()
    TUI.aura_buffs:Show()
    
    -- Force the frame to be visible and ensure it stays visible
    TUI.aura_buffs:SetShown(true)

    -- Update Bars according to settings
    local barsAnchor = TUI_Layout:GetAnchorFrame(TUI.db.profile.bar_buffs.anchor_frame)
    TUI.bars:SetPoint(TUI.db.profile.bar_buffs.anchor, barsAnchor, TUI.db.profile.bar_buffs.anchor_to, TUI.db.profile.bar_buffs.pos_x, TUI.db.profile.bar_buffs.pos_y)

    TUI.bars.childSizeX = TUI.db.profile.bar_buffs.child_width
    TUI.bars.childSizeY = TUI.db.profile.bar_buffs.child_height
    TUI.bars.spacing = TUI.db.profile.bar_buffs.child_spacing

    TUI.bars:Layout()
    TUI.bars:Show()
    
    -- Force the frame to be visible and ensure it stays visible
    TUI.bars:SetShown(true)

    TUI.cast_bar:SetSize(TUI.db.profile.cast_bar.width, TUI.db.profile.cast_bar.height)
    local castBarAnchor = TUI_Layout:GetAnchorFrame(TUI.db.profile.cast_bar.anchor_frame)
    TUI.cast_bar:SetPoint(TUI.db.profile.cast_bar.anchor, castBarAnchor, TUI.db.profile.cast_bar.anchor_to, TUI.db.profile.cast_bar.pos_x, TUI.db.profile.cast_bar.pos_y)

    TUI.resource_bar:SetSize(TUI.db.profile.resource_bar.width, TUI.db.profile.resource_bar.height)
    local resourceBarAnchor = TUI_Layout:GetAnchorFrame(TUI.db.profile.resource_bar.anchor_frame)
    TUI.resource_bar:SetPoint(TUI.db.profile.resource_bar.anchor, resourceBarAnchor, TUI.db.profile.resource_bar.anchor_to, TUI.db.profile.resource_bar.pos_x, TUI.db.profile.resource_bar.pos_y)

    TUI.secondary_resource_bar:SetSize(TUI.db.profile.secondary_resource_bar.width, TUI.db.profile.secondary_resource_bar.height)
    local secondaryResourceBarAnchor = TUI_Layout:GetAnchorFrame(TUI.db.profile.secondary_resource_bar.anchor_frame)
    TUI.secondary_resource_bar:SetPoint(TUI.db.profile.secondary_resource_bar.anchor, secondaryResourceBarAnchor, TUI.db.profile.secondary_resource_bar.anchor_to, TUI.db.profile.secondary_resource_bar.pos_x, TUI.db.profile.secondary_resource_bar.pos_y)

    -- Refresh edit mode indicators if edit mode is enabled
    TUI_Layout:RefreshEditModeIndicators()
end

function TUI_Layout:ConvertAnchorPosition(configKey, oldAnchorFrame, newAnchorFrame)
    -- Get the frame that this config applies to
    local frame = TUI_Layout:GetFrameForConfigKey(configKey)
    if not frame then return end
    
    -- Get current absolute position of the frame
    local frameX, frameY = frame:GetCenter()
    
    -- Get the old anchor frame
    local oldAnchor = _G[oldAnchorFrame]
    if not oldAnchor then return end
    
    -- Get the new anchor frame
    local newAnchor = _G[newAnchorFrame]
    if not newAnchor then return end
    
    -- Calculate the frame's position relative to the old anchor
    local oldAnchorX, oldAnchorY = oldAnchor:GetCenter()
    local oldRelativeX = frameX - oldAnchorX
    local oldRelativeY = frameY - oldAnchorY
    
    -- Calculate the frame's position relative to the new anchor
    local newAnchorX, newAnchorY = newAnchor:GetCenter()
    local newRelativeX = frameX - newAnchorX
    local newRelativeY = frameY - newAnchorY
    
    -- Update the position offsets to maintain absolute position
    local config = TUI.db.profile[configKey]
    if config then
        config.pos_x = newRelativeX
        config.pos_y = newRelativeY
    end
    
    -- Update the layout to apply the new position
    TUI_Layout:UpdateLayout()
end

function TUI_Layout:GetFrameForConfigKey(configKey)
    -- Map config keys to their corresponding frames
    if configKey == "main_cooldowns" then
        return TUI.main_cooldowns
    elseif configKey == "util_cooldowns" then
        return TUI.util_cooldowns
    elseif configKey == "aura_buffs" then
        return TUI.aura_buffs
    elseif configKey == "bar_buffs" then
        return TUI.bars
    elseif configKey == "cast_bar" then
        return TUI.cast_bar.frame
    elseif configKey == "resource_bar" then
        return TUI.resource_bar.frame
    elseif configKey == "secondary_resource_bar" then
        return TUI.secondary_resource_bar.frame
    end
    return nil
end

function TUI_Layout:ApplyDatabaseAnchorSettingsToAllFrames()
    -- Apply database anchor settings to all frames when entering edit mode
    TUI_Layout:ApplyDatabaseAnchorSettings(TUI.main_cooldowns, "main_cooldowns")
    TUI_Layout:ApplyDatabaseAnchorSettings(TUI.util_cooldowns, "util_cooldowns")
    TUI_Layout:ApplyDatabaseAnchorSettings(TUI.aura_buffs, "aura_buffs")
    TUI_Layout:ApplyDatabaseAnchorSettings(TUI.bars, "bar_buffs")
    TUI_Layout:ApplyDatabaseAnchorSettings(TUI.cast_bar.frame, "cast_bar")
    TUI_Layout:ApplyDatabaseAnchorSettings(TUI.resource_bar.frame, "resource_bar")
    TUI_Layout:ApplyDatabaseAnchorSettings(TUI.secondary_resource_bar.frame, "secondary_resource_bar")
    
    -- Now apply the layout using the database settings
    TUI_Layout:UpdateLayout()
end

function TUI_Layout:ApplyDatabaseAnchorSettings(frame, configKey)
    if not frame or not configKey then return end
    
    -- Get the configuration from database
    local config = TUI.db.profile[configKey]
    if not config then 
        return 
    end
    
    -- Get the anchor frame object
    local anchorFrame = TUI_Layout:GetAnchorFrame(config.anchor_frame)
    if not anchorFrame then 
        return 
    end
    
    -- Check if the frame object is valid
    if not frame or not frame.SetPoint then
        return
    end
    
    -- Note: We don't need to call SetPoint here because UpdateLayout() will handle it
    -- This function is just for verification that the database settings are correct
end

function TUI_Layout:ResetPositions()
    print("|cff88ff88TUI:|r Resetting all element positions to defaults.")
    
    -- Reset to default positions
    for key, defaultConfig in pairs(TUI.defaults.profile) do
        if key ~= "edit_mode" and TUI.db.profile[key] then
            for settingKey, defaultValue in pairs(defaultConfig) do
                TUI.db.profile[key][settingKey] = defaultValue
            end
        end
    end
    
    -- Update layout
    TUI_Layout:UpdateLayout()
end

