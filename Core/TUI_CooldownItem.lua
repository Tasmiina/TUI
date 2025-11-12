TUI_CooldownItem = {};

function TUI_CooldownItem:GetIconTexture()
	return self.Icon;
end

function TUI_CooldownItem:GetChargeCountFrame()
	return self.ChargeCount;
end

function TUI_CooldownItem:GetCooldownFrame()
	return self.Cooldown;
end

function TUI_CooldownItem:GetCooldownFlashFrame()
	return self.CooldownFlash;
end

function TUI_CooldownItem:ShouldBeActive()
	return self.cooldownID ~= nil;
end

function TUI_CooldownItem:GetBaseSpellID()
    return self.cooldownID;
end

function TUI_CooldownItem:GetSpellID()
	return self.cooldownID;
end

function TUI_CooldownItem:IsExpired()
    return false

	-- if self.cooldownEnabled == nil then
    --     return true
    -- end

    -- return self.cooldownEnabled;
end

function TUI_CooldownItem:OnActiveStateChanged()
	self:UpdateShownState();
end

function TUI_CooldownItem:SetIsActive(active)
	if active == self.isActive then
		return;
	end

	self.isActive = active;

	self:OnActiveStateChanged();
end

function TUI_CooldownItem:NeedsCooldownUpdate(spellID, baseSpellID, startRecoveryCategory)
    if spellID == nil then
        return true
    end

    -- Blizz CooldownManager checks for LinkedSpells here

    if startRecoveryCategory == Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY then
		return true;
	end

    local itemBaseSpellID = self:GetBaseSpellID();

	if spellID == itemBaseSpellID then
		return true;
	end

    if baseSpellID == itemBaseSpellID then
        return true;
    end

    if spellID == self:GetSpellID() then
        return true
    end

    -- local cooldownInfo = self:GetCooldownInfo();
	-- if cooldownInfo and spellID == cooldownInfo.previousOverrideSpellID then
	-- 	return true;
	-- end

	return false;
end

function TUI_CooldownItem:OnSpellUpdateCooldownEvent(spellID, baseSpellID, startRecoveryCategory)
	if self:NeedsCooldownUpdate(spellID, baseSpellID, startRecoveryCategory) then
		self:RefreshData();
	end
end

function TUI_CooldownItem:OnPowerUpdate()
	self:RefreshIconDesaturation();
end

function TUI_CooldownItem:ClearCooldownID()
	if self.cooldownID ~= nil then
		self.cooldownID = nil;
		self:OnCooldownIDCleared();
	end
end

function TUI_CooldownItem:SetViewerFrame(viewerFrame)
	self.viewerFrame = viewerFrame;
end

function TUI_CooldownItem:OnCooldownIDCleared()
	self.cooldownInfo = nil;
	self.validAlertTypes = nil;
	-- self:ClearAuraInstanceInfo();
	-- self:ClearTotemData();

	self:RefreshData();
	self:UpdateShownState();
end

function TUI_CooldownItem:SetCooldownID(cooldownID, forceSet)
	if forceSet or self.cooldownID ~= cooldownID then
		self.cooldownID = cooldownID;
		self:OnCooldownIDSet();
	end
end

function TUI_CooldownItem:OnCooldownIDSet()
	-- self.cooldownInfo = CooldownViewerSettings:GetDataProvider():GetCooldownInfoForID(self:GetCooldownID());
	-- self.validAlertTypes = nil;

	-- self:ClearEditModeData();

	-- If one of the item's linked spells currenly has an active aura, it needs to be linked now because
	-- the UNIT_AURA event for it may have already happened and there might not be another one. e.g. the
	-- case of an infinite duration aura.
	-- local linkedSpellID = self:FindLinkedSpellForCurrentAuras();
	-- if linkedSpellID then
	-- 	self:SetLinkedSpell(linkedSpellID);
	-- end

    self:CacheChargeValues();

	self:RefreshData();
	self:UpdateShownState();
end

function TUI_CooldownItem:ClearVisualDataSource()
	self.wasSetFromCharges = false;
	self.wasSetFromCooldown = false;
	self.wasSetFromAura = false;
	self.wasSetFromEditMode = false;
