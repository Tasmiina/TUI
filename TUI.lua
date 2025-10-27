local addonName, Addon = ...

TUI = LibStub("AceAddon-3.0"):NewAddon("TUI", "AceConsole-3.0")

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

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

local function ExportProfile(profileName)
    local profile = TUI.db.profiles[profileName]
    if not profile then
        return nil, "Profile not found."
    end

    local exportData = {
        meta = {
            addon = "TUI",
            version = 0,
            exported = date("%Y-%m-%d %H:%M:%S"),
            profileName = profileName,
        },
        profile = profile,
    }

    local serialized = LibSerialize:Serialize(exportData)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForPrint(compressed)

    -- Add a recognizable prefix for safety
    local exportString = "TUI_EXPORT:" .. encoded
    return exportString
end

local function ImportProfileString(data)
    if data:sub(1, 11) == "TUI_EXPORT:" then
        data = data:sub(12)
    end

    local decoded = LibDeflate:DecodeForPrint(data)
    if not decoded then
        return nil, "Decoding failed (bad characters or format)."
    end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then
        return nil, "Decompression failed."
    end

    local success, exportData = LibSerialize:Deserialize(decompressed)
    if not success or type(exportData) ~= "table" or not exportData.profile then
        return nil, "Deserialization failed or invalid structure."
    end

    local profileName = exportData.meta and exportData.meta.profileName or ("Imported_" .. date("%H%M%S"))
    return exportData.profile, profileName
end

local function RefreshProfileOptions()
    if AceConfigRegistry and AceConfigRegistry.NotifyChange then
        AceConfigRegistry:NotifyChange(addonName)
    end

    -- Force a UI refresh (works for both standalone and Blizzard panel)
    if AceConfigDialog and AceConfigDialog.OpenFrames then
        local frame = AceConfigDialog.OpenFrames[addonName]
        if frame then
            AceConfigDialog:Open(addonName)
        end
    end
end

local function ShowProfileImportExport(mode)
    local frame = AceGUI:Create("Frame")
    frame:SetTitle(mode == "export" and "Export Profile" or "Import Profile")
    frame:SetStatusText("")
    frame:SetLayout("List")
    frame:SetWidth(500)
    frame:SetHeight(400)
    frame:EnableResize(true)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    frame:AddChild(scroll)

    local editBox = AceGUI:Create("MultiLineEditBox")
    editBox:SetFullWidth(true)
    editBox:SetLabel(mode == "export" and "Profile String" or "Paste Profile String Here")
    editBox:SetNumLines(15)
    editBox:DisableButton(true)
    scroll:AddChild(editBox)

    if mode == "export" then
        local currentProfile = TUI.db:GetCurrentProfile()
        local exportString, err = ExportProfile(currentProfile)
        if exportString then
            editBox:SetText(exportString)
            editBox:HighlightText()
        else
            editBox:SetText("Error exporting: " .. (err or "Unknown"))
        end
    else
        -- Spacer
        local spacer = AceGUI:Create("Label")
        spacer:SetText(" ")
        spacer:SetFullWidth(true)
        scroll:AddChild(spacer)

        -- Import button
        local importBtn = AceGUI:Create("Button")
        importBtn:SetText("Import Profile")
        importBtn:SetFullWidth(true)
        importBtn:SetCallback("OnClick", function()
            local text = editBox:GetText()
            if not text or text == "" then
                print("|cffff5555TUI:|r Paste a profile string first.")
                return
            end

            local profileData, profileNameOrErr = ImportProfileString(text)
            if not profileData then
                print("|cffff5555TUI:|r " .. profileNameOrErr)
                return
            end

            -- Ensure unique name (in case the same profile name exists)
            local baseName = profileNameOrErr or "Imported_" .. date("%H%M%S")
            local newName = baseName
            local counter = 1
            while TUI.db.profiles[newName] do
                counter = counter + 1
                newName = baseName .. "_" .. counter
            end

            TUI.db:SetProfile(newName)
            for k, v in pairs(profileData) do
                TUI.db.profile[k] = v
            end

            print(string.format("|cff88ff88TUI:|r Imported profile '%s' successfully.", newName))
            if TUI.UpdateLayout then TUI:UpdateLayout() end
            RefreshProfileOptions()
            frame:Hide()
        end)
        scroll:AddChild(importBtn)
    end

    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
    end)
end

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

