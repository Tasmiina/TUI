local addonName, Addon = ...

TUI = LibStub("AceAddon-3.0"):NewAddon("TUI", "AceConsole-3.0")

local defaults = {
    profile = {
        edit_mode = {
            show_grid = true,
            grid_size = 20
        },
        main_cooldowns = {
            pos_x = 0,
            pos_y = -1,
            first_row_limit = 10,
            first_row_size_x = 38,
            first_row_size_y = 32,
            row_limit = 10,
            row_size_x = 38,
            row_size_y = 32,
            spacing_x = 2,
            spacing_y = 2,
            grow_direction_up = false,
            anchor_frame = "TUI_ResourceBar",
            anchor_to = "BOTTOM",
            anchor = "TOP"
        },
        util_cooldowns = {
            pos_x = 0,
            pos_y = -111,
            first_row_limit = 6,
            first_row_size_x = 40,
            first_row_size_y = 40,
            spacing_x = 3,
            spacing_y = 2,
            row_limit = 6,
            row_size_x = 40,
            row_size_y = 40,
            grow_direction_up = false,
            anchor_frame = "TUI_ResourceBar",
            anchor_to = "BOTTOM",
            anchor = "TOP"
        },
        bar_buffs = {
            pos_x = 0,
            pos_y = -30,
            anchor_frame = "TUI_UtilCooldowns",
            anchor_to = "BOTTOM",
            anchor = "TOP",
            child_width = 220,
            child_height = 20,
            child_spacing = 10
        },
        aura_buffs = {
            pos_x = 0,
            pos_y = 10,
            anchor_frame = "TUI_Castbar",
            anchor_to = "TOP",
            anchor = "BOTTOM",
            child_width = 40,
            child_height = 40,
            child_spacing = 4
        },
        cast_bar = {
            anchor_frame = "TUI_SecondaryResourceBar",
            anchor_to = "TOP",
            anchor = "BOTTOM",
            pos_x = 0,
            pos_y = 0,
            width = 400,
            height = 20
        },
        resource_bar = {
            anchor_frame = "UIParent",
            anchor_to = "CENTER",
            anchor = "BOTTOM",
            pos_x = 0,
            pos_y = -210,
            width = 400,
            height = 20
        },
        secondary_resource_bar = {
            anchor_frame = "TUI_ResourceBar",
            anchor_to = "TOP",
            anchor = "BOTTOM",
            pos_x = 0,
            pos_y = 0,
            width = 400,
            height = 15
        }
    }
}

function TUI:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("TUI_DB", defaults)
    
    -- Store defaults for reset functionality
    self.defaults = defaults
    
    -- Initialize edit mode state (not persisted in database)
    self.editModeEnabled = false
    
    self.isInitializing = true
    
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
    
    self.main_cooldowns = _G["TUI_MainCooldowns"]
    self.util_cooldowns = _G["TUI_UtilCooldowns"]
    self.aura_buffs = _G["TUI_AuraBuffs"]
    self.bars = _G["TUI_Bars"]
    
    self.cast_bar = TUICastBar:new("TUI_Castbar", UIParent)
    self.resource_bar = TUIResourceBar:new("TUI_ResourceBar", UIParent)
    self.secondary_resource_bar = TUISecondaryResourceBar:new("TUI_SecondaryResourceBar", UIParent)
    
    TUI_Layout:DisableBlizz()

    TUI_Layout:UpdateLayout()

    TUI_Config:AddOptions(addonName)

    self:RegisterChatCommand("tui", "SlashCommand")
    
    -- Clear initialization flag
    self.isInitializing = false
end

function TUI:SlashCommand(msg)
    if msg == "edit" then
        TUI_EditMode:ToggleEditMode()
    elseif msg == "reset" then
        TUI_Layout:ResetPositions()
    elseif msg == "help" then
        print("|cff88ff88TUI Commands:|r")
        print("|cffffffff/tui edit|r - Toggle edit mode")
        print("|cffffffff/tui reset|r - Reset all element positions")
        print("|cffffffff/tui help|r - Show this help")
    end
