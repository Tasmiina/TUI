---@class TUI_SpellPicker
TUI_SpellPicker = {}

local FRAME_WIDTH = 720
local FRAME_HEIGHT = 560
local LEFT_MARGIN = 16
local RIGHT_MARGIN = 32
local COLUMN_GAP = 24
local SECTION_TOP_OFFSET = -56
local TAB_WIDTH = 48
local TAB_SPACING = 12

local AVAILABLE_WIDTH = FRAME_WIDTH - LEFT_MARGIN - RIGHT_MARGIN - COLUMN_GAP - TAB_WIDTH - TAB_SPACING
local COLUMN_WIDTH = math.floor(AVAILABLE_WIDTH / 2)

local BACKDROP_INFO = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 24,
    edgeSize = 24,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
}

local ROW_HEIGHT = 32
local ROW_WIDTH = COLUMN_WIDTH - 20
local DEFAULT_ICON = 134400 -- Spellbook icon fallback
local UNKNOWN_SPELL_NAME = "Unknown"
local ItemTypeSpell = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or nil
local SpellBankPlayer = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or nil
local SpellBankPet = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet or nil
local ItemTypeFlyout = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout or nil

local GetFlyoutInfo = rawget(_G, "GetFlyoutInfo")
local GetFlyoutSlotInfo = rawget(_G, "GetFlyoutSlotInfo")
local GlobalGetSpellInfo = rawget(_G, "GetSpellInfo")
local IsPassiveSpell = rawget(_G, "IsPassiveSpell")

local SPELLBOOK_FILTER_ORDER = { "class", "general", "pet" }
local SPELLBOOK_FILTERS = {
    class = { label = "Class Spells" },
    general = { label = "General Spells" },
    pet = { label = "Pet Spells" },
}

local COOLDOWN_LISTS = {
    { key = "cooldowns_1", icon = "Interface\\Icons\\INV_Misc_Number_1", label = "Cooldowns 1" },
    { key = "cooldowns_2", icon = "Interface\\Icons\\INV_Misc_Number_2", label = "Cooldowns 2" },
    { key = "cooldowns_3", icon = "Interface\\Icons\\INV_Misc_Number_3", label = "Cooldowns 3" },
    { key = "cooldowns_4", icon = "Interface\\Icons\\INV_Misc_Number_4", label = "Cooldowns 4" },
    { key = "cooldowns_5", icon = "Interface\\Icons\\INV_Misc_Number_5", label = "Cooldowns 5" },
    { key = "cooldowns_6", icon = "Interface\\Icons\\INV_Misc_Number_6", label = "Cooldowns 6" },
}

TUI_SpellPicker.spellbookFilter = "class"
TUI_SpellPicker.selectedCooldownListIndex = 1

local function GetCooldownListInfo(index)
    return COOLDOWN_LISTS[index or 1]
end

function TUI_SpellPicker:GetSelectedCooldownListIndex()
    if not self.selectedCooldownListIndex or not COOLDOWN_LISTS[self.selectedCooldownListIndex] then
        self.selectedCooldownListIndex = 1
    end
    return self.selectedCooldownListIndex
end

function TUI_SpellPicker:GetSelectedCooldownListInfo()
    return GetCooldownListInfo(self:GetSelectedCooldownListIndex())
end

function TUI_SpellPicker:GetSelectedCooldownListKey()
    local info = self:GetSelectedCooldownListInfo()
    return info and info.key or "cooldowns_1"
end

function TUI_SpellPicker:GetSelectedCooldownListLabel()
    local info = self:GetSelectedCooldownListInfo()
    return info and info.label or "Cooldowns"
end

function TUI_SpellPicker:SetSelectedCooldownList(index)
    if not COOLDOWN_LISTS[index] then
        return
    end

    if self.selectedCooldownListIndex == index then
        return
    end

    self.selectedCooldownListIndex = index
    self:UpdateCooldownTabSelection()
    self:RefreshSections()
end

function TUI_SpellPicker:UpdateCooldownTabSelection()
    if not self.tabButtons then
        return
    end

    local selectedIndex = self:GetSelectedCooldownListIndex()

    for index, button in ipairs(self.tabButtons) do
        if index == selectedIndex then
            button:SetAlpha(1)
            if button.SelectedTexture then
                button.SelectedTexture:Show()
            end
        else
            button:SetAlpha(0.6)
            if button.SelectedTexture then
                button.SelectedTexture:Hide()
            end
        end
    end
