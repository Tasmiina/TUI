---------------------------------------------------------------------------------------------------
-- Base Mixin for Essential and Utility cooldown items.
TUI_CooldownItemMixin = CreateFromMixins(CooldownViewerItemDataMixin);

function TUI_CooldownItemMixin:GetCooldownFrame()
	return self.Cooldown;
end

function TUI_CooldownItemMixin:GetIconTexture()
	return self.Icon;
end

function TUI_CooldownItemMixin:SetViewerFrame(viewerFrame)
	self.viewerFrame = viewerFrame;
end

function TUI_CooldownItemMixin:SetIsEditing(isEditing)
	self.isEditing = isEditing;
	self:UpdateShownState();
end

function TUI_CooldownItemMixin:IsEditing()
	return self.isEditing;
end

function TUI_CooldownItemMixin:SetEditModeData(index)
	self.editModeIndex = index;
	self:RefreshData();
end

function TUI_CooldownItemMixin:HasEditModeData()
	return self.editModeIndex ~= nil;
end

function TUI_CooldownItemMixin:ClearEditModeData()
	if not self:HasEditModeData() then
		return;
	end

	self.editModeIndex = nil;
	self:RefreshData();
end

function TUI_CooldownItemMixin:OnCooldownViewerSpellOverrideUpdatedEvent(baseSpellID, overrideSpellID)
	-- Any time an override is added or removed the item needs to be synchronously updated so
	-- it correctly responds to unique events happening later in the frame. To reduce redunant work
	-- the whole RefreshData isn't done until a unique event is received.
	if baseSpellID ~= self:GetBaseSpellID() then
		return;
	end

	self:SetOverrideSpell(overrideSpellID);
	self:RefreshData();
end

function TUI_CooldownItemMixin:OnSpellUpdateCooldownEvent(spellID, baseSpellID, startRecoveryCategory)
	if not self:NeedsCooldownUpdate(spellID, baseSpellID, startRecoveryCategory) then
		return;
	end

	self:RefreshData();
end

function TUI_CooldownItemMixin:OnPlayerTotemUpdateEvent(slot, name, startTime, duration, modRate, spellID)
	if not self:NeedsTotemUpdate(slot, spellID) then
		return;
	end

	if duration == 0 then
		self:ClearTotemData();
	else
		self:SetTotemData({
			slot = slot,
			expirationTime = startTime + duration,
			duration = duration,
			name = name,
			modRate = modRate;
		});
	end

	self:RefreshData();
end

function TUI_CooldownItemMixin:GetFallbackSpellTexture()
	if self:HasEditModeData() then
		return GetEditModeIcon(self.editModeIndex);
	end

	return nil;
end

function TUI_CooldownItemMixin:RefreshActive()
	self:SetIsActive(self:ShouldBeActive());
end

function TUI_CooldownItemMixin:RefreshSpellTexture()
	local spellTexture = self:GetSpellTexture();
	self:GetIconTexture():SetTexture(spellTexture);
end

function TUI_CooldownItemMixin:UpdateTooltip()
	if GameTooltip:IsOwned(self) then
		self:RefreshTooltip();
	end
end

function TUI_CooldownItemMixin:SetHideWhenInactive(hideWhenInactive)
	self.hideWhenInactive = hideWhenInactive;
	self:UpdateShownState();
end

function TUI_CooldownItemMixin:ShouldBeShown()
	if self:GetCooldownID() then
		if not self.allowHideWhenInactive then
			return true;
		end

		if not self.hideWhenInactive then
			return true;
		end

		if self:IsActive() then
			return true;
		end

		if CooldownViewerSettings:IsVisible() then
			return true;
		end
	end

	if self:IsEditing() then
		return true;
	end

	return false;
end

function TUI_CooldownItemMixin:UpdateShownState()
	local shouldBeShown = self:ShouldBeShown();
	self:SetShown(shouldBeShown);