end

function TUI_CooldownItem:GetSpellTexture()
	
	-- Intentionally always use the base spell when calling C_Spell.GetSpellTexture. Its internal logic will handle the override if needed.
	local spellID = self:GetBaseSpellID();
	if spellID then
		return C_Spell.GetSpellTexture(spellID);
	end

	return nil;
end

function TUI_CooldownItem:RefreshSpellTexture()
	local spellTexture = self:GetSpellTexture();
	self:GetIconTexture():SetTexture(spellTexture);
end

function TUI_CooldownItem:RefreshActive()
	self:SetIsActive(self:ShouldBeActive());
end

function TUI_CooldownItem:RefreshSpellChargeInfo()
	-- self:CacheChargeValues();

	local chargeCountFrame = self:GetChargeCountFrame();
	chargeCountFrame:SetShown(self.cooldownChargesShown);

	if self.cooldownChargesShown then
		chargeCountFrame.Current:SetText(self:GetSpellChargeInfo().currentCharges);
	end
end

function TUI_CooldownItem:GetSpellChargeInfo()
	if self.cooldownID then
        return C_Spell.GetSpellCharges(self.cooldownID);
	end

	return nil;
end

function TUI_CooldownItem:CacheChargeValues()
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

function TUI_CooldownItem:RefreshSpellCooldownInfo()
	self:CacheCooldownValues();

	local cooldownFrame = self:GetCooldownFrame();

    -- Would ideally hide this, but this works with secrets so we roll with it
    self:GetCooldownFrame():SetCooldown(self.cooldownStartTime, self.cooldownDuration, self.cooldownModRate)
    self:GetCooldownFrame():SetDrawEdge(self.cooldownShowDrawEdge)

	if self.cooldownPaused then
		cooldownFrame:Pause();
	else
		cooldownFrame:Resume();
	end

	if self.allowOnCooldownAlert then
		self:TriggerAlertEvent(Enum.CooldownViewerAlertEventType.OnCooldown);
		self.allowOnCooldownAlert = false;
	end
end

function TUI_CooldownItem:CacheCooldownValues()
	local timeNow = GetTime();

	-- Cooldowns can be influenced by multiple sources, so check them all
	-- But if any source performed an update, those functions might return early.
	-- The state updates are in "rough" priority order and the call order here actually matters.
	self:CheckCacheCooldownValuesFromCharges(timeNow);
	self:CheckCacheCooldownValuesFromSpellCooldown(timeNow);

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
		-- self.isOnGCD = false;
		self.cooldownIsActive = false;
		self.allowOnCooldownAlert = false;
		self.isOnActualCooldown = false;
	end
end

function TUI_CooldownItem:IsUsingVisualDataSource_Spell()
	return self.wasSetFromCharges or self.wasSetFromCooldown or self.wasSetFromAura;
end

function TUI_CooldownItem:IsUsingVisualDataSource_Any()
	return self:IsUsingVisualDataSource_Spell();
end


function TUI_CooldownItem:AddVisualDataSource_Charges()
	self.wasSetFromCharges = true;
end

function TUI_CooldownItem:HasVisualDataSource_Charges()
	return self.wasSetFromCharges;
end

function TUI_CooldownItem:AddVisualDataSource_Cooldown()
	self.wasSetFromCooldown = true;
end

function TUI_CooldownItem:AddVisualDataSource_Aura()
	self.wasSetFromAura = true;
end

-- local wasOnGCDLookup = {};
-- local function CheckAllowOnCooldown(cdItem, spellID, spellCooldownInfo)
-- 	local wasOnGCD = wasOnGCDLookup[spellID];
-- 	wasOnGCDLookup[spellID] = cdItem.isOnGCD;

-- 	local allowOnCooldownAlert = wasOnGCD and not cdItem.isOnGCD and spellCooldownInfo.duration > (cdItem.cooldownDuration or 0) and spellCooldownInfo.duration > 0;
-- 	return allowOnCooldownAlert;
-- end

