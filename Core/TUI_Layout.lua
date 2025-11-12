-- TUI Layout Module
-- Handles layout management, positioning, and frame management

---@class TUI_Layout
TUI_Layout = {}

local COOLDOWN_LAYOUT_CONFIGS = {
    { key = "cooldowns_1", configKey = "main_cooldowns" },
    { key = "cooldowns_2", configKey = "util_cooldowns" },
    { key = "cooldowns_3", configKey = "cooldowns_3" },
    { key = "cooldowns_4", configKey = "cooldowns_4" },
    { key = "cooldowns_5", configKey = "cooldowns_5" },
    { key = "cooldowns_6", configKey = "cooldowns_6" },
}

local function ForEachCooldownFrame(callback)
    if not TUI or not TUI.cooldown_frames then
        return
    end

    for key, frame in pairs(TUI.cooldown_frames) do
        if frame then
            callback(key, frame)
        end
    end
end

local function ApplyCooldownLayout(key, frame, config)
    if not frame or not config then
        return
    end

    local anchorFrame = TUI_Layout:GetAnchorFrame(config.anchor_frame)
    frame:ClearAllPoints()
    frame:SetPoint(config.anchor, anchorFrame, config.anchor_to, config.pos_x, config.pos_y)

    if config.first_row_limit then
        frame.firstRowLimit = config.first_row_limit
    end
    if config.first_row_size_x then
        frame.firstRowSizeX = config.first_row_size_x
    end
    if config.first_row_size_y then
        frame.firstRowSizeY = config.first_row_size_y
    end
    if config.row_limit then
        frame.rowLimit = config.row_limit
    end
    if config.row_size_x then
        frame.rowSizeX = config.row_size_x
    end
    if config.row_size_y then
        frame.rowSizeY = config.row_size_y
    end
    if config.spacing_x then
        frame.spacingX = config.spacing_x
    end
    if config.spacing_y then
        frame.spacingY = config.spacing_y
    end
    if config.grow_direction_up ~= nil then
        frame.growDirectionUp = config.grow_direction_up
    end

    frame.alwaysUpdateLayout = true
    frame:Layout()
    frame:SetShown(true)
end

