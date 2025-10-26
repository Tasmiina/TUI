TUI_AuraBuffItemMixin = CreateFromMixins(CooldownViewerBuffItemMixin);

function TUI_AuraBuffItemMixin:GetCooldownFrame()
	return self.CooldownText;
end

function TUI_AuraBuffItemMixin:GetApplicationsFrame()
	return self.Applications;
end

function TUI_AuraBuffItemMixin:GetApplicationsFontString()
	local applicationsFrame = self:GetApplicationsFrame();
	return applicationsFrame.Applications;
end

function TUI_AuraBuffItemMixin:GetCooldownTextFrame()
	return self.CooldownText;
end

function TUI_AuraBuffItemMixin:GetCooldownTextFontString()
	local cooldownFrame = self:GetCooldownTextFrame();
	return cooldownFrame.Text;
end

function TUI_AuraBuffItemMixin:OnLoad()
	CooldownViewerBuffItemMixin.OnLoad(self);
	self:SetScript("OnUpdate", self.OnUpdate);
end

function TUI_AuraBuffItemMixin:OnUpdate(elapsed)
	self:RefreshCooldownText();
end

function TUI_AuraBuffItemMixin:OnCooldownDone()
	self:RefreshActive();
end

function TUI_AuraBuffItemMixin:RefreshCooldownText()
	local cooldownTextFrame = self:GetCooldownTextFrame();
	local cooldownTextFontString = self:GetCooldownTextFontString();
	
	if not cooldownTextFrame or not cooldownTextFontString then
		return;
	end

	local expirationTime, duration, timeMod, paused = self:GetCooldownValues();
	local currentTime = expirationTime - GetTime();

	if currentTime > 0 and not paused then
		local timeText;
		if currentTime >= 60 then
			local minutes = math.floor(currentTime / 60);
			local seconds = math.floor(currentTime % 60);
			timeText = string.format("%d:%02d", minutes, seconds);
		else
			timeText = string.format("%.1f", currentTime);
		end
		
		cooldownTextFontString:SetText(timeText);
		cooldownTextFontString:SetTextColor(1, 1, 1, 1);
		
		cooldownTextFontString:ClearAllPoints();
		cooldownTextFontString:SetPoint("TOP", cooldownTextFrame, "TOP", 0, 8);
		
		cooldownTextFrame:Show();
	else
		cooldownTextFontString:SetText("");
		cooldownTextFrame:Hide();
	end
end

function TUI_AuraBuffItemMixin:RefreshApplications()
	local applicationsText = self:GetApplicationsText();

	local applicationsFontString = self:GetApplicationsFontString();
	applicationsFontString:SetText(applicationsText);
	
	if applicationsText and applicationsText ~= "" then
		applicationsFontString:ClearAllPoints();
		applicationsFontString:SetPoint("BOTTOM", self.Applications, "BOTTOM", 0, -8);
	end
end

function TUI_AuraBuffItemMixin:RefreshData()
	self:RefreshAuraInstance();
	self:RefreshCooldownText();
	self:RefreshSpellTexture();
	self:RefreshApplications();
	self:RefreshActive();
end