end

function TUI_CooldownItemMixin:SetTimerShown(shownSetting)
	local cooldownFrame = self:GetCooldownFrame();
	if cooldownFrame then
		cooldownFrame:SetHideCountdownNumbers(not shownSetting);
	end
end

function TUI_CooldownItemMixin:SetTooltipsShown(shownSetting)
	self:SetMouseClickEnabled(false);
	self:SetMouseMotionEnabled(shownSetting);
end

function TUI_CooldownItemMixin:IsTimerShown()
	local cooldownFrame = self:GetCooldownFrame();
	if cooldownFrame then
		return not cooldownFrame:GetHideCountdownNumbers();
	end
	return false;
end

function TUI_CooldownItemMixin:ShouldBeActive()
	return self.cooldownID ~= nil;
end

function TUI_CooldownItemMixin:OnActiveStateChanged()
	self:UpdateShownState();
end

function TUI_CooldownItemMixin:SetIsActive(active)
	if active == self.isActive then
		return;
	end

	self.isActive = active;

	self:OnActiveStateChanged();
end

function TUI_CooldownItemMixin:IsActive()
	return self.isActive;
end

function TUI_CooldownItemMixin:NeedsCooldownUpdate(spellID, baseSpellID, startRecoveryCategory)
	-- A nil spellID indicates all cooldowns should be updated.
	if spellID == nil then
		return true;
	end

	if self:UpdateLinkedSpell(spellID) then
		return true;
	end

	if startRecoveryCategory == Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY then
		return true;
	end

	local itemBaseSpellID = self:GetBaseSpellID();

	if spellID == itemBaseSpellID then
		return true;
	end

	-- Depending on the order of overrides being applied and removed, the item may already have a
	-- different override spell than the spell being updated. But if the base spell is the same, the
	-- item should still respond to the event.
	if baseSpellID == itemBaseSpellID then
		return true;
	end

	if spellID == self:GetSpellID() then
		return true;
	end

	-- In rare cases, some spells remove their override before the Update Cooldown Event is sent.
	-- When this happens the event doesn't correctly reference the base spell, so this logic
	-- compensates for that to ensure the event causes a refresh.
	local cooldownInfo = self:GetCooldownInfo();
	if cooldownInfo and spellID == cooldownInfo.previousOverrideSpellID then
		return true;
	end

	return false;
end

function TUI_CooldownItemMixin:NeedsTotemUpdate(slot, spellID)
	if self:UpdateLinkedSpell(spellID) then
		return true;
	end

	if spellID == self:GetSpellID() then
		return true;
	end

	-- If a totem is destroyed the totem's spellID may already be set to 0, in which case
	-- it's necessary to use the slot to determine if the update is needed.
	local totemData = self:GetTotemData();
	if spellID == 0 and totemData and totemData.slot == slot then
		return true;
	end

	return false;
end

function TUI_CooldownItemMixin:GetChargeCountFrame()
	return self.ChargeCount;
end

function TUI_CooldownItemMixin:GetCooldownFlashFrame()
	return self.CooldownFlash;
end

function TUI_CooldownItemMixin:GetOutOfRangeTexture()
	return self.OutOfRange;
end

function TUI_CooldownItemMixin:OnLoad()
	CooldownViewerItemDataMixin.OnLoad(self);

	self:GetCooldownFrame():SetScript("OnCooldownDone", GenerateClosure(self.OnCooldownDone, self));
end

function TUI_CooldownItemMixin:OnCooldownIDSet()
	CooldownViewerItemDataMixin.OnCooldownIDSet(self);

	self:RefreshOverlayGlow();

	local baseSpellID = self:GetBaseSpellID();
	self.needsRangeCheck = baseSpellID and C_Spell.SpellHasRange(baseSpellID);
	if self.needsRangeCheck == true then
		self.rangeCheckSpellID = baseSpellID;
		C_Spell.EnableSpellRangeCheck(self.rangeCheckSpellID, true);
		self.spellOutOfRange = C_Spell.IsSpellInRange(self.rangeCheckSpellID) == false;
		self:RegisterEvent("SPELL_RANGE_CHECK_UPDATE");
		self:RefreshIconColor();
	end
