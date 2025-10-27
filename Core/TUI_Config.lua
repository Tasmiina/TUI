-- TUI Configuration Module
-- Handles all configuration options and UI generation

---@class TUI_Config
TUI_Config = {}

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")


local anchorPoints = { "TOP", "BOTTOM", "LEFT", "RIGHT", "CENTER" }

local function SetAndUpdate(func)
    return function(_, val)
        func(val)
        if TUI.UpdateLayout then
            TUI:UpdateLayout()
        end
    end
end

local function CreateFrameOptions(name, data)
    local group = {
        type = "group",
        name = name,
        args = {
            header = { type = "header", name = name, order = 0 },

            pos_x = {
                type = "range", name = "X Position", order = 1,
                min = -1000, max = 1000, step = 1,
                get = function() return TUI.db.profile[data].pos_x end,
                set = SetAndUpdate(function(val) TUI.db.profile[data].pos_x = val end),
            },
            pos_y = {
                type = "range", name = "Y Position", order = 2,
                min = -1000, max = 1000, step = 1,
                get = function() return TUI.db.profile[data].pos_y end,
                set = SetAndUpdate(function(val) TUI.db.profile[data].pos_y = val end),
            },
            anchor_frame = {
                type = "select", name = "Anchor Frame", order = 3,
                values = function()
                    local values = {
                        ["UIParent"] = "Screen",
                    }
                    
                    -- Add all TUI frames as options
                    if TUI.main_cooldowns then
                        values["TUI_MainCooldowns"] = "Main Cooldowns"
                    end
                    if TUI.util_cooldowns then
                        values["TUI_UtilCooldowns"] = "Utility Cooldowns"
                    end
                    if TUI.aura_buffs then
                        values["TUI_AuraBuffs"] = "Aura Buffs"
                    end
                    if TUI.bars then
                        values["TUI_Bars"] = "Bar Buffs"
                    end
                    if TUI.cast_bar and TUI.cast_bar.frame then
                        values["TUI_Castbar"] = "Cast Bar"
                    end
                    if TUI.resource_bar and TUI.resource_bar.frame then
                        values["TUI_ResourceBar"] = "Resource Bar"
                    end
                    if TUI.secondary_resource_bar and TUI.secondary_resource_bar.frame then
                        values["TUI_SecondaryResourceBar"] = "Secondary Resource Bar"
                    end
                    
                    return values
                end,
                get = function()
                    local val = TUI.db.profile[data].anchor_frame
                    local values = {
                        ["UIParent"] = "UIParent",
                        ["TUI_MainCooldowns"] = "Main Cooldowns",
                        ["TUI_UtilCooldowns"] = "Utility Cooldowns",
                        ["TUI_AuraBuffs"] = "Aura Buffs",
                        ["TUI_Bars"] = "Bar Buffs",
                        ["TUI_Castbar"] = "Cast Bar",
                        ["TUI_ResourceBar"] = "Resource Bar",
                        ["TUI_SecondaryResourceBar"] = "Secondary Resource Bar",
                    }
                    
                    for key, displayName in pairs(values) do
                        if key == val then
                            return key
                        end
                    end
                    return "UIParent" -- Default fallback
                end,
                set = function(_, key)
                    local oldAnchorFrame = TUI.db.profile[data].anchor_frame
                    TUI.db.profile[data].anchor_frame = key
                    
                    -- Only convert position if this is a user-initiated change (not during initialization)
                    if oldAnchorFrame ~= key and oldAnchorFrame ~= nil and not TUI.isInitializing then
                        TUI:ConvertAnchorPosition(data, oldAnchorFrame, key)
                    else
                        -- Just update layout normally if no conversion needed
                        if TUI.UpdateLayout then
                            TUI:UpdateLayout()
                        end
                    end
                    
                    -- Update anchor indicator if in edit mode
                    if TUI.editModeEnabled then
                        local frame = TUI:GetFrameForConfigKey(data)
                        if frame and frame.tuiAnchorIndicator then
                            TUI:UpdateAnchorIndicator(frame)
                        end
                    end
                end,
            },
            anchor_to = {
                type = "select", name = "Anchor To", order = 4,
                values = anchorPoints,
                get = function()
                    local val = TUI.db.profile[data].anchor_to
                    for i, v in ipairs(anchorPoints) do if v == val then return i end end
                end,
                set = SetAndUpdate(function(key)
                    TUI.db.profile[data].anchor_to = anchorPoints[key]
                    
                    -- Update anchor indicator if in edit mode
                    if TUI.editModeEnabled then
                        local frame = TUI:GetFrameForConfigKey(data)
                        if frame and frame.tuiAnchorIndicator then
                            TUI:UpdateAnchorIndicator(frame)
                        end
                    end
                end),
            },
            anchor = {
                type = "select", name = "Anchor", order = 5,
                values = anchorPoints,
                get = function()
                    local val = TUI.db.profile[data].anchor
                    for i, v in ipairs(anchorPoints) do if v == val then return i end end
                end,
                set = SetAndUpdate(function(key)
                    TUI.db.profile[data].anchor = anchorPoints[key]
                    
                    -- Update anchor indicator if in edit mode
                    if TUI.editModeEnabled then
                        local frame = TUI:GetFrameForConfigKey(data)
                        if frame and frame.tuiAnchorIndicator then
                            TUI:UpdateAnchorIndicator(frame)
                        end
                    end
                end),
            },
        }
    }

    -- Add extra sliders dynamically if fields exist
    local extra = TUI.db.profile[data]
    if extra.width then
        group.args.width = {
            type = "range", name = "Width", order = 6,
            min = 1, max = 1000, step = 1,
            get = function() return TUI.db.profile[data].width end,
            set = SetAndUpdate(function(val) TUI.db.profile[data].width = val end),
        }
    end
    if extra.height then
        group.args.height = {
            type = "range", name = "Height", order = 7,
            min = 1, max = 1000, step = 1,
            get = function() return TUI.db.profile[data].height end,
            set = SetAndUpdate(function(val) TUI.db.profile[data].height = val end),
        }
    end
    if extra.first_row_limit then
        group.args.first_row_limit = {
            type = "range", name = "First Row Limit", order = 8,
            min = 1, max = 20, step = 1,
            get = function() return TUI.db.profile[data].first_row_limit end,
            set = SetAndUpdate(function(val) TUI.db.profile[data].first_row_limit = val end),
        }
        group.args.grow_direction_up = {
            type = "toggle", name = "Grow Direction Up", order = 9,
            get = function() return TUI.db.profile[data].grow_direction_up end,
            set = SetAndUpdate(function(val) TUI.db.profile[data].grow_direction_up = val end),
        }
        group.args.first_row_size_x = {
            type = "range", name="First Row Size X", order = 10,
            min = 1, max = 128, step = 1,
            get = function() return TUI.db.profile[data].first_row_size_x end,
            set = SetAndUpdate(function(val) TUI.db.profile[data].first_row_size_x = val end),
        }
        group.args.first_row_size_y = {
            type = "range", name="First Row Size Y", order = 11,
            min = 1, max = 128, step = 1,
            get = function() return TUI.db.profile[data].first_row_size_y end,
            set = SetAndUpdate(function(val) TUI.db.profile[data].first_row_size_y = val end),
        }
        group.args.row_limit = {
            type = "range", name = "Row Limit", order = 12,
            min = 1, max = 20, step = 1,
            get = function() return TUI.db.profile[data].row_limit end,
            set = SetAndUpdate(function(val) TUI.db.profile[data].row_limit = val end),
        }
        group.args.row_size_x = {
            type = "range", name="Row Size X", order = 13,
            min = 1, max = 128, step = 1,
            get = function() return TUI.db.profile[data].row_size_x end,
            set = SetAndUpdate(function(val) TUI.db.profile[data].row_size_x = val end),
        }
        group.args.row_size_y = {
            type = "range", name="Row Size Y", order = 14,
            min = 1, max = 128, step = 1,
            get = function() return TUI.db.profile[data].row_size_y end,
            set = SetAndUpdate(function(val) TUI.db.profile[data].row_size_y = val end),
        }
        group.args.spacing_x = {
            type = "range", name="Spacing X", order = 13,
            min = -128, max = 128, step = 1,
            get = function() return TUI.db.profile[data].spacing_x end,
            set = SetAndUpdate(function(val) TUI.db.profile[data].spacing_x = val end),
        }
        group.args.spacing_y = {
            type = "range", name="Spacing Y", order = 14,
            min = -128, max = 128, step = 1,
            get = function() return TUI.db.profile[data].spacing_y end,
            set = SetAndUpdate(function(val) TUI.db.profile[data].spacing_y = val end),
        }
    end

    if extra.child_width then
        group.args.child_width = {
            type = "range", name="Child Height", order = 15,
            min = 1, max = 128, step = 1,
            get = function() return TUI.db.profile[data].child_width end,
            set = SetAndUpdate(function(val) TUI.db.profile[data].child_width = val end),
        }
        group.args.child_height = {
            type = "range", name="Child Height", order = 16,
            min = 1, max = 128, step = 1,
            get = function() return TUI.db.profile[data].child_height end,
            set = SetAndUpdate(function(val) TUI.db.profile[data].child_height = val end),
        }
        group.args.child_spacing = {
            type = "range", name="Spacing", order = 17,
            min = -128, max = 128, step = 1,
            get = function() return TUI.db.profile[data].child_spacing end,
            set = SetAndUpdate(function(val) TUI.db.profile[data].child_spacing = val end),
        }
    end
    return group