function TUI:ClearAnchors()
    self.main_cooldowns:ClearAllPoints()
    self.util_cooldowns:ClearAllPoints()
    self.aura_buffs:ClearAllPoints()
    self.bars:ClearAllPoints()
    self.cast_bar.frame:ClearAllPoints()
    self.resource_bar.frame:ClearAllPoints()
    self.secondary_resource_bar.frame:ClearAllPoints()
end

function TUI:DisableBlizz()
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

function TUI:GetAnchorFrame(anchorFrameName)
    -- Convert anchor frame name to actual frame object
    if anchorFrameName == "UIParent" then
        return UIParent
    elseif anchorFrameName == "TUI_MainCooldowns" then
        return self.main_cooldowns
    elseif anchorFrameName == "TUI_UtilCooldowns" then
        return self.util_cooldowns
    elseif anchorFrameName == "TUI_AuraBuffs" then
        return self.aura_buffs
    elseif anchorFrameName == "TUI_Bars" then
        return self.bars
    elseif anchorFrameName == "TUI_Castbar" then
        return self.cast_bar.frame
    elseif anchorFrameName == "TUI_ResourceBar" then
        return self.resource_bar.frame
    elseif anchorFrameName == "TUI_SecondaryResourceBar" then
        return self.secondary_resource_bar.frame
    else
        -- Fallback to UIParent if anchor frame is not found
        return UIParent
    end
end

function TUI:GetFrameVisualBounds(frame)
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

function TUI:RefreshEditModeIndicators()
    if not self.editModeEnabled then return end
    
    -- Use a delayed refresh to ensure frames have finished updating their size
    local refreshFrame = CreateFrame("Frame")
    local attempts = 0
    refreshFrame:SetScript("OnUpdate", function(self)
        attempts = attempts + 1
        
        -- Refresh edit mode indicators for all frames to match their current size
        if TUI.main_cooldowns and TUI.main_cooldowns.tuiEditIndicator then
            local visualWidth, visualHeight = TUI:GetFrameVisualBounds(TUI.main_cooldowns)
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
            local visualWidth, visualHeight = TUI:GetFrameVisualBounds(TUI.util_cooldowns)
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
            local visualWidth, visualHeight = TUI:GetFrameVisualBounds(TUI.aura_buffs)
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
            local visualWidth, visualHeight = TUI:GetFrameVisualBounds(TUI.bars)
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
                TUI:UpdateAnchorIndicator(frame)
            end
        end
        
        -- Clean up the refresh frame
        self:SetScript("OnUpdate", nil)
    end)
end