end

function TUI_CooldownItemMixin:OnCooldownIDCleared()
	CooldownViewerItemDataMixin.OnCooldownIDCleared(self);

	ActionButtonSpellAlertManager:HideAlert(self);

	if self.needsRangeCheck == true then
		C_Spell.EnableSpellRangeCheck(self.rangeCheckSpellID, false);
		self:UnregisterEvent("SPELL_RANGE_CHECK_UPDATE");
		self.rangeCheckSpellID = nil;
		self.spellOutOfRange = nil;
	end
end

function TUI_CooldownItemMixin:OnCooldownDone()
	-- No external event is dispatched when a totem finishes, but if the totem duration was shorter
	-- than the spell's cooldown, the item should immediately start displaying the cooldown.
	local totemData = self:GetTotemData();
	if totemData and totemData.expirationTime < GetTime() then
		self:ClearTotemData();
		self:RefreshData();
	else
		self:RefreshIconDesaturation();
	end
end

function TUI_CooldownItemMixin:OnSpellActivationOverlayGlowShowEvent(spellID)
	if not self:NeedSpellActivationUpdate(spellID) then
		return;
	end

	ActionButtonSpellAlertManager:ShowAlert(self);
end

function TUI_CooldownItemMixin:OnSpellActivationOverlayGlowHideEvent(spellID)
	if not self:NeedSpellActivationUpdate(spellID) then
		return;
	end

	ActionButtonSpellAlertManager:HideAlert(self);
end

function TUI_CooldownItemMixin:OnSpellUpdateUsesEvent(spellID, baseSpellID)
	if not self:NeedSpellUseUpdate(spellID, baseSpellID) then
		return;
	end

	self:RefreshSpellChargeInfo();
end

function TUI_CooldownItemMixin:OnSpellUpdateUsableEvent()
	self:RefreshIconColor();
end

function TUI_CooldownItemMixin:OnSpellRangeCheckUpdateEvent(spellID, inRange, checksRange)
	if not self:NeedsSpellRangeUpdate(spellID) then
		return;
	end

	self.spellOutOfRange = checksRange == true and inRange == false;
	self:RefreshIconColor();
end

function TUI_CooldownItemMixin:NeedSpellActivationUpdate(spellID)
	if spellID == self:GetSpellID() then
		return true;
	end

	return false;
end

function TUI_CooldownItemMixin:NeedSpellUseUpdate(spellID, baseSpellID)
	if spellID == self:GetSpellID() then
		return true;
	end

	if baseSpellID and baseSpellID == self:GetBaseSpellID() then
		return true;
	end

	return false;
end

function TUI_CooldownItemMixin:NeedsSpellRangeUpdate(spellID)
	if spellID == self.rangeCheckSpellID then
		return true;
	end

	return false;
end

