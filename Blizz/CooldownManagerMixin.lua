CooldownManagerMixin = {};

-- Largely a copy of the CooldownViewerMixin but with edits to get the layout working as intended

function CooldownManagerMixin:GetItemContainerFrame()
	return self;
end

function CooldownManagerMixin:GetItemFrames()
	local itemContainerFrame = self:GetItemContainerFrame();
	return itemContainerFrame:GetLayoutChildren();
end

function CooldownManagerMixin:OnLoad()
	local itemResetCallback = function(pool, itemFrame)
		Pool_HideAndClearAnchors(pool, itemFrame);
		itemFrame:ClearCooldownID();
		itemFrame.layoutIndex = nil;
	end;
	self.itemFramePool = CreateFramePool("FRAME", self:GetItemContainerFrame(), self.itemTemplate, itemResetCallback);

	self.iconLimit = 1;
	self.iconDirection = Enum.CooldownViewerIconDirection.Right;
	self.iconPadding = 5;
	self.isHorizontal = true;
	self.iconScale = 1;
	self.timerShown = true;
	self.tooltipsShown = true;

	-- Used for quick lookup when handling UNIT_AURA events, requires the items to register/unregister their auraInstanceID when it changes.
	self.auraInstanceIDToItemFramesMap = {};

	self:RegisterEvent("PLAYER_REGEN_ENABLED");
	self:RegisterEvent("PLAYER_REGEN_DISABLED");
	self:RegisterEvent("PLAYER_LEVEL_CHANGED");

	EventRegistry:RegisterFrameEventAndCallback("VARIABLES_LOADED", self.OnVariablesLoaded, self);
	-- CVarCallbackRegistry:RegisterCallback(cooldownViewerEnabledCVar, self.OnCooldownViewerEnabledCVarChanged, self);

	EventRegistry:RegisterCallback("CooldownViewerSettings.OnShow", self.OnViewerSettingsShownStateChange, self);
	EventRegistry:RegisterCallback("CooldownViewerSettings.OnHide", self.OnViewerSettingsShownStateChange, self);

	self:UpdateShownState();

	-- The edit mode selection indicator uses the bounds of the item container to more closely match the player's expectation.
	-- self.Selection:SetAllPoints(self:GetItemContainerFrame());
end

function CooldownManagerMixin:RegisterAuraInstanceIDItemFrame(auraInstanceID, itemFrame)
	if not auraInstanceID then
		return;
	end

	if not self.auraInstanceIDToItemFramesMap[auraInstanceID] then
		self.auraInstanceIDToItemFramesMap[auraInstanceID] = {};
	end

	-- It's rare that two itemFrames use the same auraInstanceID but the data setup allows for it.
	tInsertUnique(self.auraInstanceIDToItemFramesMap[auraInstanceID], itemFrame);
end

function CooldownManagerMixin:UnregisterAuraInstanceIDItemFrame(auraInstanceID, itemFrame)
	tDeleteItem(self.auraInstanceIDToItemFramesMap[auraInstanceID], itemFrame);
end

function CooldownManagerMixin:OnShow()
	-- Events passed directly to the items.
	self:RegisterEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED");
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN");
	self:RegisterUnitEvent("UNIT_AURA", "player");
	self:RegisterEvent("PLAYER_TOTEM_UPDATE");

	local function RefreshFromSettingsUpdate()
		self:RefreshLayout();
	end

	EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", RefreshFromSettingsUpdate, self);
	EventRegistry:RegisterCallback("CooldownViewerSettings.OnSettingsLoaded", RefreshFromSettingsUpdate, self);

	self:RefreshLayout();
end

function CooldownManagerMixin:OnHide()
	-- Events passed directly to the items.
	self:UnregisterEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED");
	self:UnregisterEvent("SPELL_UPDATE_COOLDOWN");
	self:UnregisterEvent("UNIT_AURA");
	self:UnregisterEvent("PLAYER_TOTEM_UPDATE");

	EventRegistry:UnregisterCallback("CooldownViewerSettings.OnDataChanged", self);
	EventRegistry:UnregisterCallback("CooldownViewerSettings.OnSettingsLoaded", self);
end

function CooldownManagerMixin:OnVariablesLoaded()
	self:UpdateShownState();
end

-- function CooldownManagerMixin:OnCooldownViewerEnabledCVarChanged()
-- 	self:UpdateShownState();
-- end