function TUI:UpdateLayout()

    self:ClearAnchors()

    -- Update MainCooldowns according to settings
    local mainCooldownsAnchor = self:GetAnchorFrame(TUI.db.profile.main_cooldowns.anchor_frame)
    self.main_cooldowns:SetPoint(TUI.db.profile.main_cooldowns.anchor, mainCooldownsAnchor, TUI.db.profile.main_cooldowns.anchor_to, TUI.db.profile.main_cooldowns.pos_x, TUI.db.profile.main_cooldowns.pos_y)

    self.main_cooldowns.firstRowLimit = TUI.db.profile.main_cooldowns.first_row_limit
    self.main_cooldowns.firstRowSizeX = TUI.db.profile.main_cooldowns.first_row_size_x
    self.main_cooldowns.firstRowSizeY = TUI.db.profile.main_cooldowns.first_row_size_y
    
    self.main_cooldowns.rowLimit = TUI.db.profile.main_cooldowns.row_limit
    self.main_cooldowns.rowSizeX = TUI.db.profile.main_cooldowns.row_size_x
    self.main_cooldowns.rowSizeY = TUI.db.profile.main_cooldowns.row_size_y

    self.main_cooldowns.spacingX = TUI.db.profile.main_cooldowns.spacing_x
    self.main_cooldowns.spacingY = TUI.db.profile.main_cooldowns.spacing_y
    self.main_cooldowns.growDirectionUp = TUI.db.profile.main_cooldowns.grow_direction_up

    self.main_cooldowns.alwaysUpdateLayout = true

    self.main_cooldowns:Layout()
    self.main_cooldowns:Show()
    
    -- Force the frame to be visible and ensure it stays visible
    self.main_cooldowns:SetShown(true)

    -- Update UtilCooldowns according to settings
    local utilCooldownsAnchor = self:GetAnchorFrame(TUI.db.profile.util_cooldowns.anchor_frame)
    self.util_cooldowns:SetPoint(TUI.db.profile.util_cooldowns.anchor, utilCooldownsAnchor, TUI.db.profile.util_cooldowns.anchor_to, TUI.db.profile.util_cooldowns.pos_x, TUI.db.profile.util_cooldowns.pos_y)

    self.util_cooldowns.firstRowLimit = TUI.db.profile.util_cooldowns.first_row_limit
    self.util_cooldowns.firstRowSizeX = TUI.db.profile.util_cooldowns.first_row_size_x
    self.util_cooldowns.firstRowSizeY = TUI.db.profile.util_cooldowns.first_row_size_y
    
    self.util_cooldowns.rowLimit = TUI.db.profile.util_cooldowns.row_limit
    self.util_cooldowns.rowSizeX = TUI.db.profile.util_cooldowns.row_size_x
    self.util_cooldowns.rowSizeY = TUI.db.profile.util_cooldowns.row_size_y

    self.util_cooldowns.spacingX = TUI.db.profile.util_cooldowns.spacing_x
    self.util_cooldowns.spacingY = TUI.db.profile.util_cooldowns.spacing_y
    self.util_cooldowns.growDirectionUp = TUI.db.profile.util_cooldowns.grow_direction_up

    self.util_cooldowns.alwaysUpdateLayout = true

    self.util_cooldowns:Layout()
    self.util_cooldowns:Show()
    
    -- Force the frame to be visible and ensure it stays visible
    self.util_cooldowns:SetShown(true)

    -- Update AuraBuffs according to settings
    local auraBuffsAnchor = self:GetAnchorFrame(TUI.db.profile.aura_buffs.anchor_frame)
    self.aura_buffs:SetPoint(TUI.db.profile.aura_buffs.anchor, auraBuffsAnchor, TUI.db.profile.aura_buffs.anchor_to, TUI.db.profile.aura_buffs.pos_x, TUI.db.profile.aura_buffs.pos_y)

    self.aura_buffs.childSizeX = TUI.db.profile.aura_buffs.child_width
    self.aura_buffs.childSizeY = TUI.db.profile.aura_buffs.child_height
    self.aura_buffs.spacing = TUI.db.profile.aura_buffs.child_spacing

    self.aura_buffs:Layout()
    self.aura_buffs:Show()
    
    -- Force the frame to be visible and ensure it stays visible
    self.aura_buffs:SetShown(true)

    -- Update Bars according to settings
    local barsAnchor = self:GetAnchorFrame(TUI.db.profile.bar_buffs.anchor_frame)
    self.bars:SetPoint(TUI.db.profile.bar_buffs.anchor, barsAnchor, TUI.db.profile.bar_buffs.anchor_to, TUI.db.profile.bar_buffs.pos_x, TUI.db.profile.bar_buffs.pos_y)

    self.bars.childSizeX = TUI.db.profile.bar_buffs.child_width
    self.bars.childSizeY = TUI.db.profile.bar_buffs.child_height
    self.bars.spacing = TUI.db.profile.bar_buffs.child_spacing

    self.bars:Layout()
    self.bars:Show()
    
    -- Force the frame to be visible and ensure it stays visible
    self.bars:SetShown(true)

    self.cast_bar:SetSize(TUI.db.profile.cast_bar.width, TUI.db.profile.cast_bar.height)
    local castBarAnchor = self:GetAnchorFrame(TUI.db.profile.cast_bar.anchor_frame)
    self.cast_bar:SetPoint(TUI.db.profile.cast_bar.anchor, castBarAnchor, TUI.db.profile.cast_bar.anchor_to, TUI.db.profile.cast_bar.pos_x, TUI.db.profile.cast_bar.pos_y)

    self.resource_bar:SetSize(TUI.db.profile.resource_bar.width, TUI.db.profile.resource_bar.height)
    local resourceBarAnchor = self:GetAnchorFrame(TUI.db.profile.resource_bar.anchor_frame)
    self.resource_bar:SetPoint(TUI.db.profile.resource_bar.anchor, resourceBarAnchor, TUI.db.profile.resource_bar.anchor_to, TUI.db.profile.resource_bar.pos_x, TUI.db.profile.resource_bar.pos_y)

    self.secondary_resource_bar:SetSize(TUI.db.profile.secondary_resource_bar.width, TUI.db.profile.secondary_resource_bar.height)
    local secondaryResourceBarAnchor = self:GetAnchorFrame(TUI.db.profile.secondary_resource_bar.anchor_frame)
    self.secondary_resource_bar:SetPoint(TUI.db.profile.secondary_resource_bar.anchor, secondaryResourceBarAnchor, TUI.db.profile.secondary_resource_bar.anchor_to, TUI.db.profile.secondary_resource_bar.pos_x, TUI.db.profile.secondary_resource_bar.pos_y)

    -- Refresh edit mode indicators if edit mode is enabled
    self:RefreshEditModeIndicators()
