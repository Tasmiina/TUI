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
        main_cooldowns = {
            pos_x = 0,
            pos_y = -1,
            first_row_limit = 9,
            first_row_size_x = 36,
            first_row_size_y = 28,
            row_limit = 9,
            row_size_x = 34,
            row_size_y = 26,
            spacing_x = 3,
            spacing_y = 2,
            grow_direction_up = false,
            anchor_frame = "TUI_ResourceBar",
            anchor_to = "BOTTOM",
            anchor = "TOP"
        },
        util_cooldowns = {
            pos_x = 0,
            pos_y = -250,
            first_row_limit = 9,
            first_row_size_x = 36,
            first_row_size_y = 28,
            spacing_x = 3,
            spacing_y = 2,
            row_limit = 9,
            row_size_x = 34,
            row_size_y = 26,
            grow_direction_up = false,
            anchor_frame = "TUI_ResourceBar",
            anchor_to = "BOTTOM",
            anchor = "TOP"
        },
        bar_buffs = {
            pos_x = 0,
            pos_y = -100,
            anchor_frame = "TUI_ResourceBar",
            anchor_to = "BOTTOM",
            anchor = "TOP"
        },
        aura_buffs = {
            pos_x = 0,
            pos_y = 10,
            anchor_frame = "TUI_Castbar",
            anchor_to = "TOP",
            anchor = "BOTTOM"
        },
        cast_bar = {
            anchor_frame = "TUI_SecondaryResourceBar",
            anchor_to = "TOP",
            anchor = "BOTTOM",
            pos_x = 0,
            pos_y = 0,
            width = 348,
            height = 10
        },
        resource_bar = {
            anchor_frame = "UIParent",
            anchor_to = "CENTER",
            anchor = "BOTTOM",
            pos_x = 0,
            pos_y = -190,
            width = 348,
            height = 7
        },
        secondary_resource_bar = {
            anchor_frame = "TUI_ResourceBar",
            anchor_to = "TOP",
            anchor = "BOTTOM",
            pos_x = 0,
            pos_y = 0,
            width = 348,
            height = 5
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
                type = "input", name = "Anchor Frame", order = 3,
                get = function() return TUI.db.profile[data].anchor_frame end,
                set = SetAndUpdate(function(val) TUI.db.profile[data].anchor_frame = val end),
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

function TUI:UpdateLayout()

    self:ClearAnchors()

    -- Update MainCooldowns according to settings
    self.main_cooldowns:SetPoint(TUI.db.profile.main_cooldowns.anchor, TUI.db.profile.main_cooldowns.anchor_frame, TUI.db.profile.main_cooldowns.anchor_to, TUI.db.profile.main_cooldowns.pos_x, TUI.db.profile.main_cooldowns.pos_y)

    self.main_cooldowns.firstRowLimit = TUI.db.profile.main_cooldowns.first_row_limit
    self.main_cooldowns.firstRowSizeX = TUI.db.profile.main_cooldowns.first_row_size_x
    self.main_cooldowns.firstRowSizeY = TUI.db.profile.main_cooldowns.first_row_size_y
    
    self.main_cooldowns.rowLimit = TUI.db.profile.main_cooldowns.row_limit
    self.main_cooldowns.rowSizeX = TUI.db.profile.main_cooldowns.row_size_x
    self.main_cooldowns.rowSizeY = TUI.db.profile.main_cooldowns.row_size_y

    self.main_cooldowns.spacingX = TUI.db.profile.main_cooldowns.spacing_x
    self.main_cooldowns.spacingY = TUI.db.profile.main_cooldowns.spacing_y
    self.main_cooldowns.growDirectionUp = TUI.db.profile.main_cooldowns.grow_direction_up

    self.main_cooldowns:Layout()
    self.main_cooldowns:Show()

    -- Update UtilCooldowns according to settings
    self.util_cooldowns:SetPoint(TUI.db.profile.util_cooldowns.anchor, TUI.db.profile.util_cooldowns.anchor_frame, TUI.db.profile.util_cooldowns.anchor_to, TUI.db.profile.util_cooldowns.pos_x, TUI.db.profile.util_cooldowns.pos_y)

    self.util_cooldowns.firstRowLimit = TUI.db.profile.util_cooldowns.first_row_limit
    self.util_cooldowns.firstRowSizeX = TUI.db.profile.util_cooldowns.first_row_size_x
    self.util_cooldowns.firstRowSizeY = TUI.db.profile.util_cooldowns.first_row_size_y
    
    self.util_cooldowns.rowLimit = TUI.db.profile.util_cooldowns.row_limit
    self.util_cooldowns.rowSizeX = TUI.db.profile.util_cooldowns.row_size_x
    self.util_cooldowns.rowSizeY = TUI.db.profile.util_cooldowns.row_size_y

    self.util_cooldowns.spacingX = TUI.db.profile.util_cooldowns.spacing_x
    self.util_cooldowns.spacingY = TUI.db.profile.util_cooldowns.spacing_y
    self.util_cooldowns.growDirectionUp = TUI.db.profile.util_cooldowns.grow_direction_up

    self.util_cooldowns:Layout()
    self.util_cooldowns:Show()

    self.aura_buffs:SetPoint(TUI.db.profile.aura_buffs.anchor, TUI.db.profile.aura_buffs.anchor_frame, TUI.db.profile.aura_buffs.anchor_to, TUI.db.profile.aura_buffs.pos_x, TUI.db.profile.aura_buffs.pos_y)

    self.bars:SetPoint(TUI.db.profile.bar_buffs.anchor, TUI.db.profile.bar_buffs.anchor_frame, TUI.db.profile.bar_buffs.anchor_to, TUI.db.profile.bar_buffs.pos_x, TUI.db.profile.bar_buffs.pos_y)

    self.cast_bar:SetSize(TUI.db.profile.cast_bar.width, TUI.db.profile.cast_bar.height)
    self.cast_bar:SetPoint(TUI.db.profile.cast_bar.anchor, TUI.db.profile.cast_bar.anchor_frame, TUI.db.profile.cast_bar.anchor_to, TUI.db.profile.cast_bar.pos_x, TUI.db.profile.cast_bar.pos_y)

    self.resource_bar:SetSize(TUI.db.profile.resource_bar.width, TUI.db.profile.resource_bar.height)
    self.resource_bar:SetPoint(TUI.db.profile.resource_bar.anchor, TUI.db.profile.resource_bar.anchor_frame, TUI.db.profile.resource_bar.anchor_to, TUI.db.profile.resource_bar.pos_x, TUI.db.profile.resource_bar.pos_y)

    self.secondary_resource_bar:SetSize(TUI.db.profile.secondary_resource_bar.width, TUI.db.profile.secondary_resource_bar.height)
    self.secondary_resource_bar:SetPoint(TUI.db.profile.secondary_resource_bar.anchor, TUI.db.profile.secondary_resource_bar.anchor_frame, TUI.db.profile.secondary_resource_bar.anchor_to, TUI.db.profile.secondary_resource_bar.pos_x, TUI.db.profile.secondary_resource_bar.pos_y)

end

function TUI:_AddOptions()
    local options = {
        type = "group",
        name = addonName,
        args = {
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
end

function TUI:RefreshConfig()
    self:UpdateLayout()
end