function TUI_CooldownItem:CheckCacheCooldownValuesFromSpellCooldown(timeNow)
	local spellID = self:GetSpellID();
	local spellCooldownInfo = spellID and C_Spell.GetSpellCooldown(spellID);
	if spellCooldownInfo and not self:HasVisualDataSource_Charges() then
		self:AddVisualDataSource_Cooldown();

        -- DevTool:AddData(spellCooldownInfo, "SCDI");

		-- local endTime = spellCooldownInfo.startTime + spellCooldownInfo.duration;
		-- self.cooldownIsActive = endTime > timeNow;
		-- self.isOnGCD = spellCooldownInfo.isOnGCD;
		-- self.isOnActualCooldown = not self.isOnGCD and self.cooldownIsActive;
		-- self.allowOnCooldownAlert = CheckAllowOnCooldown(self, spellID, spellCooldownInfo);
		-- self.allowAvailableAlert = self.allowAvailableAlert or (not self.isOnGCD and spellCooldownInfo.duration > 0 and self.cooldownEnabled);
		-- self.availableAlertTriggerTime = self.allowAvailableAlert and endTime or nil;
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
	end
end

function TUI_CooldownItem:AddChargeGainedAlertTime(predictedChargeGainTime)
	local chargeTimes = GetOrCreateTableEntry(self, "chargeGainedAlertTimes", {});
	chargeTimes[predictedChargeGainTime] = true;
end

function TUI_CooldownItem:CheckCacheCooldownValuesFromCharges(timeNow)
	local spellChargeInfo = self:GetSpellChargeInfo();
	-- local displayChargeCooldown = spellChargeInfo and (spellChargeInfo.cooldownStartTime or 0) > 0 and (spellChargeInfo.currentCharges or 0) > 0;

	-- If the spell has multiple charges, give those values precedence over the spell's cooldown until the charges are spent.
	if spellChargeInfo ~= nil then
		self:AddVisualDataSource_Charges();
		self.cooldownEnabled = true;
		self.cooldownStartTime = spellChargeInfo.cooldownStartTime;
		self.cooldownDuration = spellChargeInfo.cooldownDuration;
		self.cooldownModRate = spellChargeInfo.chargeModRate;
		self.cooldownSwipeColor = CooldownViewerConstants.ITEM_COOLDOWN_COLOR;
		self.cooldownDesaturated = spellChargeInfo.currentCharges;
		self.cooldownShowDrawEdge = true;
		self.cooldownShowSwipe = false;
		self.cooldownUseAuraDisplayTime = false;
		self.cooldownPlayFlash = true;
		self.cooldownPaused = false;

        DevTool:AddData(spellChargeInfo, "SCI");

		-- if spellChargeInfo.cooldownStartTime > 0 and spellChargeInfo.cooldownDuration > 0 and spellChargeInfo.currentCharges < spellChargeInfo.maxCharges then
		-- 	local predictedChargeGainTime = spellChargeInfo.cooldownStartTime + spellChargeInfo.cooldownDuration;
		-- 	if predictedChargeGainTime > timeNow then
		-- 		self:AddChargeGainedAlertTime(predictedChargeGainTime);
		-- 	end
		-- end
	end
end

function TUI_CooldownItem:RefreshIconDesaturation()
    self:GetIconTexture():SetDesaturated(not C_Spell.IsSpellUsable(self.cooldownID))
end

function TUI_CooldownItem:RefreshData()
    self:ClearVisualDataSource();
	-- self:RefreshAuraInstance();
	self:RefreshSpellCooldownInfo();
	self:RefreshSpellChargeInfo();
	self:RefreshSpellTexture();
	self:RefreshIconDesaturation();
	-- self:RefreshIconColor();
	-- self:RefreshOverlayGlow();
	self:RefreshActive();
end

function TUI_CooldownItem:UpdateShownState()
    self:SetShown(true)
end

function TUI_CooldownItem:OnLoad()
	-- CooldownViewerItemMixin.OnLoad(self);

	-- self:GetCooldownFrame():SetScript("OnCooldownDone", GenerateClosure(self.OnCooldownDone, self));
end