end

function TUI:_AddOptions()
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
                    ShowProfileImportExport("export")
                end,
            },
            import_btn = {
                type = "execute",
                name = "Import New Profile",
                order = 2,
                func = function()
                    ShowProfileImportExport("import")
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

function TUI:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("TUI_DB", defaults)
    
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
    
    self:DisableBlizz()

    self:UpdateLayout()

    self:_AddOptions()

    self:RegisterChatCommand("tui", "SlashCommand")
    
    -- Clear initialization flag
    self.isInitializing = false
end

function TUI:SlashCommand(msg)
    if msg == "edit" then
        self:ToggleEditMode()
    elseif msg == "reset" then
        self:ResetPositions()
    elseif msg == "help" then
        print("|cff88ff88TUI Commands:|r")
        print("|cffffffff/tui edit|r - Toggle edit mode")
        print("|cffffffff/tui reset|r - Reset all element positions")
        print("|cffffffff/tui help|r - Show this help")
    end
end

function TUI:RefreshConfig()
    self:UpdateLayout()
end

-- Edit Mode Functions
function TUI:ToggleEditMode()
    self.editModeEnabled = not self.editModeEnabled
    
    if self.editModeEnabled then
        self:EnterEditMode()
    else
        self:ExitEditMode()
    end
end

function TUI:EnterEditMode()
    print("|cff88ff88TUI:|r Entering edit mode. Drag elements to reposition them.")
    
    -- Apply database anchor settings to all frames when entering edit mode
    self:ApplyDatabaseAnchorSettingsToAllFrames()
    
    -- Wait a frame for layout to complete, then continue with edit mode setup
    local continueFrame = CreateFrame("Frame")
    continueFrame:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        TUI:ContinueEditModeSetup()
    end)
end