function CooldownManagerMixin:OnEvent(event, ...)
	if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_LEVEL_CHANGED" then
		self:UpdateShownState();
	elseif event == "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED" then
		local baseSpellID, overrideSpellID = ...;
		for itemFrame in self.itemFramePool:EnumerateActive() do
			itemFrame:OnCooldownViewerSpellOverrideUpdatedEvent(baseSpellID, overrideSpellID);
		end
	elseif event =="SPELL_UPDATE_COOLDOWN" then
		local spellID, baseSpellID, _category, startRecoveryCategory = ...;
		for itemFrame in self.itemFramePool:EnumerateActive() do
			itemFrame:OnSpellUpdateCooldownEvent(spellID, baseSpellID, startRecoveryCategory);
		end
	elseif event == "UNIT_AURA" then
		local _unit, unitAuraUpdateInfo = ...;

		if unitAuraUpdateInfo then
			if unitAuraUpdateInfo.removedAuraInstanceIDs then
				for _, auraInstanceID in ipairs(unitAuraUpdateInfo.removedAuraInstanceIDs) do
					local itemFrames = self.auraInstanceIDToItemFramesMap[auraInstanceID];
					if itemFrames then
						for _, itemFrame in ipairs(itemFrames) do
							itemFrame:OnUnitAuraRemovedEvent();
						end
					end
				end
			end

			if unitAuraUpdateInfo.updatedAuraInstanceIDs then
				for _, auraInstanceID in ipairs(unitAuraUpdateInfo.updatedAuraInstanceIDs) do
					local itemFrames = self.auraInstanceIDToItemFramesMap[auraInstanceID];
					if itemFrames then
						for _, itemFrame in ipairs(itemFrames) do
							itemFrame:OnUnitAuraUpdatedEvent();
						end
					end
				end
			end

			if unitAuraUpdateInfo.addedAuras then
				for itemFrame in self.itemFramePool:EnumerateActive() do
					itemFrame:OnUnitAuraAddedEvent(unitAuraUpdateInfo);
				end
			end
		end

		self:RefreshLayout()
	elseif event == "PLAYER_TOTEM_UPDATE" then
		local slot = ...;
		local _haveTotem, name, startTime, duration, _icon, modRate, spellID = GetTotemInfo(slot);
		for itemFrame in self.itemFramePool:EnumerateActive() do
			itemFrame:OnPlayerTotemUpdateEvent(slot, name, startTime, duration, modRate, spellID);
		end
	end
end

function CooldownManagerMixin:ShouldBeShown()
	return true
end

function CooldownManagerMixin:SetIsEditing(isEditing)
	if self.isEditing == isEditing then
		return;
	end

	self.isEditing = isEditing;

	self:RefreshLayout();
	self:UpdateShownState();
end

function CooldownManagerMixin:IsEditing()
	return self.isEditing;
end

function CooldownManagerMixin:SetHideWhenInactive(hideWhenInactive)
	if self.hideWhenInactive == hideWhenInactive then
		return;
	end

	self.hideWhenInactive = hideWhenInactive;

	for itemFrame in self.itemFramePool:EnumerateActive() do
		itemFrame:SetHideWhenInactive(hideWhenInactive);
	end
end

function CooldownManagerMixin:GetHideWhenInactive()
	return self.hideWhenInactive;
end

function CooldownManagerMixin:UpdateShownState()
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

function CooldownManagerMixin:OnViewerSettingsShownStateChange()
	self:UpdateShownState();

	for itemFrame in self.itemFramePool:EnumerateActive() do
		itemFrame:UpdateShownState();
	end
end

function CooldownManagerMixin:GetItemCount()
	local cooldownIDs = self:GetCooldownIDs();
	local itemCount = cooldownIDs and #cooldownIDs or 0;

	local minimumItemCount = 2;
	itemCount = math.max(itemCount, minimumItemCount);

	return itemCount;
end

function CooldownManagerMixin:OnAcquireItemFrame(itemFrame)
	itemFrame:SetViewerFrame(self);
	itemFrame:SetScale(self.iconScale);
	itemFrame:SetTimerShown(self.timerShown);
	itemFrame:SetTooltipsShown(self.tooltipsShown);
	itemFrame:SetHideWhenInactive(self.hideWhenInactive);
	itemFrame:SetIsEditing(self.isEditing);
end

function CooldownManagerMixin:RefreshLayout()
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

function CooldownManagerMixin:GetCategory()
	return self.cooldownViewerCategory;
end

function CooldownManagerMixin:GetCooldownIDs()
	assertsafe(self:GetCategory(), "Cooldown Viewer Category not set");
	return CooldownViewerSettings:GetDataProvider():GetOrderedCooldownIDsForCategory(self:GetCategory());
end

