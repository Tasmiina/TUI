TUI_CooldownFrame = {};

function TUI_CooldownFrame:GetItemContainerFrame()
    return self;
end

function TUI_CooldownFrame:GetItemFrames()
    return self:GetItemContainerFrame():GetLayoutChildren();
end

function TUI_CooldownFrame:OnLoad()
    local itemResetCallback = function(pool, itemFrame)
        Pool_HideAndClearAnchors(pool, itemFrame);
        itemFrame:ClearCooldownID();
        itemFrame.layoutIndex = nil;
    end;

    self.itemFramePool = CreateFramePool("FRAME", self:GetItemContainerFrame(), self.itemTemplate, itemResetCallback);

    if not self.cooldownListKey then
        self.cooldownListKey = self.cooldownList or "cooldowns_1"
    end

    self.cooldownList = nil
    self.cooldownEntries = {}

	self:UpdateShownState();
end


function TUI_CooldownFrame:CooldownValid(entry)
    if entry.type == "item" then
        return C_Item.IsEquippedItem(entry.id)
    else
        return C_SpellBook.IsSpellInSpellBook(entry.id)
    end
end

function TUI_CooldownFrame:BuildCooldownList()
    local baseList = self:GetCooldownIDsBase()

    self.cooldownEntries = {}

    local seen = {}

    for _, item in ipairs(baseList) do
        local id = tonumber(item.id) or item.id
        if id and not seen[id] and self:CooldownValid(item) then
            table.insert(self.cooldownEntries, {
                id = id,
                type = item.type or "spell"
            })
            seen[id] = true
        end
    end
end

function TUI_CooldownFrame:OnShow()
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN");
	self:RegisterEvent("SPELL_RANGE_CHECK_UPDATE");
    self:RegisterEvent("UNIT_POWER_UPDATE", "player");
    self:RegisterEvent("UNIT_AURA", "player");
    
    self:RegisterEvent("PLAYER_LEVEL_CHANGED")
    self:RegisterEvent("PLAYER_TALENT_UPDATE")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

    self:RefreshLayout();
end

function TUI_CooldownFrame:OnHide()
    self:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
	self:UnregisterEvent("SPELL_RANGE_CHECK_UPDATE");
    self:UnregisterEvent("UNIT_POWER_UPDATE")
    self:UnregisterEvent("UNIT_AURA")

    self:UnregisterEvent("PLAYER_LEVEL_CHANGED")
    self:UnregisterEvent("PLAYER_TALENT_UPDATE")
    self:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
end

function TUI_CooldownFrame:OnEvent(event, ...)
    if event == "SPELL_UPDATE_COOLDOWN" then
        local spellID, baseSpellID, _category, startRecoveryCategory= ...;
        
        for itemFrame in self.itemFramePool:EnumerateActive() do            
            itemFrame:OnSpellUpdateCooldownEvent(spellID, baseSpellID, startRecoveryCategory);
        end
    elseif event == "SPELL_RANGE_CHECK_UPDATE" then
		local spellID, inRange, checksRange = ...;
		for itemFrame in self.itemFramePool:EnumerateActive() do
			itemFrame:OnSpellRangeCheckUpdateEvent(spellID, inRange, checksRange);
		end
    elseif event == "UNIT_POWER_UPDATE" then
        for itemFrame in self.itemFramePool:EnumerateActive() do
            itemFrame:OnPowerUpdate();
        end
    elseif event == "UNIT_AURA" then
        local _unit, unitAuraUpdateInfo = ...;
    elseif event == "PLAYER_LEVEL_CHANGED" then
        self:RefreshLayout();
    elseif event == "PLAYER_TALENT_UPDATE" then
        self:RefreshLayout();
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        self:RefreshLayout();
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        self:RefreshLayout();
    end
end

function TUI_CooldownFrame:ShouldBeShown()
    return true
end

function TUI_CooldownFrame:SetHideWhenInactive(hideWhenInactive)
    if self.hideWhenInactive == hideWhenInactive then
        return;
    end

    self.hideWhenInactive = hideWhenInactive

    for itemFrame in self.itemFramePool:EnumerateActive() do
        itemFrame:SetHideWhenInactive(hideWhenInactive)
    end
end

function TUI_CooldownFrame:GetHideWhenInactive()
    return self.hideWhenInactive;
end

function TUI_CooldownFrame:UpdateShownState()
    local shouldBeShown = self:ShouldBeShown();
    local isShown = self:IsShown();

    if shouldBeShown == isShown then
        return;
    end

    self:SetShown(shouldBeShown);

    if shouldBeShown then
        self:RefreshData();
    end
end

function TUI_CooldownFrame:GetItemCount()
    local cooldownIDs = self:GetCooldownIDs();
    local itemCount = cooldownIDs and #cooldownIDs or 0;

    local minimumItemCount = 2;
    itemCount = math.max(itemCount, minimumItemCount);

    return itemCount;
end

function TUI_CooldownFrame:OnAcquireItemFrame(itemFrame)
    itemFrame.SetViewerFrame(self);
    -- itemFrame.SetScale(1.0);
    -- itemFrame.SetTimerShown(false);
    -- itemFrame.SetTooltipsShown(false);
    -- itemFrame.SetHideWhenInactive(true);
end

function TUI_CooldownFrame:RefreshLayout()
    self:BuildCooldownList();
    self.itemFramePool:ReleaseAll();

    local itemCount = self:GetItemCount();
    for i = 1, itemCount do
        local itemFrame = self.itemFramePool:Acquire();
        itemFrame.layoutIndex = i;

        self:OnAcquireItemFrame(itemFrame);
    end

    if self:IsShown() then
        self:RefreshData();
    end

    self:GetItemContainerFrame():Layout();
end

-- https://warcraft.wiki.gg/wiki/API_C_Item.IsEquippedItem

function TUI_CooldownFrame:GetCooldownIDsBase()
    local listKey = self.cooldownListKey or "cooldowns_1"

    if TUI and TUI.db and TUI.db.profile and TUI.db.profile.spells then
        local configured = TUI.db.profile.spells[listKey]
        if type(configured) == "table" then
            return configured
        end
    end

    return {}
end

function TUI_CooldownFrame:GetCooldownIDs()
    return self.cooldownEntries
end

function TUI_CooldownFrame:RefreshData()
    local cooldownIDs = self:GetCooldownIDs();

    for itemFrame in self.itemFramePool:EnumerateActive() do
        local cooldownID = cooldownIDs and cooldownIDs[itemFrame.layoutIndex];
        if cooldownID then
            itemFrame:SetCooldownID(cooldownID.id, cooldownID.type);
        else
            itemFrame:ClearCooldownID();
        end
    end

    self:GetItemContainerFrame():Layout();
end

function TUI_CooldownFrame:SetTimerShown(shownSetting)
    self.timerShown = shownSetting

    for itemFrame in self.itemFramePool:EnumerateActive() do
        itemFrame:SetTimerShown(shownSetting);
    end
end

function TUI_CooldownFrame:SetTooltipsShown(shownSetting)
    self.tooltipShown = shownSetting

    for itemFrame in self.itemFramePool:EnumerateActive() do
        itemFrame:SetTooltipsShown(shownSetting);
    end
end