end

function TUI_SpellPicker:CreateCooldownTabs(frame)
    if self.tabButtons then
        return
    end

    self.tabButtons = {}

    local buttonWidth = TAB_WIDTH
    local buttonHeight = 48
    local spacing = 8
    local startX = LEFT_MARGIN
    local startY = SECTION_TOP_OFFSET

    for index, info in ipairs(COOLDOWN_LISTS) do
        local button = CreateFrame("Button", nil, frame)
        button:SetSize(buttonWidth, buttonHeight)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", startX, startY - (index - 1) * (buttonHeight + spacing))

        local normal = button:CreateTexture(nil, "ARTWORK")
        normal:SetAllPoints()
        normal:SetTexture(info.icon)
        button:SetNormalTexture(normal)

        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.15)
        button:SetHighlightTexture(highlight)

        local selected = button:CreateTexture(nil, "BACKGROUND")
        selected:SetAllPoints()
        selected:SetColorTexture(1, 0.82, 0, 0.25)
        selected:Hide()
        button.SelectedTexture = selected

        button:SetScript("OnClick", function()
            self:SetSelectedCooldownList(index)
        end)

        if GameTooltip then
            button:SetScript("OnEnter", function(btn)
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                GameTooltip:SetText(info.label)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end

        self.tabButtons[index] = button
    end

    self:UpdateCooldownTabSelection()
end

local function NormalizeSpellId(identifier)
    if identifier == nil then
        return nil
    end

    if type(identifier) == "number" then
        return identifier
    end

    local numeric = tonumber(identifier)
    return numeric or identifier
end

local function SanitizeCooldownEntry(entry)
    if not entry then
        return nil
    end

    local normalizedId = NormalizeSpellId(entry.id)
    if not normalizedId then
        return nil
    end

    local entryType = entry.type
    if entryType ~= "item" then
        entryType = "spell"
    end

    return {
        id = normalizedId,
        type = entryType,
    }
end

local function CopyCooldownList(list)
    local copy = {}
    local seen = {}

    if not list then
        return copy
    end

    for _, entry in ipairs(list) do
        local sanitized = SanitizeCooldownEntry(entry)
        if sanitized and not seen[sanitized.id] then
            seen[sanitized.id] = true
            table.insert(copy, sanitized)
        end
    end

    return copy
end

local function RefreshCooldownFramesForKey(key)
    if not key or not TUI or not TUI.cooldown_frames then
        return
    end

    local frame = TUI.cooldown_frames[key]
    if frame and frame.RefreshLayout then
        frame:RefreshLayout()
    end
end

function TUI_SpellPicker:GetCooldownList()
    if not TUI or not TUI.db or not TUI.db.profile then
        return {}
    end

    local db = TUI.db
    local profile = db.profile
    if type(profile) ~= "table" then
        profile = {}
        db.profile = profile
    end
    profile.spells = profile.spells or {}

    local key = self:GetSelectedCooldownListKey()
    profile.spells[key] = profile.spells[key] or {}

    return profile.spells[key]
end

function TUI_SpellPicker:SetCooldownList(list)
    if not TUI or not TUI.db or not TUI.db.profile then
        return
    end

    local db = TUI.db
    local profile = db.profile
    if type(profile) ~= "table" then
        profile = {}
        db.profile = profile
    end
    profile.spells = profile.spells or {}

    local key = self:GetSelectedCooldownListKey()
    profile.spells[key] = CopyCooldownList(list)
end

local function CreateSpellbookFilterDropdown(selfRef, section)
    local dropdown = CreateFrame("Frame", "TUI_SpellPickerSpellbookFilterDropdown", section.Container, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPRIGHT", -2, 6)
    UIDropDownMenu_SetWidth(dropdown, COLUMN_WIDTH - 60)
    UIDropDownMenu_JustifyText(dropdown, "LEFT")

    local function OnSelect(_, key)
        CloseDropDownMenus()
        selfRef:SetSpellbookFilter(key)
    end

    local function Initialize(_, level)
        if not level then
            return
        end

        for _, filterKey in ipairs(SPELLBOOK_FILTER_ORDER) do
            local filterData = SPELLBOOK_FILTERS[filterKey]
            if filterData then
                local info = UIDropDownMenu_CreateInfo()
                info.text = filterData.label
                info.arg1 = filterKey
                info.func = OnSelect
                info.checked = (selfRef.spellbookFilter == filterKey)
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end

    UIDropDownMenu_Initialize(dropdown, Initialize)

    section.FilterDropdown = dropdown
end

local function CreateTitleFontString(frame)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", 18, -18)
    title:SetText("TUI Spell Picker")
    return title
end

local function CreateCloseButton(frame)
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -4, -4)
    closeButton:SetScript("OnClick", function()
        TUI_SpellPicker:Hide()
    end)
    return closeButton
end

local function CreateSection(self, frame, key, titleText, offsetX, emptyText)
    self.sections = self.sections or {}

    local section = {}
    section.key = key

    local container = CreateFrame("Frame", nil, frame)
    container:SetSize(COLUMN_WIDTH, FRAME_HEIGHT - 96)
    container:SetPoint("TOPLEFT", frame, "TOPLEFT", offsetX, SECTION_TOP_OFFSET)
    section.Container = container

    section.Title = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    section.Title:SetPoint("TOPLEFT", 2, 0)
    section.Title:SetText(titleText)

    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -22)
    scrollFrame:SetPoint("BOTTOMRIGHT", -20, 0)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(ROW_WIDTH, 1)
    scrollFrame:SetScrollChild(content)

    local emptyLabel = container:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyLabel:SetPoint("CENTER", container, "CENTER", 0, -10)
    emptyLabel:SetText(emptyText)
    emptyLabel:Hide()

    section.ScrollFrame = scrollFrame
    section.ScrollContent = content
    section.EmptyLabel = emptyLabel
    section.rows = {}

    if key == "spellbook" then
        CreateSpellbookFilterDropdown(self, section)
    end

    self.sections[key] = section
    return section
