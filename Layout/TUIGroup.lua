
TUI_GroupFrameMixin = {}

local function IsLayoutFrame(frame)
	return frame.IsLayoutFrame and frame:IsLayoutFrame();
end

function TUI_GroupFrameMixin:Layout()
    local layoutChildren = self:GetLayoutChildren();
	if not self:ShouldUpdateLayout(layoutChildren) then
		return;
	end

    local total = #layoutChildren

    for childIndex, child in ipairs(self:GetLayoutChildren()) do
        if not self.skipChildLayout and IsLayoutFrame(child) then
            child:Layout();
        end

        child:SetWidth(self.childSizeX)
        child:SetHeight(self.childSizeY)

        local elementSize = self.childSizeY
        if self.horizontal then elementSize = self.childSizeY end

        -- local offsetPosition = (elementSize + self.spacing) * (childIndex - 1)

        local offsetPosition = 0 - (elementSize + self.spacing) / 2 * (total-1) + ((childIndex - 1) * (elementSize + self.spacing))

        child:ClearAllPoints()
        if self.horizontal then
            child:SetPoint("CENTER", self:GetItemContainerFrame(), "CENTER", offsetPosition, 0)
        else
            child:SetPoint("CENTER", self:GetItemContainerFrame(), "CENTER", 0, offsetPosition)
        end
        
    end

    ResizeLayoutMixin.Layout(self);
	self:CacheLayoutSettings(layoutChildren);
end

function TUI_GroupFrameMixin:CacheLayoutSettings(layoutChildren)
    self.oldGridSettings = {
		layoutChildren = layoutChildren;
        childSizeX = self.childSizeX;
		childSizeY = self.childSizeY;
		spacing = self.spacing;
		horizontal = self.horizontal;
    };
end

function TUI_GroupFrameMixin:ShouldUpdateLayout(layoutChildren)
    if not self:IsShown() then
        return false;
    end

	if self.alwaysUpdateLayout then
		return true;
	end

    if self.oldGridSettings == nil then
        return true;
    end

    if #self.oldGridSettings.layoutChildren ~= #layoutChildren
	or self.oldGridSettings.childSizeX ~= self.childSizeX
	or self.oldGridSettings.childSizeY ~= self.childSizeY
    or self.oldGridSettings.spacing ~= self.spacing
    or self.oldGridSettings.horizontal ~= self.horizontal then
        return true;
    end

    for index, child in ipairs(layoutChildren) do
        if self.oldGridSettings.layoutChildren[index] ~= child then
            return true;
        end
    end

    return false;
end

function TUI_GroupFrameMixin:IgnoreLayoutIndex()
	return false;
end