function TUI_CooldownItemMixin:CacheCooldownValues()
	-- If the spell results in a self buff, give those values precedence over the spell's cooldown until the buff is gone.
	-- Aura functionality removed - only using spell cooldown info
	local spellChargeInfo = self:GetSpellChargeInfo();
	local displayChargeCooldown = spellChargeInfo
		and spellChargeInfo.cooldownStartTime
		and spellChargeInfo.cooldownStartTime > 0
		and spellChargeInfo.currentCharges
		and spellChargeInfo.currentCharges > 0;

	-- If the spell has multiple charges, give those values precedence over the spell's cooldown until the charges are spent.
	if displayChargeCooldown then
		self.cooldownEnabled = 1;
		self.cooldownStartTime = spellChargeInfo.cooldownStartTime;
		self.cooldownDuration = spellChargeInfo.cooldownDuration;
		self.cooldownModRate = spellChargeInfo.chargeModRate;
		self.cooldownSwipeColor = CooldownViewerConstants.ITEM_COOLDOWN_COLOR;
		self.cooldownDesaturated = false;
		self.cooldownShowDrawEdge = true;
		self.cooldownShowSwipe = false;
		self.cooldownUseAuraDisplayTime = false;
		self.cooldownPlayFlash = true;
		self.cooldownPaused = false;
		return;
	end

	local spellCooldownInfo = self:GetSpellCooldownInfo();
	if spellCooldownInfo then
		self.cooldownEnabled = spellCooldownInfo.isEnabled;
		self.cooldownStartTime = spellCooldownInfo.startTime;
		self.cooldownDuration = spellCooldownInfo.duration;
		self.cooldownModRate = spellCooldownInfo.modRate;
		self.cooldownSwipeColor = CooldownViewerConstants.ITEM_COOLDOWN_COLOR;
		self.cooldownShowDrawEdge = false;
		self.cooldownShowSwipe = true;
		self.cooldownUseAuraDisplayTime = false;
		self.cooldownPaused = false;

		if spellCooldownInfo.activeCategory == Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY then
			self.cooldownDesaturated = false;
			self.cooldownPlayFlash = false;
		else
			self.cooldownDesaturated = true;
			self.cooldownPlayFlash = true;
		end

		return;
	end

	if self:HasEditModeData() then
		self.cooldownEnabled = 1;
		self.cooldownStartTime = GetTime() - GetEditModeElapsedTime(self.editModeIndex);
		self.cooldownDuration = GetEditModeDuration(self.editModeIndex);
		self.cooldownModRate = 1;
		self.cooldownSwipeColor = CooldownViewerConstants.ITEM_COOLDOWN_COLOR;
		self.cooldownDesaturated = false;
		self.cooldownShowDrawEdge = false;
		self.cooldownShowSwipe = true;
		self.cooldownUseAuraDisplayTime = false;
		self.cooldownPlayFlash = false;
		self.cooldownPaused = true;
		return;
	end

	self.cooldownEnabled = 0;
	self.cooldownStartTime = 0;
	self.cooldownDuration = 0;
	self.cooldownModRate = 1;
	self.cooldownSwipeColor = CooldownViewerConstants.ITEM_COOLDOWN_COLOR;
	self.cooldownDesaturated = false;
	self.cooldownShowDrawEdge = false;
	self.cooldownShowSwipe = false;
	self.cooldownUseAuraDisplayTime = false;
	self.cooldownPlayFlash = false;
	self.cooldownPaused = false;
end

function TUI_CooldownItemMixin:CacheChargeValues()
	-- Give precedence to spells set up with explicit charge info that have more than one max charge.
	local spellChargeInfo = self:GetSpellChargeInfo();
	if spellChargeInfo and spellChargeInfo.maxCharges > 1 then
		self.cooldownChargesShown = true;
		self.cooldownChargesCount = spellChargeInfo.currentCharges;
		return;
	end

	-- Some spells are set up to show 'cast count' (also called 'use count') which can have different meanings base on the context of the spell.
	local spellID = self:GetSpellID();
	if spellID then
		self.cooldownChargesCount = C_Spell.GetSpellCastCount(spellID);
		self.cooldownChargesShown = self.cooldownChargesCount > 0;
		return;
	end

	self.cooldownChargesShown = false;
end

function TUI_CooldownItemMixin:IsExpired()
	if self.cooldownStartTime == 0 then
		return true;
	end

	return self.cooldownStartTime + self.cooldownDuration <= GetTime();
end