end

local function AcquireRow(self, section, index)
    local rows = section.rows
    local row = rows[index]

    if not row then
        row = CreateFrame("Frame", nil, section.ScrollContent)
        row:SetSize(ROW_WIDTH, ROW_HEIGHT)
        row:EnableMouse(true)

        if index == 1 then
            row:SetPoint("TOPLEFT", section.ScrollContent, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", rows[index - 1], "BOTTOMLEFT", 0, -4)
        end

        local icon = row:CreateTexture(nil, "BACKGROUND")
        icon:SetSize(32, 32)
        icon:SetPoint("LEFT", 0, 0)
        row.Icon = icon

        local spellIdText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        spellIdText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        spellIdText:SetWidth(80)
        spellIdText:SetJustifyH("LEFT")
        row.SpellIDText = spellIdText

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameText:SetPoint("LEFT", spellIdText, "RIGHT", 12, 0)
        nameText:SetJustifyH("LEFT")
        row.NameText = nameText

        if section.key == "profile" or section.key == "spellbook" then
            local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            button:SetPoint("RIGHT", 0, 0)
            button:SetSize(32, 24)
            row.ActionButton = button
        else
            nameText:SetPoint("RIGHT", -4, 0)
        end

        if section.key == "profile" then
            local downButton = CreateFrame("Button", nil, row)
            downButton:SetSize(20, 20)
            downButton:SetPoint("RIGHT", row.ActionButton, "LEFT", -4, 0)
            downButton:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
            downButton:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
            downButton:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight", "ADD")
            downButton:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Disabled")
            row.DownButton = downButton

            local upButton = CreateFrame("Button", nil, row)
            upButton:SetSize(20, 20)
            upButton:SetPoint("RIGHT", downButton, "LEFT", -4, 0)
            upButton:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
            upButton:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Down")
            upButton:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Highlight", "ADD")
            upButton:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Disabled")
            row.UpButton = upButton

            nameText:SetPoint("RIGHT", row.UpButton, "LEFT", -6, 0)
        elseif section.key == "spellbook" and row.ActionButton then
            nameText:SetPoint("RIGHT", row.ActionButton, "LEFT", -6, 0)
        end

        rows[index] = row
    end

    if not row.ActionButton then
        row.NameText:SetPoint("RIGHT", -4, 0)
    end

    return row
end

local function PopulateSection(self, section, entries)
    local numEntries = #entries

    if numEntries == 0 then
        section.EmptyLabel:Show()
    else
        section.EmptyLabel:Hide()
    end

    for i = 1, numEntries do
        local row = AcquireRow(self, section, i)
        local entry = entries[i]

        row.Icon:SetTexture(entry.icon)
        row.SpellIDText:SetText(entry.id)
        row.NameText:SetText(entry.name)
        row.tuiIndex = i

        if row.ActionButton then
            if section.key == "profile" then
                row.ActionButton:SetText("X")
                row.ActionButton:SetWidth(32)
                row.ActionButton:SetScript("OnClick", function()
                    self:RemoveCooldownSpell(entry.id)
                end)
                row.ActionButton:Show()
                if row.UpButton then
                    row.UpButton:SetScript("OnClick", function()
                        self:MoveCooldownEntry(i, -1)
                    end)
                    if i <= 1 then
                        row.UpButton:Disable()
                        row.UpButton:SetAlpha(0.4)
                    else
                        row.UpButton:Enable()
                        row.UpButton:SetAlpha(1)
                    end
                end
                if row.DownButton then
                    row.DownButton:SetScript("OnClick", function()
                        self:MoveCooldownEntry(i, 1)
                    end)
                    if i >= numEntries then
                        row.DownButton:Disable()
                        row.DownButton:SetAlpha(0.4)
                    else
                        row.DownButton:Enable()
                        row.DownButton:SetAlpha(1)
                    end
                end
            elseif section.key == "spellbook" then
                row.ActionButton:SetText("Add")
                row.ActionButton:SetWidth(60)
                row.ActionButton:SetScript("OnClick", function()
                    self:AddCooldownSpell(entry.id)
                end)
                row.ActionButton:Show()
            else
                row.ActionButton:Hide()
            end
        end

        row:Show()
    end

    for i = numEntries + 1, #section.rows do
        if section.rows[i] then
            section.rows[i]:Hide()
        end
    end

    local contentHeight = (numEntries > 0) and (numEntries * (ROW_HEIGHT + 4) - 4) or ROW_HEIGHT
    section.ScrollContent:SetHeight(contentHeight)
    if section.ScrollFrame.ScrollBar then
        section.ScrollFrame.ScrollBar:SetValue(0)
    end
end

function TUI_SpellPicker:RemoveCooldownSpell(spellId)
    local normalizedId = NormalizeSpellId(spellId)
    if not normalizedId then
        return
    end

    local listKey = self:GetSelectedCooldownListKey()

    local currentList = CopyCooldownList(self:GetCooldownList())
    if #currentList == 0 then
        return
    end

    local removed = false
    local updatedList = {}

    for _, entry in ipairs(currentList) do
        if entry.id ~= normalizedId then
            table.insert(updatedList, entry)
        else
            removed = true
        end
    end

    if not removed then
        return
    end

    self:SetCooldownList(updatedList)

    if TUI and TUI.RefreshConfig then
        TUI:RefreshConfig()
    end

    RefreshCooldownFramesForKey(listKey)

    self:RefreshSections()
end

function TUI_SpellPicker:AddCooldownSpell(spellId)
    local normalizedId = NormalizeSpellId(spellId)
    if not normalizedId then
        return
    end

    local listKey = self:GetSelectedCooldownListKey()

    local currentList = CopyCooldownList(self:GetCooldownList())

    for _, entry in ipairs(currentList) do
        if entry.id == normalizedId then
            return
        end
    end

    table.insert(currentList, {
        id = normalizedId,
        type = "spell",
    })

    self:SetCooldownList(currentList)

    if TUI and TUI.RefreshConfig then
        TUI:RefreshConfig()
    end

    RefreshCooldownFramesForKey(listKey)

    self:RefreshSections()
end

function TUI_SpellPicker:MoveCooldownEntry(index, delta)
    if not index or not delta then
        return
    end

    local currentList = CopyCooldownList(self:GetCooldownList())
    local count = #currentList

    if count == 0 or index < 1 or index > count then
        return
    end

    local targetIndex = index + delta
    if targetIndex < 1 or targetIndex > count then
        return
    end

    local entry = table.remove(currentList, index)
    if not entry then
        return
    end

    table.insert(currentList, targetIndex, entry)

    self:SetCooldownList(currentList)

    if TUI and TUI.RefreshConfig then
        TUI:RefreshConfig()
    end

    RefreshCooldownFramesForKey(self:GetSelectedCooldownListKey())

    self:RefreshSections()
end

function TUI_SpellPicker:UpdateSpellbookFilterDropdown()
    if not self.sections then
        return
    end

    local section = self.sections.spellbook
    if not section or not section.FilterDropdown then
        return
    end

    local filterKey = self.spellbookFilter
    if not SPELLBOOK_FILTERS[filterKey] then
        filterKey = "class"
        self.spellbookFilter = filterKey
    end

    local label = SPELLBOOK_FILTERS[filterKey] and SPELLBOOK_FILTERS[filterKey].label or filterKey
    UIDropDownMenu_SetSelectedValue(section.FilterDropdown, filterKey)
    UIDropDownMenu_SetText(section.FilterDropdown, label)
end

function TUI_SpellPicker:SetSpellbookFilter(filterKey)
    if not SPELLBOOK_FILTERS[filterKey] then
        filterKey = "class"
    end

    if self.spellbookFilter == filterKey then
        self:UpdateSpellbookFilterDropdown()
        return
    end

    self.spellbookFilter = filterKey
    self:UpdateSpellbookFilterDropdown()
    self:RefreshSections()
end

function TUI_SpellPicker:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "TUI_SpellPickerFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetBackdrop(BACKDROP_INFO)
    frame:SetBackdropColor(0, 0, 0, 0.85)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame.Title = CreateTitleFontString(frame)
    frame.CloseButton = CreateCloseButton(frame)
    self.sections = {}

    self:CreateCooldownTabs(frame)

    local profileOffset = LEFT_MARGIN + TAB_WIDTH + TAB_SPACING
    CreateSection(self, frame, "profile", "", profileOffset, "No spells configured for this cooldown list.")
    CreateSection(self, frame, "spellbook", "Spellbook Spells", profileOffset + COLUMN_WIDTH + COLUMN_GAP, "No spells found in your spellbook.")
    self:UpdateSpellbookFilterDropdown()

    frame:Hide()

    self.frame = frame

    return frame
end

function TUI_SpellPicker:GetCooldownSpellEntries()
    local entries = {}
    local spellIdSet = {}

    local storedList = CopyCooldownList(self:GetCooldownList())

    for _, data in ipairs(storedList) do
        local id = data.id
        spellIdSet[id] = true

        if data.type == "item" then
            local itemName, _itemLine, _itemQuality, _itemLevel, _itemMinLevel, _itemType, _itemSubType, _itemStackCount, _itemEquipLoc, itemTexture = C_Item.GetItemInfo(id)

            table.insert(entries, {
                id = id,
                icon = itemTexture or DEFAULT_ICON,
                name = itemName or UNKNOWN_SPELL_NAME
            })
        else
            local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id) or {}

            table.insert(entries, {
                id = id,
                icon = spellInfo.iconID or DEFAULT_ICON,
                name = spellInfo.name or UNKNOWN_SPELL_NAME
            })
        end
    end

    return entries, spellIdSet
