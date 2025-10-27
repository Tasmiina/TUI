---------------------------------------------------------------------------------------------------
-- Base Mixin for Essential and Utility cooldown items.
TUI_CooldownItemMixin = CreateFromMixins(CooldownViewerItemMixin);

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
	CooldownViewerItemMixin.OnLoad(self);

	self:GetCooldownFrame():SetScript("OnCooldownDone", GenerateClosure(self.OnCooldownDone, self));
end

function TUI_CooldownItemMixin:OnCooldownIDSet()
	CooldownViewerItemMixin.OnCooldownIDSet(self);

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
	CooldownViewerItemMixin.OnCooldownIDCleared(self);

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

	-- Custom highlight instead of ActionButtonSpellAlertManager
	self:ShowCustomHighlight();
end

function TUI_CooldownItemMixin:OnSpellActivationOverlayGlowHideEvent(spellID)
	if not self:NeedSpellActivationUpdate(spellID) then
		return;
	end

	-- Hide custom highlight
	self:HideCustomHighlight();
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
	if self:UseAuraForCooldown() == true then
		local totemData = self:GetTotemData();
		if totemData then
			self.cooldownEnabled = 1;
			self.cooldownStartTime = totemData.expirationTime - totemData.duration;
			self.cooldownDuration = totemData.duration;
			self.cooldownModRate = totemData.modRate;
			self.cooldownSwipeColor = CooldownViewerConstants.ITEM_AURA_COLOR;
			self.cooldownDesaturated = false;
			self.cooldownShowDrawEdge = false;
			self.cooldownShowSwipe = true;
			self.cooldownUseAuraDisplayTime = true;
			self.cooldownPlayFlash = false;
			self.cooldownPaused = false;
			return;
		end

		local auraData = self:GetAuraData();
		if auraData then
			self.cooldownEnabled = 1;
			self.cooldownStartTime = auraData.expirationTime - auraData.duration;
			self.cooldownDuration = auraData.duration;
			self.cooldownModRate = auraData.timeMod;
			self.cooldownSwipeColor = CooldownViewerConstants.ITEM_AURA_COLOR;
			self.cooldownDesaturated = false;
			self.cooldownShowDrawEdge = false;
			self.cooldownShowSwipe = true;
			self.cooldownUseAuraDisplayTime = true;
			self.cooldownPlayFlash = false;
			self.cooldownPaused = false;
			return;
		end
	end

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
		cooldownFrame:SetUseAuraDisplayTime(self.cooldownUseAuraDisplayTime);
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
		self:ShowCustomHighlight();
	else
		self:HideCustomHighlight();
	end
end

function TUI_CooldownItemMixin:ShowCustomHighlight()
	-- Use LibCustomGlow for button glow effect without start animation
	local LibCustomGlow = LibStub("LibCustomGlow-1.0");
	if LibCustomGlow then
		LibCustomGlow.ButtonGlow_Start(self, {1, 1, 0, 0.8}, 0.5); -- Yellow glow with 0.5 frequency
		-- Skip the start animation and go directly to the final glow state
		if self._ButtonGlow and self._ButtonGlow.animIn then
			self._ButtonGlow.animIn:Stop();
			-- Call the finished handler to set final state
			local AnimIn_OnFinished = self._ButtonGlow.animIn:GetScript("OnFinished");
			if AnimIn_OnFinished then
				AnimIn_OnFinished(self._ButtonGlow.animIn);
			end
		end
	end
end

function TUI_CooldownItemMixin:HideCustomHighlight()
	-- Stop LibCustomGlow button glow
	local LibCustomGlow = LibStub("LibCustomGlow-1.0");
	if LibCustomGlow then
		LibCustomGlow.ButtonGlow_Stop(self);
	end
end

function TUI_CooldownItemMixin:RefreshData()
	self:RefreshAuraInstance();
	self:RefreshSpellCooldownInfo();
	self:RefreshSpellChargeInfo();
	self:RefreshSpellTexture();
	self:RefreshIconDesaturation();
	self:RefreshIconColor();
	self:RefreshOverlayGlow();
	self:RefreshActive();
end