end

function TUI_Config:AddOptions(addonName)
    local options = {
        type = "group",
        name = addonName,
        args = {
            edit_mode = {
                type = "group",
                name = "Edit Mode",
                order = 1,
                args = {
                    header = { type = "header", name = "Edit Mode Settings", order = 0 },
                    enabled = {
                        type = "toggle",
                        name = "Enable Edit Mode",
                        order = 1,
                        get = function() return TUI.editModeEnabled end,
                        set = function(val) 
                            TUI.editModeEnabled = val
                            if val then
                                TUI:EnterEditMode()
                            else
                                TUI:ExitEditMode()
                            end
                        end,
                    },
                    show_grid = {
                        type = "toggle",
                        name = "Show Grid",
                        order = 2,
                        get = function() return TUI.db.profile.edit_mode.show_grid end,
                        set = function(val) 
                            TUI.db.profile.edit_mode.show_grid = val
                            if TUI.editModeEnabled then
                                if val then
                                    TUI:ShowGrid()
                                else
                                    TUI:HideGrid()
                                end
                            end
                        end,
                    },
                    grid_size = {
                        type = "range",
                        name = "Grid Size",
                        order = 3,
                        min = 10,
                        max = 50,
                        step = 5,
                        get = function() return TUI.db.profile.edit_mode.grid_size end,
                        set = function(val) 
                            TUI.db.profile.edit_mode.grid_size = val
                            if TUI.editModeEnabled and TUI.db.profile.edit_mode.show_grid then
                                TUI:HideGrid()
                                TUI:ShowGrid()
                            end
                        end,
                    },
                    instructions = {
                        type = "description",
                        name = "Use |cffffffff/tui edit|r to toggle edit mode, or use the toggle above. In edit mode, you can drag UI elements to reposition them.",
                        order = 4,
                    },
                    reset_positions = {
                        type = "execute",
                        name = "Reset All Positions",
                        order = 5,
                        func = function()
                            TUI:ResetPositions()
                        end,
                    },
                }
            },
            main_cooldowns = CreateFrameOptions("Main Cooldowns", "main_cooldowns"),
            util_cooldowns = CreateFrameOptions("Utility Cooldowns", "util_cooldowns"),
            bar_buffs = CreateFrameOptions("Bar Buffs", "bar_buffs"),
            aura_buffs = CreateFrameOptions("Aura Buffs", "aura_buffs"),
            cast_bar = CreateFrameOptions("Cast Bar", "cast_bar"),
            resource_bar = CreateFrameOptions("Resource Bar", "resource_bar"),
            secondary_resource_bar = CreateFrameOptions("Secondary Resource Bar", "secondary_resource_bar"),
        }
    }

    local profiles = AceDBOptions:GetOptionsTable(TUI.db)
    options.args.profiles = profiles
    options.args.profiles.order = 1000
    options.args.profiles.name = "Profiles"

    options.args.profiles.args.importexport = {
        type = "group",
        name = "Import / Export",
        inline = true,
        order = 2000,
        args = {
            export_btn = {
                type = "execute",
                name = "Export Current Profile",
                order = 1,
                func = function()
                    TUI_Profile:ShowImportExport("export")
                end,
            },
            import_btn = {
                type = "execute",
                name = "Import New Profile",
                order = 2,
                func = function()
                    TUI_Profile:ShowImportExport("import")
                end,
            },
            desc = {
                type = "description",
                name = "Export your current profile as a text string to share, or import a shared profile here.",
                order = 3,
            }
        }
    }

    AceConfig:RegisterOptionsTable(addonName, options)
    AceConfigDialog:AddToBlizOptions(addonName, addonName)
end

function TUI_Config:OpenFrameSettings(elementName, configKey)
    if not configKey then
        print("|cff88ff88TUI:|r No configuration available for this element.")
        return
    end
    
    local frameOptions = {
        type = "group",
        name = elementName or "Frame Settings",
        args = {}
    }
    
    -- Get the frame configuration options
    local frameConfig = CreateFrameOptions(elementName or "Frame", configKey)
    frameOptions.args = frameConfig.args
    
    -- Register the temporary options
    local tempKey = "TUI_FrameSettings_" .. configKey
    AceConfigRegistry:RegisterOptionsTable(tempKey, frameOptions)
    
    -- Open the dialog
    AceConfigDialog:Open(tempKey)
end