function CooldownManagerMixin:RefreshData()
	local cooldownIDs = self:GetCooldownIDs();

	for itemFrame in self.itemFramePool:EnumerateActive() do
		local cooldownID = cooldownIDs and cooldownIDs[itemFrame.layoutIndex];
		if cooldownID then
			itemFrame:SetCooldownID(cooldownID);
		else
			itemFrame:ClearCooldownID();

			if self:IsEditing() then
				-- Generate a unique number for each item in edit mode that can be used to look up a placeholder texture or generate a fake duration.
				local editModeData = itemFrame.layoutIndex * 5 + self:GetCategory();
				itemFrame:SetEditModeData(editModeData);
			else
				itemFrame:ClearEditModeData();
			end
		end
	end
end

function CooldownManagerMixin:SetTimerShown(shownSetting)
	self.timerShown = shownSetting;

	for itemFrame in self.itemFramePool:EnumerateActive() do
		itemFrame:SetTimerShown(shownSetting);
	end
end

function CooldownManagerMixin:SetTooltipsShown(shownSetting)
	self.tooltipsShown = shownSetting;

	for itemFrame in self.itemFramePool:EnumerateActive() do
		itemFrame:SetTooltipsShown(shownSetting);
	end
end

-----------------------------------------------------------------
TUI_EssentialCooldownViewerMixin = CreateFromMixins(CooldownManagerMixin);

function TUI_EssentialCooldownViewerMixin:OnLoad()
	CooldownManagerMixin.OnLoad(self);
end

function TUI_EssentialCooldownViewerMixin:OnShow()
	LayoutMixin.OnShow(self);
	CooldownManagerMixin.OnShow(self);
end

function TUI_EssentialCooldownViewerMixin:OnHide()
	CooldownManagerMixin.OnHide(self);
end

function TUI_EssentialCooldownViewerMixin:OnEvent(event, ...)
	CooldownManagerMixin.OnEvent(self, event, ...);
end

TUI_UtilityCooldownViewerMixin = CreateFromMixins(CooldownManagerMixin);

function TUI_UtilityCooldownViewerMixin:OnLoad()
	CooldownManagerMixin.OnLoad(self);
end

function TUI_UtilityCooldownViewerMixin:OnShow()
	LayoutMixin.OnShow(self);
	CooldownManagerMixin.OnShow(self);
end

function TUI_UtilityCooldownViewerMixin:OnHide()
	CooldownManagerMixin.OnHide(self);
end

function TUI_UtilityCooldownViewerMixin:OnEvent(event, ...)
	CooldownManagerMixin.OnEvent(self, event, ...);
end

TUI_BarCooldownViewerMixin = CreateFromMixins(CooldownManagerMixin);

function TUI_BarCooldownViewerMixin:OnLoad()
	CooldownManagerMixin.OnLoad(self);

	self.barContent = Enum.CooldownViewerBarContent.IconAndName;
end

function TUI_BarCooldownViewerMixin:OnShow()
	LayoutMixin.OnShow(self);
	CooldownManagerMixin.OnShow(self);
end

function TUI_BarCooldownViewerMixin:OnHide()
	CooldownManagerMixin.OnHide(self);
end

function TUI_BarCooldownViewerMixin:OnEvent(event, ...)
	CooldownManagerMixin.OnEvent(self, event, ...);
end

function TUI_BarCooldownViewerMixin:OnAcquireItemFrame(itemFrame)
	self:SetHideWhenInactive(true)
	CooldownManagerMixin.OnAcquireItemFrame(self, itemFrame);

	itemFrame:SetBarContent(self.barContent);
end

function TUI_BarCooldownViewerMixin:SetBarContent(barContent)
	self.barContent = barContent;

	for itemFrame in self.itemFramePool:EnumerateActive() do
		itemFrame:SetBarContent(barContent);
	end
end

TUI_BuffCooldownViewerMixin = CreateFromMixins(CooldownManagerMixin);

function TUI_BuffCooldownViewerMixin:OnLoad()
	CooldownManagerMixin.OnLoad(self);
	self:SetHideWhenInactive(true)
end

function TUI_BuffCooldownViewerMixin:OnAcquireItemFrame(itemFrame)
	self:SetHideWhenInactive(true)
end

function TUI_BuffCooldownViewerMixin:OnShow()
	LayoutMixin.OnShow(self);
	CooldownManagerMixin.OnShow(self);
end

function TUI_BuffCooldownViewerMixin:OnHide()
	CooldownManagerMixin.OnHide(self);
end

function TUI_BuffCooldownViewerMixin:OnEvent(event, ...)
	CooldownManagerMixin.OnEvent(self, event, ...);
end