end

function TUI_SpellPicker:GetSpellBookEntries(excludeIds, filterKey)
    local entries = {}
    local excluded = excludeIds or {}

    if not C_SpellBook then
        return entries
    end

    local activeFilter = filterKey or self.spellbookFilter or "class"
    if not SPELLBOOK_FILTERS[activeFilter] then
        activeFilter = "class"
    end

    local seen = {}

    local function ResolveSpellNameIcon(spellID, name, iconID)
        local resolvedName = name
        local resolvedIcon = iconID

        if (not resolvedName or not resolvedIcon) and C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(spellID)
            if info then
                resolvedName = resolvedName or info.name
                resolvedIcon = resolvedIcon or info.iconID
            end
        end

        if not resolvedName or not resolvedIcon then
            local fallbackName, fallbackIcon
            if GlobalGetSpellInfo then
                local nameResult, _, iconResult = GlobalGetSpellInfo(spellID)
                fallbackName = nameResult
                fallbackIcon = iconResult
            end
            if fallbackName then
                resolvedName = resolvedName or fallbackName
            end
            if fallbackIcon then
                resolvedIcon = resolvedIcon or fallbackIcon
            end
        end

        return resolvedName or UNKNOWN_SPELL_NAME, resolvedIcon or DEFAULT_ICON
    end

    local function ShouldTreatAsPassive(spellID, explicitPassive)
        if explicitPassive ~= nil then
            return explicitPassive
        end

        if IsPassiveSpell then
            local success, result = pcall(IsPassiveSpell, spellID)
            if success and result ~= nil then
                return result
            end
        end

        return false
    end

    local function MaybeAddSpell(spellID, name, iconID, isPassive, category)
        if not spellID or category ~= activeFilter then
            return
        end

        if seen[spellID] or excluded[spellID] then
            return
        end

        if isPassive then
            return
        end

        local resolvedName, resolvedIcon = ResolveSpellNameIcon(spellID, name, iconID)

        table.insert(entries, {
            id = spellID,
            icon = resolvedIcon,
            name = resolvedName
        })

        seen[spellID] = true
    end

    local function ProcessSpellLine(index, bank, category)
        local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(index)
        local offset, numSlots = skillLineInfo.itemIndexOffset, skillLineInfo.numSpellBookItems
        for j = offset+1, offset+numSlots do

            local itemInfo = C_SpellBook.GetSpellBookItemInfo(j, bank)
            local itemType = C_SpellBook.GetSpellBookItemType(j, Enum.SpellBookSpellBank.Player)

            if itemType == ItemTypeSpell then
                if itemInfo then
                    MaybeAddSpell(itemInfo.spellID, itemInfo.name, itemInfo.iconID, itemInfo.isPassive, category)
                end
            elseif itemType == ItemTypeFlyout and itemInfo and itemInfo.actionID and GetFlyoutInfo and GetFlyoutSlotInfo then
                local _, _, numSlots, isKnown = GetFlyoutInfo(itemInfo.actionID)
                if numSlots and numSlots > 0 then
                    for slotIndex = 1, numSlots do
                        local spellID, overrideSpellID, isSlotKnown = GetFlyoutSlotInfo(itemInfo.actionID, slotIndex)
                        if isSlotKnown then
                            local finalSpellID = overrideSpellID and overrideSpellID ~= 0 and overrideSpellID or spellID
                            if finalSpellID then
                                MaybeAddSpell(finalSpellID, nil, nil, nil, category)
                            end
                        end
                    end
                end
            elseif itemInfo and itemInfo.spellID then
                MaybeAddSpell(itemInfo.spellID, itemInfo.name, itemInfo.iconID, itemInfo.isPassive, category)
            end
        end
    end

    local function ProcessSpellSlot(spellBookSlot, bank, category)
        if not category then
            return
        end

        local skillLines = C_SpellBook.GetNumSpellBookSkillLines()

        if category == "class" then
            for i = 2, skillLines do
                ProcessSpellLine(i, bank, category);
            end
        elseif category == "general" then
            ProcessSpellLine(1, bank, category);
        end

        -- for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        --     local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(i)
        --     local offset, numSlots = skillLineInfo.itemIndexOffset, skillLineInfo.numSpellBookItems
        --     for j = offset+1, offset+numSlots do

        --         local itemInfo = C_SpellBook.GetSpellBookItemInfo(j, bank)
        --         local itemType = C_SpellBook.GetSpellBookItemType(j, Enum.SpellBookSpellBank.Player)

        --         if itemType == ItemTypeSpell then
        --             if itemInfo then
        --                 MaybeAddSpell(itemInfo.spellID, itemInfo.name, itemInfo.iconID, itemInfo.isPassive, category)
        --             end
        --         elseif itemType == ItemTypeFlyout and itemInfo and itemInfo.actionID and GetFlyoutInfo and GetFlyoutSlotInfo then
        --             local _, _, numSlots, isKnown = GetFlyoutInfo(itemInfo.actionID)
        --             if numSlots and numSlots > 0 then
        --                 for slotIndex = 1, numSlots do
        --                     local spellID, overrideSpellID, isSlotKnown = GetFlyoutSlotInfo(itemInfo.actionID, slotIndex)
        --                     if isSlotKnown then
        --                         local finalSpellID = overrideSpellID and overrideSpellID ~= 0 and overrideSpellID or spellID
        --                         if finalSpellID then
        --                             MaybeAddSpell(finalSpellID, nil, nil, nil, category)
        --                         end
        --                     end
        --                 end
        --             end
        --         elseif itemInfo and itemInfo.spellID then
        --             MaybeAddSpell(itemInfo.spellID, itemInfo.name, itemInfo.iconID, itemInfo.isPassive, category)
        --         end
        --     end
        -- end

    --     local itemInfo = C_SpellBook.GetSpellBookItemInfo(spellBookSlot, bank)
    --     local itemType = C_SpellBook.GetSpellBookItemType and C_SpellBook.GetSpellBookItemType(spellBookSlot, bank)

    --     if not itemType and itemInfo then
    --         itemType = itemInfo.itemType
    --     end

    --     if not itemType then
    --         return
    --     end

    --     if itemType == ItemTypeSpell then
    --         if itemInfo then
    --             MaybeAddSpell(itemInfo.spellID, itemInfo.name, itemInfo.iconID, itemInfo.isPassive, category)
    --         end
    --     elseif itemType == ItemTypeFlyout and itemInfo and itemInfo.actionID and GetFlyoutInfo and GetFlyoutSlotInfo then
    --         local _, _, numSlots, isKnown = GetFlyoutInfo(itemInfo.actionID)
    --         if numSlots and numSlots > 0 then
    --             for slotIndex = 1, numSlots do
    --                 local spellID, overrideSpellID, isSlotKnown = GetFlyoutSlotInfo(itemInfo.actionID, slotIndex)
    --                 if isSlotKnown then
    --                     local finalSpellID = overrideSpellID and overrideSpellID ~= 0 and overrideSpellID or spellID
    --                     if finalSpellID then
    --                         MaybeAddSpell(finalSpellID, nil, nil, nil, category)
    --                     end
    --                 end
    --             end
    --         end
    --     elseif itemInfo and itemInfo.spellID then
    --         MaybeAddSpell(itemInfo.spellID, itemInfo.name, itemInfo.iconID, itemInfo.isPassive, category)
    --     end
    end

    local function DetermineSkillLineCategory(skillLineInfo)
        if not skillLineInfo or skillLineInfo.shouldHide or skillLineInfo.isGuild then
            return nil
        end

        local specID = skillLineInfo.specID
        local offSpecID = skillLineInfo.offSpecID

        if specID == 0 then
            specID = nil
        end
        if offSpecID == 0 then
            offSpecID = nil
        end

        if not specID and not offSpecID then
            return "general"
        end

        return "class"
    end

    if activeFilter == "pet" then
        if not SpellBankPet or not C_SpellBook.HasPetSpells then
            return entries
        end

        local numPetSpells = C_SpellBook.HasPetSpells()
        if not numPetSpells or numPetSpells <= 0 then
            return entries
        end

        for slotIndex = 1, numPetSpells do
            ProcessSpellSlot(slotIndex, SpellBankPet, "pet")
        end
    else
        if not SpellBankPlayer or not C_SpellBook.GetNumSpellBookSkillLines or not C_SpellBook.GetSpellBookSkillLineInfo then
            return entries
        end

        local numSkillLines = C_SpellBook.GetNumSpellBookSkillLines()
        if not numSkillLines or numSkillLines == 0 then
            return entries
        end

        for skillLineIndex = 1, numSkillLines do
            local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(skillLineIndex)

            local category = DetermineSkillLineCategory(skillLineInfo)

            if category == activeFilter then
                local totalItems = skillLineInfo.numSpellBookItems or 0
                for slotOffset = 1, totalItems do
                    local spellBookSlot = skillLineInfo.itemIndexOffset + slotOffset
                    ProcessSpellSlot(spellBookSlot, SpellBankPlayer, category)
                end
            end
        end
    end

    table.sort(entries, function(left, right)
        if left.name == right.name then
            return left.id < right.id
        end
        return left.name < right.name
    end)

    return entries
end

function TUI_SpellPicker:RefreshSections()
    local frame = self:EnsureFrame()
    local profileSection = self.sections.profile
    local spellbookSection = self.sections.spellbook
    local profileEntries, profileIds = self:GetCooldownSpellEntries()

    self:UpdateCooldownTabSelection()

    if profileSection then
        PopulateSection(self, profileSection, profileEntries)
        if profileSection.Title then
            profileSection.Title:SetText(self:GetSelectedCooldownListLabel())
        end
    end

    if spellbookSection then
        self:UpdateSpellbookFilterDropdown()
        PopulateSection(self, spellbookSection, self:GetSpellBookEntries(profileIds, self.spellbookFilter))
    end
end

function TUI_SpellPicker:Show()
    local frame = self:EnsureFrame()
    self:RefreshSections()
    frame:Show()
    frame:Raise()
end

function TUI_SpellPicker:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function TUI_SpellPicker:Toggle()
    local frame = self:EnsureFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        self:RefreshSections()
        frame:Show()
        frame:Raise()
    end
end


