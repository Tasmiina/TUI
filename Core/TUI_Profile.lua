-- TUI Profile Module
-- Handles profile import/export functionality

---@class TUI_Profile
TUI_Profile = {}

local AceGUI = LibStub("AceGUI-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")


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
        AceConfigRegistry:NotifyChange("TUI")
    end

    -- Force a UI refresh (works for both standalone and Blizzard panel)
    if AceConfigDialog and AceConfigDialog.OpenFrames then
        local frame = AceConfigDialog.OpenFrames["TUI"]
        if frame then
            AceConfigDialog:Open("TUI")
        end
    end
end

function TUI_Profile:ShowImportExport(mode)
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