function TUI:ContinueEditModeSetup()
    -- Ensure cast bar and secondary resource bar are visible
    self.cast_bar:Show()
    self.secondary_resource_bar.frame:Show()
    
    -- Force visibility in edit mode by temporarily overriding their visibility logic
    self.cast_bar.tuiEditModeForced = true
    self.secondary_resource_bar.tuiEditModeForced = true
    
    -- Add temporary children to frames with less than 3 children
    self:AddTemporaryChildrenForEditMode()
    
    self:CreateEditModeOverlay()
    
    -- Enable dragging for all elements
    self:EnableElementDragging()
    
    
    -- Force main cooldowns to update its layout periodically in edit mode
    if self.main_cooldowns then
        self.main_cooldowns.tuiEditModeForced = true
        self.main_cooldowns:SetShown(true)
        
        self.main_cooldowns.tuiEditModeUpdateFrame = CreateFrame("Frame")
        self.main_cooldowns.tuiEditModeUpdateFrame:SetScript("OnUpdate", function(self)
            if TUI.editModeEnabled and TUI.main_cooldowns and TUI.main_cooldowns.tuiEditModeForced then
                -- Force layout update every few frames
                TUI.main_cooldowns:Layout()
                TUI.main_cooldowns:SetShown(true)
                
                -- Also refresh the edit mode indicator size
                if TUI.main_cooldowns.tuiEditIndicator then
                    local visualWidth, visualHeight = TUI:GetFrameVisualBounds(TUI.main_cooldowns)
                    TUI.main_cooldowns.tuiEditIndicator:SetSize(visualWidth, visualHeight)
                    
                    -- Update border sizes too
                    if TUI.main_cooldowns.tuiEditBorder then
                        TUI.main_cooldowns.tuiEditBorder.top:SetSize(visualWidth + 4, 2)
                        TUI.main_cooldowns.tuiEditBorder.bottom:SetSize(visualWidth + 4, 2)
                        TUI.main_cooldowns.tuiEditBorder.left:SetSize(2, visualHeight + 4)
                        TUI.main_cooldowns.tuiEditBorder.right:SetSize(2, visualHeight + 4)
                    end
                end
            else
                -- Clean up when edit mode is disabled
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
    
    -- Force util cooldowns to update its layout periodically in edit mode
    if self.util_cooldowns then
        self.util_cooldowns.tuiEditModeForced = true
        self.util_cooldowns:SetShown(true)
        
        self.util_cooldowns.tuiEditModeUpdateFrame = CreateFrame("Frame")
        self.util_cooldowns.tuiEditModeUpdateFrame:SetScript("OnUpdate", function(self)
            if TUI.editModeEnabled and TUI.util_cooldowns and TUI.util_cooldowns.tuiEditModeForced then
                -- Force layout update every few frames
                TUI.util_cooldowns:Layout()
                TUI.util_cooldowns:SetShown(true)
                
                -- Also refresh the edit mode indicator size
                if TUI.util_cooldowns.tuiEditIndicator then
                    local visualWidth, visualHeight = TUI:GetFrameVisualBounds(TUI.util_cooldowns)
                    TUI.util_cooldowns.tuiEditIndicator:SetSize(visualWidth, visualHeight)
                    
                    -- Update border sizes too
                    if TUI.util_cooldowns.tuiEditBorder then
                        TUI.util_cooldowns.tuiEditBorder.top:SetSize(visualWidth + 4, 2)
                        TUI.util_cooldowns.tuiEditBorder.bottom:SetSize(visualWidth + 4, 2)
                        TUI.util_cooldowns.tuiEditBorder.left:SetSize(2, visualHeight + 4)
                        TUI.util_cooldowns.tuiEditBorder.right:SetSize(2, visualHeight + 4)
                    end
                end
            else
                -- Clean up when edit mode is disabled
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
    
    -- Force aura buffs to update its layout periodically in edit mode
    if self.aura_buffs then
        self.aura_buffs.tuiEditModeForced = true
        self.aura_buffs:SetShown(true)
        
        self.aura_buffs.tuiEditModeUpdateFrame = CreateFrame("Frame")
        self.aura_buffs.tuiEditModeUpdateFrame:SetScript("OnUpdate", function(self)
            if TUI.editModeEnabled and TUI.aura_buffs and TUI.aura_buffs.tuiEditModeForced then
                -- Force layout update every few frames
                TUI.aura_buffs:Layout()
                TUI.aura_buffs:SetShown(true)
                
                -- Also refresh the edit mode indicator size
                if TUI.aura_buffs.tuiEditIndicator then
                    local visualWidth, visualHeight = TUI:GetFrameVisualBounds(TUI.aura_buffs)
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
    if self.bars then
        self.bars.tuiEditModeForced = true
        self.bars:SetShown(true)
        
        self.bars.tuiEditModeUpdateFrame = CreateFrame("Frame")
        self.bars.tuiEditModeUpdateFrame:SetScript("OnUpdate", function(self)
            if TUI.editModeEnabled and TUI.bars and TUI.bars.tuiEditModeForced then
                -- Force layout update every few frames
                TUI.bars:Layout()
                TUI.bars:SetShown(true)
                
                -- Also refresh the edit mode indicator size
                if TUI.bars.tuiEditIndicator then
                    local visualWidth, visualHeight = TUI:GetFrameVisualBounds(TUI.bars)
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
    if self.db.profile.edit_mode.show_grid then
        self:ShowGrid()
    end
end

function TUI:AddTemporaryChildrenForEditMode()
    -- Add temporary children to frames that have less than 3 children
    local framesToCheck = {
        {frame = self.main_cooldowns, name = "Main Cooldowns", childCount = 3},
        {frame = self.util_cooldowns, name = "Util Cooldowns", childCount = 3},
        {frame = self.aura_buffs, name = "Aura Buffs", childCount = 3},
        {frame = self.bars, name = "Bars", childCount = 3}
    }
    
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

function TUI:RemoveTemporaryChildren()
    -- Remove all temporary children from frames
    local framesToCheck = {self.main_cooldowns, self.util_cooldowns, self.aura_buffs, self.bars}
    
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

function TUI:ExitEditMode()
    print("|cff88ff88TUI:|r Exiting edit mode.")
    
    -- Clear forced visibility flags
    if self.cast_bar then
        self.cast_bar.tuiEditModeForced = false
    end
    if self.secondary_resource_bar then
        self.secondary_resource_bar.tuiEditModeForced = false
    end
    
    -- Clear main cooldowns forced visibility and update frame
    if self.main_cooldowns then
        self.main_cooldowns.tuiEditModeForced = false
        if self.main_cooldowns.tuiEditModeUpdateFrame then
            self.main_cooldowns.tuiEditModeUpdateFrame:SetScript("OnUpdate", nil)
            self.main_cooldowns.tuiEditModeUpdateFrame = nil
        end
    end
    
    -- Clear util cooldowns forced visibility and update frame
    if self.util_cooldowns then
        self.util_cooldowns.tuiEditModeForced = false
        if self.util_cooldowns.tuiEditModeUpdateFrame then
            self.util_cooldowns.tuiEditModeUpdateFrame:SetScript("OnUpdate", nil)
            self.util_cooldowns.tuiEditModeUpdateFrame = nil
        end
    end
    
    -- Clear aura buffs forced visibility and update frame
    if self.aura_buffs then
        self.aura_buffs.tuiEditModeForced = false
        if self.aura_buffs.tuiEditModeUpdateFrame then
            self.aura_buffs.tuiEditModeUpdateFrame:SetScript("OnUpdate", nil)
            self.aura_buffs.tuiEditModeUpdateFrame = nil
        end
    end
    
    -- Clear bars forced visibility and update frame
    if self.bars then
        self.bars.tuiEditModeForced = false
        if self.bars.tuiEditModeUpdateFrame then
            self.bars.tuiEditModeUpdateFrame:SetScript("OnUpdate", nil)
            self.bars.tuiEditModeUpdateFrame = nil
        end
    end
    
    -- Remove temporary children added for edit mode
    self:RemoveTemporaryChildren()
    
    -- Disable dragging for all elements
    self:DisableElementDragging()
    
    -- Hide grid
    self:HideGrid()
    
    -- Remove edit mode overlay
    self:RemoveEditModeOverlay()
    
    -- Update layout to apply any changes
    self:UpdateLayout()
    
    -- Note: We don't hide the frames here because UpdateLayout() will handle their visibility
    -- based on their normal logic (e.g., main_cooldowns may be hidden if no cooldowns are active)
end

function TUI:CreateEditModeOverlay()
    if self.editModeOverlay then return end
    
    self.editModeOverlay = CreateFrame("Frame", "TUI_EditModeOverlay", UIParent)
    self.editModeOverlay:SetAllPoints()
    self.editModeOverlay:SetFrameStrata("TOOLTIP")
    self.editModeOverlay:SetFrameLevel(1000)
    self.editModeOverlay:EnableMouse(false)
    
    -- Add instructions text
    local instructions = self.editModeOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    instructions:SetPoint("TOP", UIParent, "TOP", 0, -50)
    instructions:SetText("|cffffffffTUI Edit Mode|r - Drag elements to reposition them")
    instructions:SetTextColor(1, 1, 0)
    
    -- Add right-click instructions
    local rightClickInstructions = self.editModeOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rightClickInstructions:SetPoint("TOP", instructions, "BOTTOM", 0, -10)
    rightClickInstructions:SetText("Right-click any frame for additional settings")
    rightClickInstructions:SetTextColor(0.8, 0.8, 0.8)
    
    -- Add exit instructions
    local exitInstructions = self.editModeOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    exitInstructions:SetPoint("TOP", rightClickInstructions, "BOTTOM", 0, -10)
    exitInstructions:SetText("Type |cffffffff/tui edit|r to exit edit mode")
    exitInstructions:SetTextColor(0.8, 0.8, 0.8)
end

function TUI:RemoveEditModeOverlay()
    if self.editModeOverlay then
        self.editModeOverlay:Hide()
        self.editModeOverlay = nil
    end
end

function TUI:ShowGrid()
    if self.gridFrame then return end
    
    self.gridFrame = CreateFrame("Frame", "TUI_GridFrame", UIParent)
    self.gridFrame:SetAllPoints()
    self.gridFrame:SetFrameStrata("BACKGROUND")
    self.gridFrame:SetFrameLevel(1)
    self.gridFrame:EnableMouse(false)
    
    local gridSize = self.db.profile.edit_mode.grid_size
    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    
    -- Vertical lines
    local numVerticalLines = math.ceil(screenWidth / gridSize) + 1
    for i = 0, numVerticalLines do
        local x = i * gridSize
        local line = self.gridFrame:CreateTexture(nil, "BACKGROUND")
        line:SetTexture("Interface\\AddOns\\TUI\\Media\\Flat.tga")
        line:SetColorTexture(0.3, 0.3, 0.3, 0.3)
        line:SetPoint("TOPLEFT", self.gridFrame, "TOPLEFT", x, 0)
        line:SetPoint("BOTTOMLEFT", self.gridFrame, "BOTTOMLEFT", x, 0)
        line:SetWidth(1)
    end
    
    -- Horizontal lines
    local numHorizontalLines = math.ceil(screenHeight / gridSize) + 1
    for i = 0, numHorizontalLines do
        local y = i * gridSize
        local line = self.gridFrame:CreateTexture(nil, "BACKGROUND")
        line:SetTexture("Interface\\AddOns\\TUI\\Media\\Flat.tga")
        line:SetColorTexture(0.3, 0.3, 0.3, 0.3)
        line:SetPoint("TOPLEFT", self.gridFrame, "TOPLEFT", 0, -y)
        line:SetPoint("TOPRIGHT", self.gridFrame, "TOPRIGHT", 0, -y)
        line:SetHeight(1)
    end
end

function TUI:HideGrid()
    if self.gridFrame then
        self.gridFrame:Hide()
        self.gridFrame = nil
    end
end

function TUI:EnableElementDragging()
    -- Enable dragging for all UI elements with user-friendly names
    self:EnableDraggingForElement(self.main_cooldowns, "main_cooldowns", "Main Cooldowns")
    self:EnableDraggingForElement(self.util_cooldowns, "util_cooldowns", "Utility Cooldowns")
    self:EnableDraggingForElement(self.aura_buffs, "aura_buffs", "Aura Buffs")
    self:EnableDraggingForElement(self.bars, "bar_buffs", "Bar Buffs")
    self:EnableDraggingForElement(self.cast_bar.frame, "cast_bar", "Cast Bar")
    self:EnableDraggingForElement(self.resource_bar.frame, "resource_bar", "Resource Bar")
    self:EnableDraggingForElement(self.secondary_resource_bar.frame, "secondary_resource_bar", "Secondary Resource Bar")
end

function TUI:DisableElementDragging()
    -- Disable dragging for all UI elements
    self:DisableDraggingForElement(self.main_cooldowns)
    self:DisableDraggingForElement(self.util_cooldowns)
    self:DisableDraggingForElement(self.aura_buffs)
    self:DisableDraggingForElement(self.bars)
    self:DisableDraggingForElement(self.cast_bar.frame)
    self:DisableDraggingForElement(self.resource_bar.frame)
    self:DisableDraggingForElement(self.secondary_resource_bar.frame)
end

function TUI:EnableDraggingForElement(element, configKey, elementName)
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
    self:AddEditModeIndicator(frame, elementName)
    
    -- Add anchor indicator
    self:AddAnchorIndicator(frame, elementName)
    
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
        TUI:UpdateAnchorDisplay(self)
        
        -- Add update handler to refresh anchor display and position during drag
        self.tuiDragUpdateFrame = CreateFrame("Frame")
        self.tuiDragUpdateFrame:SetScript("OnUpdate", function()
            if self.tuiIsDragging then
                TUI:UpdateFramePositionDuringDrag(self)
                TUI:UpdateAnchorDisplay(self)
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
        TUI:SaveElementPosition(self, configKey)
    end)
end

function TUI:DisableDraggingForElement(element)
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
    self:RemoveEditModeIndicator(frame)
end

function TUI:AddAnchorIndicator(frame, elementName)
    if frame.tuiAnchorIndicator then return end
    
    -- Create a small indicator showing the anchor point
    local indicator = frame:CreateTexture(nil, "OVERLAY")
    indicator:SetSize(8, 8)
    indicator:SetColorTexture(1, 1, 0, 0.8) -- Bright yellow
    indicator:SetDrawLayer("OVERLAY", 7)
    
    frame.tuiAnchorIndicator = indicator
    
    -- Update the indicator position
    self:UpdateAnchorIndicator(frame)
end

function TUI:UpdateAnchorIndicator(frame)
    if not frame.tuiAnchorIndicator then return end
    
    local configKey = self:GetConfigKeyForFrame(frame)
    if not configKey then return end
    
    local config = self.db.profile[configKey]
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

function TUI:RemoveAnchorIndicator(frame)
    if frame.tuiAnchorIndicator then
        frame.tuiAnchorIndicator:Hide()
        frame.tuiAnchorIndicator = nil
    end
end
function TUI:AddEditModeIndicator(frame, elementName)
    if frame.tuiEditIndicator then return end
    
    -- Calculate the actual visual bounds of the frame
    local visualWidth, visualHeight = self:GetFrameVisualBounds(frame)
    
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
    frame.tuiEditRightClickOverlay.configKey = self:GetConfigKeyForFrame(frame)
    
    -- Add right-click handler
    frame.tuiEditRightClickOverlay:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            TUI:OpenFrameSettings(self.elementName, self.configKey)
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

function TUI:RemoveEditModeIndicator(frame)
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
    self:RemoveAnchorIndicator(frame)
end

function TUI:GetConfigKeyForFrame(frame)
    -- Map frame names to their configuration keys
    local frameName = frame:GetName()
    
    if frameName == "TUI_MainCooldowns" then
        return "main_cooldowns"
    elseif frameName == "TUI_UtilCooldowns" then
        return "util_cooldowns"
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
    if self.cast_bar and frame == self.cast_bar.frame then
        return "cast_bar"
    elseif self.resource_bar and frame == self.resource_bar.frame then
        return "resource_bar"
    elseif self.secondary_resource_bar and frame == self.secondary_resource_bar.frame then
        return "secondary_resource_bar"
    end
    
    return nil
end

function TUI:OpenFrameSettings(elementName, configKey)
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

function TUI:ConvertAnchorPosition(configKey, oldAnchorFrame, newAnchorFrame)
    -- Get the frame that this config applies to
    local frame = self:GetFrameForConfigKey(configKey)
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
    local config = self.db.profile[configKey]
    if config then
        config.pos_x = newRelativeX
        config.pos_y = newRelativeY
    end
    
    -- Update the layout to apply the new position
    self:UpdateLayout()
end

function TUI:GetFrameForConfigKey(configKey)
    -- Map config keys to their corresponding frames
    if configKey == "main_cooldowns" then
        return self.main_cooldowns
    elseif configKey == "util_cooldowns" then
        return self.util_cooldowns
    elseif configKey == "aura_buffs" then
        return self.aura_buffs
    elseif configKey == "bar_buffs" then
        return self.bars
    elseif configKey == "cast_bar" then
        return self.cast_bar.frame
    elseif configKey == "resource_bar" then
        return self.resource_bar.frame
    elseif configKey == "secondary_resource_bar" then
        return self.secondary_resource_bar.frame
    end
    return nil
end

function TUI:ApplyDatabaseAnchorSettingsToAllFrames()
    -- Apply database anchor settings to all frames when entering edit mode
    self:ApplyDatabaseAnchorSettings(self.main_cooldowns, "main_cooldowns")
    self:ApplyDatabaseAnchorSettings(self.util_cooldowns, "util_cooldowns")
    self:ApplyDatabaseAnchorSettings(self.aura_buffs, "aura_buffs")
    self:ApplyDatabaseAnchorSettings(self.bars, "bar_buffs")
    self:ApplyDatabaseAnchorSettings(self.cast_bar.frame, "cast_bar")
    self:ApplyDatabaseAnchorSettings(self.resource_bar.frame, "resource_bar")
    self:ApplyDatabaseAnchorSettings(self.secondary_resource_bar.frame, "secondary_resource_bar")
    
    -- Now apply the layout using the database settings
    self:UpdateLayout()
end

function TUI:ApplyDatabaseAnchorSettings(frame, configKey)
    if not frame or not configKey then return end
    
    -- Get the configuration from database
    local config = self.db.profile[configKey]
    if not config then 
        return 
    end
    
    -- Get the anchor frame object
    local anchorFrame = self:GetAnchorFrame(config.anchor_frame)
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

function TUI:UpdateFramePositionDuringDrag(frame)
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

function TUI:UpdateAnchorDisplay(frame)
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

function TUI:SaveElementPosition(frame, configKey)
    if not frame or not configKey then return end
    
    -- Get current position
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
    
    -- Update database - preserve existing anchor settings, only update position
    local config = self.db.profile[configKey]
    if config then
        config.pos_x = xOfs
        config.pos_y = yOfs
    end
end

function TUI:ResetPositions()
    print("|cff88ff88TUI:|r Resetting all element positions to defaults.")
    
    -- Reset to default positions
    for key, defaultConfig in pairs(defaults.profile) do
        if key ~= "edit_mode" and self.db.profile[key] then
            for settingKey, defaultValue in pairs(defaultConfig) do
                self.db.profile[key][settingKey] = defaultValue
            end
        end
    end
    
    -- Update layout
    self:UpdateLayout()
end
