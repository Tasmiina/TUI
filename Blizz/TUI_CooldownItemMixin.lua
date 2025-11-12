---------------------------------------------------------------------------------------------------
-- Base Mixin for Essential and Utility cooldown items.
TUI_CooldownItemMixin = CreateFromMixins(CooldownViewerItemMixin);

local function IsSpellOnGCD(spellID, spellCooldownInfo)
	-- Get cooldown information for the dummy GCD spell (ID 61304)
	local gcdInfo = C_Spell.GetSpellCooldown(61304);

	-- Return false if the spell is not on cooldown at all
	if gcdInfo and spellCooldownInfo.duration ~= 0 then
		-- Compare the current cooldown state of the spell with the current GCD state
		-- If the spell's cooldown is the same as the GCD's, and both are active,
		-- then the spell is currently on the GCD.
		if spellCooldownInfo.startTime == gcdInfo.startTime and spellCooldownInfo.duration == gcdInfo.duration then
			return true;
		end
	end

	return false;
end

local function LogCooldown(spellID, functionName, fmt, ...)
	if true then
		local msg = fmt:format(...);
		-- print(("%.2f [%d]: %s : %s"):format(GetTime(), spellID, functionName, msg));
	end
end

local function CheckDisplayCooldownState(functionName, cooldownItem)
	LogCooldown(cooldownItem:GetSpellID(), functionName, "isOnGCD: %s, isEnabled: %s, allowAvailableAlert: %s allowOnCDAlert: %s",
		tostring(cooldownItem.isOnGCD), tostring(cooldownItem.cooldownEnabled),
		tostring(cooldownItem.allowAvailableAlert), tostring(cooldownItem.allowOnCooldownAlert));
end

local function CheckDisplayCooldownInfo(functionName, spellID, cachedInfo)
	if true then
		local isOnGCD = IsSpellOnGCD(spellID, cachedInfo);

		LogCooldown(spellID, functionName, "ST: %.4f, Dur: %.4f, Enabled: %s, Mod: %.4f, Cat: %s, Recovery: %.4f, structOnGCD: %s, hackOnGCD: %s",
			cachedInfo.startTime, cachedInfo.duration, tostring(cachedInfo.isEnabled), cachedInfo.modRate, tostring(cachedInfo.activeCategory),
			(cachedInfo.timeUntilEndOfStartRecovery or 0), tostring(cachedInfo.isOnGCD), tostring(isOnGCD));

		local cdInfo = C_Spell.GetSpellCooldown(spellID);
		assertsafe(cdInfo == cachedInfo or tCompare(cachedInfo, cdInfo), "cd info mismatch");
		assertsafe(cachedInfo.isOnGCD == isOnGCD, "GCD hack mismatch");
	end
end

function TUI_CooldownItemMixin:IsActivelyCast()
	-- This indicates that the spell related to the cooldown item can be cast by the player and isn't a proc.
	return true;
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

	CheckDisplayCooldownState("OnCooldownDone", self);
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

function TUI_CooldownItemMixin:CheckCacheCooldownValuesFromAura(timeNow)
	-- If the spell results in a self buff, give those values precedence over the spell's cooldown until the buff is gone.
	if self:CanUseAuraForCooldown() then
		local totemData = self:GetTotemData();
		if totemData then
			self:AddVisualDataSource_Aura();
			self.cooldownEnabled = true;
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
			return; -- Early return because totems take precedence and we can avoid aura lookup
		end

		local auraData = self:GetAuraData();
		if auraData then
			-- NOTE: Auras are in a priority class where we want to show their cooldown info, but keep the charge count display, but not the charge cooldown display.
			-- This is why auras don't check to see if HasVisualDataSource_Charges is true, but it means that the charge radial swipe will not display.
			self:AddVisualDataSource_Aura();
			self.cooldownEnabled = true;
			self.cooldownStartTime = auraData.expirationTime - auraData.duration;
			self.cooldownDuration = auraData.duration;
			self.cooldownModRate = auraData.timeMod;
			self.cooldownSwipeColor = CooldownViewerConstants.ITEM_AURA_COLOR;
			self.cooldownShowDrawEdge = false;
			self.cooldownShowSwipe = true;
			self.cooldownUseAuraDisplayTime = true;
			self.cooldownPlayFlash = false;
			self.cooldownPaused = false;

			-- This may have already been set by CheckCacheCooldownValuesFromSpellCooldown
			if not self:IsActivelyCast() or self:GetAuraDataUnit() == "player" then
				self.cooldownDesaturated = false;
			end

			if self:CheckSetPandemicAlertTiggerTime(auraData, timeNow) then
				self.cooldownUseAuraDisplayTime = false;
			end
		end
	end
end

function TUI_CooldownItemMixin:CheckCacheCooldownValuesFromCharges(timeNow)
	local spellChargeInfo = self:GetSpellChargeInfo();
	local displayChargeCooldown = spellChargeInfo and (spellChargeInfo.cooldownStartTime or 0) > 0 and (spellChargeInfo.currentCharges or 0) > 0;

	-- If the spell has multiple charges, give those values precedence over the spell's cooldown until the charges are spent.
	if displayChargeCooldown then
		self:AddVisualDataSource_Charges();
		self.cooldownEnabled = true;
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

		if spellChargeInfo.cooldownStartTime > 0 and spellChargeInfo.cooldownDuration > 0 and spellChargeInfo.currentCharges < spellChargeInfo.maxCharges then
			local predictedChargeGainTime = spellChargeInfo.cooldownStartTime + spellChargeInfo.cooldownDuration;
			if predictedChargeGainTime > timeNow then
				self:AddChargeGainedAlertTime(predictedChargeGainTime);
			end
		end
	end