function TUI_Layout:ClearAnchors()
    ForEachCooldownFrame(function(_, frame)
        frame:ClearAllPoints()
    end)

    if TUI.aura_buffs then
        TUI.aura_buffs:ClearAllPoints()
    end
    if TUI.bars then
        TUI.bars:ClearAllPoints()
    end
    if TUI.cast_bar and TUI.cast_bar.frame then
        TUI.cast_bar.frame:ClearAllPoints()
    end
    if TUI.resource_bar and TUI.resource_bar.frame then
        TUI.resource_bar.frame:ClearAllPoints()
    end
    if TUI.secondary_resource_bar and TUI.secondary_resource_bar.frame then
        TUI.secondary_resource_bar.frame:ClearAllPoints()
    end
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
    elseif TUI.cooldown_frames_by_name and TUI.cooldown_frames_by_name[anchorFrameName] then
        return TUI.cooldown_frames_by_name[anchorFrameName]
    else
        -- Fallback to UIParent if anchor frame is not found
        return _G[anchorFrameName] or UIParent
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
        ForEachCooldownFrame(function(_, frame)
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
        end)
        local auraIndicator = TUI.aura_buffs and rawget(TUI.aura_buffs, "tuiEditIndicator")
        if auraIndicator then
            local visualWidth, visualHeight = TUI_Layout:GetFrameVisualBounds(TUI.aura_buffs)
            auraIndicator:SetSize(visualWidth, visualHeight)

            local auraBorder = rawget(TUI.aura_buffs, "tuiEditBorder")
            if auraBorder then
                auraBorder.top:SetSize(visualWidth + 4, 2)
                auraBorder.bottom:SetSize(visualWidth + 4, 2)
                auraBorder.left:SetSize(2, visualHeight + 4)
                auraBorder.right:SetSize(2, visualHeight + 4)
            end
        end
        local barsIndicator = TUI.bars and rawget(TUI.bars, "tuiEditIndicator")
        if barsIndicator then
            local visualWidth, visualHeight = TUI_Layout:GetFrameVisualBounds(TUI.bars)
            barsIndicator:SetSize(visualWidth, visualHeight)

            local barsBorder = rawget(TUI.bars, "tuiEditBorder")
            if barsBorder then
                barsBorder.top:SetSize(visualWidth + 4, 2)
                barsBorder.bottom:SetSize(visualWidth + 4, 2)
                barsBorder.left:SetSize(2, visualHeight + 4)
                barsBorder.right:SetSize(2, visualHeight + 4)
            end
        end
        local castIndicator = TUI.cast_bar and rawget(TUI.cast_bar, "tuiEditIndicator")
        if castIndicator then
            castIndicator:SetAllPoints()
        end
        local resourceIndicator = TUI.resource_bar and rawget(TUI.resource_bar, "tuiEditIndicator")
        if resourceIndicator then
            resourceIndicator:SetAllPoints()
        end
        local secondaryIndicator = TUI.secondary_resource_bar and rawget(TUI.secondary_resource_bar, "tuiEditIndicator")
        if secondaryIndicator then
            secondaryIndicator:SetAllPoints()
        end
        
        -- Refresh anchor indicators for all frames
        local framesToRefresh = {}
        ForEachCooldownFrame(function(_, frame)
            table.insert(framesToRefresh, frame)
        end)
        table.insert(framesToRefresh, TUI.aura_buffs)
        table.insert(framesToRefresh, TUI.bars)
        table.insert(framesToRefresh, TUI.cast_bar)
        table.insert(framesToRefresh, TUI.resource_bar)
        table.insert(framesToRefresh, TUI.secondary_resource_bar)
        
        for _, frame in ipairs(framesToRefresh) do
            if frame then
                local anchorIndicator = rawget(frame, "tuiAnchorIndicator")
                if anchorIndicator then
                    TUI_EditMode:UpdateAnchorIndicator(frame)
                end
            end
        end
        
        -- Clean up the refresh frame
        self:SetScript("OnUpdate", nil)
    end)
end

function TUI_Layout:UpdateLayout()
    TUI_Layout:ClearAnchors()

    local profile = TUI.db.profile

    if profile and TUI.cooldown_frames then
        for _, entry in ipairs(COOLDOWN_LAYOUT_CONFIGS) do
            local frame = TUI.cooldown_frames[entry.key]
            local config = profile[entry.configKey]
            if not config and TUI.defaults and TUI.defaults.profile then
                local defaultConfig = TUI.defaults.profile[entry.configKey]
                if defaultConfig then
                    config = CopyTable(defaultConfig)
                    profile[entry.configKey] = config
                end
            end
            if frame and config then
                ApplyCooldownLayout(entry.key, frame, config)
            end
        end
    end

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
        return TUI.cooldown_frames and TUI.cooldown_frames.cooldowns_1
    elseif configKey == "util_cooldowns" then
        return TUI.cooldown_frames and TUI.cooldown_frames.cooldowns_2
    elseif configKey == "cooldowns_3" then
        return TUI.cooldown_frames and TUI.cooldown_frames.cooldowns_3
    elseif configKey == "cooldowns_4" then
        return TUI.cooldown_frames and TUI.cooldown_frames.cooldowns_4
    elseif configKey == "cooldowns_5" then
        return TUI.cooldown_frames and TUI.cooldown_frames.cooldowns_5
    elseif configKey == "cooldowns_6" then
        return TUI.cooldown_frames and TUI.cooldown_frames.cooldowns_6
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
    for _, entry in ipairs(COOLDOWN_LAYOUT_CONFIGS) do
        local frame = TUI.cooldown_frames and TUI.cooldown_frames[entry.key]
        if frame then
            TUI_Layout:ApplyDatabaseAnchorSettings(frame, entry.configKey)
        end
    end
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

