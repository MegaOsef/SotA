--[[
--	SotA - State of the Art DKP Addon
--	Custom Dropdown Widget
--
--	Factory for styled dropdown menus matching SotA's visual theme.
--	Relies on XML templates defined in Dropdown.xml:
--		SOTA_DropdownTemplate, SOTA_DropdownOptionTemplate, SOTA_DropdownListTemplate
--
--	Usage:
--		local dd = SOTA:CreateDropdown(name, parent, width, placeholder)
--		dd:SetOptions({{text="BWL", value=1}, ...})
--		dd:SetSelectedValue(value)
--		dd:GetSelectedValue()
--		dd:SetOnChange(function(value, text) end)
--		dd:SetEnabled(true/false)
--		dd:GetFrame()
--]]

local SOTA = SOTAG

-- Mutex: only one dropdown open at a time
SOTA.activeDropdown = nil

local OPTION_HEIGHT = 18

function SOTA:CreateDropdown(name, parent, width, placeholder)
	local dropdown = {}
	dropdown.options = {}
	dropdown.selectedValue = nil
	dropdown.selectedText = nil
	dropdown.placeholder = placeholder or ""
	dropdown.enabled = true
	dropdown.onChange = nil
	dropdown.optionButtons = {}

	-- Header frame from XML template
	local frame = CreateFrame("Frame", name, parent, "SOTA_DropdownTemplate")
	frame:SetWidth(width)
	frame.dropdown = dropdown -- back-reference for XML scripts
	dropdown.frame = frame
	dropdown.headerBG = getglobal(name .. "BG")
	dropdown.headerText = getglobal(name .. "Text")
	dropdown.arrow = getglobal(name .. "Arrow")

	-- Set initial placeholder text
	dropdown.headerText:SetText(placeholder)

	-- Blocker: full-screen transparent button to capture outside clicks
	local blocker = CreateFrame("Button", name .. "Blocker", UIParent)
	blocker:SetAllPoints(UIParent)
	blocker:SetFrameStrata("FULLSCREEN_DIALOG")
	blocker:SetFrameLevel(99)
	blocker:Hide()
	blocker:SetScript("OnClick", function()
		dropdown:Close()
	end)
	dropdown.blocker = blocker

	-- List frame from XML template (parented to UIParent so it overlays everything)
	local listFrame = CreateFrame("Frame", name .. "List", UIParent, "SOTA_DropdownListTemplate")
	listFrame:SetWidth(width)
	listFrame:SetFrameStrata("FULLSCREEN_DIALOG")
	listFrame:SetFrameLevel(100)
	-- Background color handled by $parentBG texture in XML template
	dropdown.listFrame = listFrame

	-- Methods

	function dropdown:UpdateDisplay()
		if self.selectedText then
			self.headerText:SetText(self.selectedText)
			if self.enabled then
				self.headerText:SetTextColor(1, 1, 1)
			else
				self.headerText:SetTextColor(0.5, 0.5, 0.5)
			end
		else
			self.headerText:SetText(self.placeholder)
			if self.enabled then
				self.headerText:SetTextColor(0.7, 0.7, 0.7)
			else
				self.headerText:SetTextColor(0.5, 0.5, 0.5)
			end
		end

		if self.enabled then
			self.headerBG:SetVertexColor(0, 0, 0.5, 1)
		else
			self.headerBG:SetVertexColor(0.2, 0.2, 0.2, 1)
		end
	end

	function dropdown:Open()
		if not self.enabled then
			return
		end

		-- Mutex: close any other open dropdown
		if SOTA.activeDropdown and SOTA.activeDropdown ~= self then
			SOTA.activeDropdown:Close()
		end

		self:BuildOptionsList()
		self.blocker:Show()
		self.listFrame:Show()
		self.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
		SOTA.activeDropdown = self
	end

	function dropdown:Close()
		self.blocker:Hide()
		self.listFrame:Hide()
		self.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
		if SOTA.activeDropdown == self then
			SOTA.activeDropdown = nil
		end
	end

	function dropdown:Toggle()
		if self.listFrame:IsVisible() then
			self:Close()
		else
			self:Open()
		end
	end

	function dropdown:BuildOptionsList()
		local optCount = table.getn(self.options)
		local listHeight = (optCount * OPTION_HEIGHT) + 8

		self.listFrame:SetHeight(listHeight)
		self.listFrame:ClearAllPoints()
		self.listFrame:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT", 0, 2)
		self.listFrame:SetPoint("TOPRIGHT", self.frame, "BOTTOMRIGHT", 0, 2)

		for n = 1, optCount do
			local opt = self.options[n]
			local btn = self.optionButtons[n]

			if not btn then
				local btnName = name .. "Option" .. n
				btn = CreateFrame("Button", btnName, self.listFrame, "SOTA_DropdownOptionTemplate")
				btn.label = getglobal(btnName .. "Text")
				btn.bg = getglobal(btnName .. "BG")
				self.optionButtons[n] = btn
			end

			-- Anchor: full width inside list, stacked vertically
			btn:ClearAllPoints()
			if n == 1 then
				btn:SetPoint("TOPLEFT", self.listFrame, "TOPLEFT", 4, -4)
				btn:SetPoint("TOPRIGHT", self.listFrame, "TOPRIGHT", -4, -4)
			else
				btn:SetPoint("TOPLEFT", self.optionButtons[n - 1], "BOTTOMLEFT", 0, 0)
				btn:SetPoint("TOPRIGHT", self.optionButtons[n - 1], "BOTTOMRIGHT", 0, 0)
			end

			btn.label:SetText(opt.text)
			btn.optionValue = opt.value
			btn.optionText = opt.text

			local dd = self
			btn:SetScript("OnClick", function()
				PlaySound("igMainMenuOptionCheckBoxOn")
				dd:SetSelectedValue(this.optionValue)
				dd:Close()
				if dd.onChange then
					dd.onChange(this.optionValue, this.optionText)
				end
			end)

			btn:Show()
		end

		-- Hide surplus buttons
		for n = optCount + 1, table.getn(self.optionButtons) do
			self.optionButtons[n]:Hide()
		end
	end

	-- Public API

	function dropdown:SetOptions(opts)
		self.options = opts or {}
		if self.selectedValue then
			local found = false
			for n = 1, table.getn(self.options) do
				if self.options[n].value == self.selectedValue then
					found = true
					break
				end
			end
			if not found then
				self.selectedValue = nil
				self.selectedText = nil
			end
		end
		self:UpdateDisplay()
	end

	function dropdown:SetSelectedValue(value)
		if not value or value == 0 then
			self.selectedValue = nil
			self.selectedText = nil
		else
			self.selectedValue = value
			self.selectedText = nil
			for n = 1, table.getn(self.options) do
				if self.options[n].value == value then
					self.selectedText = self.options[n].text
					break
				end
			end
		end
		self:UpdateDisplay()
	end

	function dropdown:GetSelectedValue()
		return self.selectedValue
	end

	function dropdown:SetOnChange(func)
		self.onChange = func
	end

	function dropdown:SetEnabled(enabled)
		self.enabled = enabled
		if not enabled then
			self:Close()
			self.frame:EnableMouse(false)
		else
			self.frame:EnableMouse(true)
		end
		self:UpdateDisplay()
	end

	function dropdown:GetFrame()
		return self.frame
	end

	dropdown:UpdateDisplay()
	return dropdown
end