end

local wasOnGCDLookup = {};
local function CheckAllowOnCooldown(cdItem, spellID, spellCooldownInfo)
	local wasOnGCD = wasOnGCDLookup[spellID];
	wasOnGCDLookup[spellID] = cdItem.isOnGCD;

	local allowOnCooldownAlert = wasOnGCD and not cdItem.isOnGCD and spellCooldownInfo.duration > (cdItem.cooldownDuration or 0) and spellCooldownInfo.duration > 0;
	return allowOnCooldownAlert;
end

function TUI_CooldownItemMixin:CheckCacheCooldownValuesFromSpellCooldown(timeNow)
	local spellID = self:GetSpellID();
	local spellCooldownInfo = spellID and C_Spell.GetSpellCooldown(spellID);
	if spellCooldownInfo and not self:HasVisualDataSource_Charges() then
		self:AddVisualDataSource_Cooldown();
		CheckDisplayCooldownInfo("CheckCacheCooldownValuesFromSpellCooldown", spellID, spellCooldownInfo);

		local endTime = spellCooldownInfo.startTime + spellCooldownInfo.duration;
		self.cooldownIsActive = endTime > timeNow;

		self.isOnGCD = spellCooldownInfo.isOnGCD;
		self.isOnActualCooldown = not self.isOnGCD and self.cooldownIsActive;
		self.allowOnCooldownAlert = CheckAllowOnCooldown(self, spellID, spellCooldownInfo);
		self.allowAvailableAlert = self.allowAvailableAlert or (not self.isOnGCD and spellCooldownInfo.duration > 0 and self.cooldownEnabled);
		self.availableAlertTriggerTime = self.allowAvailableAlert and endTime or nil;
		self.cooldownEnabled = spellCooldownInfo.isEnabled;
		self.cooldownStartTime = spellCooldownInfo.startTime;
		self.cooldownDuration = spellCooldownInfo.duration;
		self.cooldownModRate = spellCooldownInfo.modRate;
		self.cooldownSwipeColor = CooldownViewerConstants.ITEM_COOLDOWN_COLOR;
		self.cooldownShowDrawEdge = false;
		self.cooldownShowSwipe = true;
		self.cooldownUseAuraDisplayTime = false;
		self.cooldownPaused = false;
		self.cooldownDesaturated = self.isOnActualCooldown;
		self.cooldownPlayFlash = self.isOnActualCooldown;

		LogCooldown(spellID, "CheckCacheCooldownValuesFromSpellCooldown:ItemData", "Start: %.2f, Duration: %.2f, active: %s", self.cooldownStartTime, self.cooldownDuration, tostring(self.cooldownIsActive));
	end
end

function TUI_CooldownItemMixin:CheckCacheCooldownValuesFromEditMode()
	if self:HasEditModeData() and not self:IsUsingVisualDataSource_Spell() then
		self:AddVisualDataSource_EditMode();
		self.cooldownEnabled = true;
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
	end
end

function TUI_CooldownItemMixin:CacheCooldownValues()
	local timeNow = GetTime();

	-- Cooldowns can be influenced by multiple sources, so check them all
	-- But if any source performed an update, those functions might return early.
	-- The state updates are in "rough" priority order and the call order here actually matters.
	self:CheckCacheCooldownValuesFromCharges(timeNow);
	self:CheckCacheCooldownValuesFromSpellCooldown(timeNow);
	self:CheckCacheCooldownValuesFromAura(timeNow);
	self:CheckCacheCooldownValuesFromEditMode();

	if not self:IsUsingVisualDataSource_Any() then
		self.cooldownEnabled = false;
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
		self.isOnGCD = false;
		self.cooldownIsActive = false;
		self.allowOnCooldownAlert = false;
		self.isOnActualCooldown = false;
	end
end

function TUI_CooldownItemMixin:CacheChargeValues()
	-- Give precedence to spells set up with explicit charge info that have more than one max charge.
	local spellChargeInfo = self:GetSpellChargeInfo();
	if spellChargeInfo and spellChargeInfo.maxCharges > 1 then
		self.cooldownChargesCount = spellChargeInfo.currentCharges;
		self.cooldownChargesShown = true;
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

	CheckDisplayCooldownState("RefreshSpellCooldownInfo", self);

	if self.allowOnCooldownAlert then
		self:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnCooldown);
		self.allowOnCooldownAlert = false;
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
	LogCooldown(self:GetSpellID(), "RefreshIconDesaturation", "%s, expired: %s", tostring(self.cooldownDesaturated), tostring(self:IsExpired()));

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
	self:ClearVisualDataSource();
	self:RefreshAuraInstance();
	self:RefreshSpellCooldownInfo();
	self:RefreshSpellChargeInfo();
	self:RefreshSpellTexture();
	self:RefreshIconDesaturation();
	self:RefreshIconColor();
	self:RefreshOverlayGlow();
	self:RefreshActive();
end