function TUI_CooldownItemMixin:RefreshSpellCooldownInfo()
	self:CacheCooldownValues();

	local cooldownFrame = self:GetCooldownFrame();
	local isExpired = self:IsExpired();

	if isExpired then
		CooldownFrame_Clear(cooldownFrame);
		cooldownFrame:SetDrawEdge(false);
	else
		cooldownFrame:SetSwipeColor(self.cooldownSwipeColor.r, self.cooldownSwipeColor.g, self.cooldownSwipeColor.b, self.cooldownSwipeColor.a);
		cooldownFrame:SetDrawSwipe(self.cooldownShowSwipe);
		CooldownFrame_Set(cooldownFrame, self.cooldownStartTime, self.cooldownDuration, self.cooldownEnabled, self.cooldownShowDrawEdge, self.cooldownModRate);
	end

	if self.cooldownPaused then
		cooldownFrame:Pause();
	else
		cooldownFrame:Resume();
	end

	local cooldownFlashFrame = self:GetCooldownFlashFrame();
	local playFlash = self.cooldownPlayFlash and not isExpired;

	if playFlash then
		local startDelay = self.cooldownStartTime + self.cooldownDuration - GetTime() - 0.75;

		cooldownFlashFrame:Show();
		cooldownFlashFrame.FlashAnim:Stop();
		cooldownFlashFrame.FlashAnim.ShowAnim:SetStartDelay(startDelay);
		cooldownFlashFrame.FlashAnim.PlayAnim:SetStartDelay(startDelay);
		cooldownFlashFrame.FlashAnim:Play();
	else
		cooldownFlashFrame:Hide();
		cooldownFlashFrame.FlashAnim:Stop();
	end
end

function TUI_CooldownItemMixin:RefreshSpellChargeInfo()
	self:CacheChargeValues();

	local chargeCountFrame = self:GetChargeCountFrame();

	chargeCountFrame:SetShown(self.cooldownChargesShown);

	if self.cooldownChargesShown then
		chargeCountFrame.Current:SetText(self.cooldownChargesCount);
	end
end

function TUI_CooldownItemMixin:RefreshIconDesaturation()
	local iconTexture = self:GetIconTexture();
	local desaturated = self.cooldownDesaturated and not self:IsExpired();

	iconTexture:SetDesaturated(desaturated);
end

function TUI_CooldownItemMixin:RefreshIconColor()
	local spellID = self:GetSpellID();
	if not spellID then
		return;
	end

	local iconTexture = self:GetIconTexture();
	local outOfRangeTexture = self:GetOutOfRangeTexture();

	local isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellID);

	if self.spellOutOfRange == true then
		iconTexture:SetVertexColor(CooldownViewerConstants.ITEM_NOT_IN_RANGE_COLOR:GetRGBA());
	elseif isUsable then
		iconTexture:SetVertexColor(CooldownViewerConstants.ITEM_USABLE_COLOR:GetRGBA());
	elseif notEnoughMana then
		iconTexture:SetVertexColor(CooldownViewerConstants.ITEM_NOT_ENOUGH_MANA_COLOR:GetRGBA());
	else
		iconTexture:SetVertexColor(CooldownViewerConstants.ITEM_NOT_USABLE_COLOR:GetRGBA());
	end

	outOfRangeTexture:SetShown(self.spellOutOfRange == true);
end

function TUI_CooldownItemMixin:RefreshOverlayGlow()
	local spellID = self:GetSpellID();
	local isSpellOverlayed = spellID and C_SpellActivationOverlay.IsSpellOverlayed(spellID) or false;
	if isSpellOverlayed then
		ActionButtonSpellAlertManager:ShowAlert(self);
	else
		ActionButtonSpellAlertManager:HideAlert(self);
	end
end

function TUI_CooldownItemMixin:RefreshData()
	self:RefreshSpellCooldownInfo();
	self:RefreshSpellChargeInfo();
	self:RefreshSpellTexture();
	self:RefreshIconDesaturation();
	self:RefreshIconColor();
	self:RefreshOverlayGlow();
	self:RefreshActive();
end