end

function TUI:RefreshConfig()
    TUI_Layout:UpdateLayout()
end

-- Delegate methods to appropriate modules
function TUI:UpdateLayout()
    TUI_Layout:UpdateLayout()
end

function TUI:ClearAnchors()
    TUI_Layout:ClearAnchors()
end

function TUI:DisableBlizz()
    TUI_Layout:DisableBlizz()
end

function TUI:GetAnchorFrame(anchorFrameName)
    return TUI_Layout:GetAnchorFrame(anchorFrameName)
end

function TUI:GetFrameVisualBounds(frame)
    return TUI_Layout:GetFrameVisualBounds(frame)
end

function TUI:RefreshEditModeIndicators()
    TUI_Layout:RefreshEditModeIndicators()
end

function TUI:ConvertAnchorPosition(configKey, oldAnchorFrame, newAnchorFrame)
    TUI_Layout:ConvertAnchorPosition(configKey, oldAnchorFrame, newAnchorFrame)
end

function TUI:GetFrameForConfigKey(configKey)
    return TUI_Layout:GetFrameForConfigKey(configKey)
end

function TUI:ApplyDatabaseAnchorSettingsToAllFrames()
    TUI_Layout:ApplyDatabaseAnchorSettingsToAllFrames()
end

function TUI:ApplyDatabaseAnchorSettings(frame, configKey)
    TUI_Layout:ApplyDatabaseAnchorSettings(frame, configKey)
end

function TUI:ResetPositions()
    TUI_Layout:ResetPositions()
end

-- Edit Mode delegation
function TUI:ToggleEditMode()
    TUI_EditMode:ToggleEditMode()
end

function TUI:EnterEditMode()
    TUI_EditMode:EnterEditMode()
end

function TUI:ExitEditMode()
    TUI_EditMode:ExitEditMode()
end

function TUI:ShowGrid()
    TUI_EditMode:ShowGrid()
end

function TUI:HideGrid()
    TUI_EditMode:HideGrid()
end

function TUI:EnableElementDragging()
    TUI_EditMode:EnableElementDragging()
end

function TUI:DisableElementDragging()
    TUI_EditMode:DisableElementDragging()
end

function TUI:EnableDraggingForElement(element, configKey, elementName)
    TUI_EditMode:EnableDraggingForElement(element, configKey, elementName)
end

function TUI:DisableDraggingForElement(element)
    TUI_EditMode:DisableDraggingForElement(element)
end

function TUI:AddAnchorIndicator(frame, elementName)
    TUI_EditMode:AddAnchorIndicator(frame, elementName)
end

function TUI:UpdateAnchorIndicator(frame)
    TUI_EditMode:UpdateAnchorIndicator(frame)
end

function TUI:RemoveAnchorIndicator(frame)
    TUI_EditMode:RemoveAnchorIndicator(frame)
end

function TUI:AddEditModeIndicator(frame, elementName)
    TUI_EditMode:AddEditModeIndicator(frame, elementName)
end

function TUI:RemoveEditModeIndicator(frame)
    TUI_EditMode:RemoveEditModeIndicator(frame)
end

function TUI:GetConfigKeyForFrame(frame)
    return TUI_EditMode:GetConfigKeyForFrame(frame)
end

function TUI:OpenFrameSettings(elementName, configKey)
    TUI_Config:OpenFrameSettings(elementName, configKey)
end

function TUI:UpdateFramePositionDuringDrag(frame)
    TUI_EditMode:UpdateFramePositionDuringDrag(frame)
end

function TUI:UpdateAnchorDisplay(frame)
    TUI_EditMode:UpdateAnchorDisplay(frame)
end

function TUI:SaveElementPosition(frame, configKey)
    TUI_EditMode:SaveElementPosition(frame, configKey)
end