local SOTA = SOTAG

local module = SOTA:NewModule("MinimapButton", "AceEvent-2.0")

local BUTTON_RADIUS = 80

local function GetMinimapButtonPosition(angle)
	local rads = math.rad(angle)
	local x = math.cos(rads) * BUTTON_RADIUS
	local y = math.sin(rads) * BUTTON_RADIUS
	return x, y
end

local function UpdateButtonPosition(button)
	local angle = SOTA.db.realm.MinimapButtonAngle
	local x, y = GetMinimapButtonPosition(angle)
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function module:OnEnable()
	local button = getglobal("SOTAMinimapButton")
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")

	UpdateButtonPosition(button)
	self.button = button
end

function SOTAMinimapButton_OnClick()
	if arg1 == "RightButton" then
		SOTA_OpenConfigurationUI()
		return
	end

	if SOTA.db.realm.DisableDashboard == 0 then
		SOTA.db.realm.DisableDashboard = 1
		SOTA_CloseDashboard()
	else
		SOTA.db.realm.DisableDashboard = 0
		SOTA_OpenDashboard()
	end
end

function SOTAMinimapButton_OnDragStart()
	module:ScheduleRepeatingEvent("SOTA_MinimapButtonDrag", module.OnDragUpdate, 0.04, module)
end

function SOTAMinimapButton_OnDragStop()
	module:CancelScheduledEvent("SOTA_MinimapButtonDrag")
end

function module:OnDragUpdate()
	local button = self.button

	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	cx = cx / scale
	cy = cy / scale

	local angle = math.deg(math.atan2(cy - my, cx - mx))
	SOTA.db.realm.MinimapButtonAngle = angle

	button:ClearAllPoints()
	UpdateButtonPosition(button)
end

function SOTAMinimapButton_OnEnter()
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:AddLine("SOTA - DKP Manager", 1, 0.82, 0)
	GameTooltip:AddLine("Left-click: Toggle Dashboard", 0, 1, 0)
	GameTooltip:AddLine("Right-click: Options", 0, 1, 0)
	GameTooltip:AddLine("Drag: Move this button", 0, 1, 0)
	GameTooltip:Show()
end
