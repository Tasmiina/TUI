
TUI_GridFrameMixin = {}

local function IsLayoutFrame(frame)
	return frame.IsLayoutFrame and frame:IsLayoutFrame();
end

function TUI_GridFrameMixin:Layout()
	local layoutChildren = self:GetLayoutChildren();
	if not self:ShouldUpdateLayout(layoutChildren) then
		return;
	end

    local total = #layoutChildren
    
    local xCount = 0

    local xOffset = 0
    local yOffset = 0

    local rowTotal = 1

    local localWidth = 1
    local localHeight = 1
    local currentRow = 0

    for childIndex, child in ipairs(self:GetLayoutChildren()) do
		-- skipChildLayout is to prevent menus from calling Layout on children
		-- that have potentially had their extents overwritten by the menu. Their
		-- extents have already been accounted for.
		if not self.skipChildLayout and IsLayoutFrame(child) then
			child:Layout();
		end

		local i = childIndex

        if i <= self.firstRowLimit then
            localWidth = self.firstRowSizeX
            localHeight = self.firstRowSizeY

            xCount = i

            if total <= self.firstRowLimit then
                rowTotal = total
            else
                rowTotal = self.firstRowLimit
            end

        elseif i <= self.rowLimit + self.firstRowLimit then
            localWidth = self.rowSizeX
            localHeight = self.rowSizeY
            currentRow = 1

            xCount = i - self.firstRowLimit

            if total <= self.firstRowLimit + self.rowLimit then
                rowTotal = total - self.firstRowLimit
            else
                rowTotal = self.rowLimit
            end
        else
            localWidth = self.rowSizeX
            localHeight = self.rowSizeY
            currentRow = 2
            rowTotal = total - self.firstRowLimit - self.rowLimit

            xCount = i - (self.rowLimit + self.firstRowLimit)
        end

        child:SetWidth(localWidth)
        child:SetHeight(localHeight)
        child:SetFrameStrata("LOW")

        xCount = xCount - 1

        xOffset = 0 - (localWidth + self.spacingX) / 2 * (rowTotal-1) + (xCount * (localWidth + self.spacingX))

        local dir_multiplier = -1
        if self.growDirectionUp then
            dir_multiplier = 1
        end

        if currentRow >= 1 then
            yOffset = self.firstRowSizeY + ((currentRow - 1) * self.rowSizeY) + (self.spacingY * (currentRow - 1))
        end

        yOffset = dir_multiplier * yOffset

        local anchor = "TOP"
        if self.growDirectionUp then
            anchor = "BOTTOM"
        end

        child:ClearAllPoints()
        child:SetPoint(anchor, self:GetItemContainerFrame(), anchor, xOffset, yOffset)
	end

    ResizeLayoutMixin.Layout(self);
	self:CacheLayoutSettings(layoutChildren);
end

function TUI_GridFrameMixin:CacheLayoutSettings(layoutChildren)
    self.oldGridSettings = {
		layoutChildren = layoutChildren;
        childXPadding = self.childXPadding;
		childYPadding = self.childYPadding;
		isHorizontal = self.isHorizontal;
		stride = self.stride;
		layoutFramesGoingRight = self.layoutFramesGoingRight;
		layoutFramesGoingUp = self.layoutFramesGoingUp;
    };
end

function TUI_GridFrameMixin:ShouldUpdateLayout(layoutChildren)
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
	or self.oldGridSettings.firstRowLimit ~= self.firstRowLimit
	or self.oldGridSettings.firstRowSizeX ~= self.firstRowSizeX
    or self.oldGridSettings.firstRowSizeY ~= self.firstRowSizeY
    or self.oldGridSettings.rowLimit ~= self.rowLimit
    or self.oldGridSettings.rowSizeX ~= self.rowSizeX
    or self.oldGridSettings.rowSizeY ~= self.rowSizeY
    or self.oldGridSettings.spacingX ~= self.spacingX
    or self.oldGridSettings.spacingY ~= self.spacingY
    or self.oldGridSettings.growDirectionUp ~= self.growDirectionUp then
        return true;
    end

    for index, child in ipairs(layoutChildren) do
        if self.oldGridSettings.layoutChildren[index] ~= child then
            return true;
        end
    end

    return false;
end

function TUI_GridFrameMixin:IgnoreLayoutIndex()
	return false;
end