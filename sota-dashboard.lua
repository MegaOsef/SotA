local SOTA = SOTAG

local module = SOTA:NewModule("Dashboard", "AceEvent-2.0")

function module:OnEnable()
	self.statsFrame = getglobal("SOTA_Dash_Stats")

	self:RegisterEvent("SOTA_ITEMPRIOS_UPDATED", "RefreshStats")
	self:ScheduleRepeatingEvent("SOTA_OnSecondTimer", self.OnSecondTimer, 1, self)

	self:RefreshStats()
end

function module:OnSecondTimer()
	if SOTA:IsInRaid(true) then
		if SOTA.db.realm.DisableDashboard == 0 then
			SOTA_OpenDashboard();
		end
	else
		if SOTA.db.realm.DisableDashboard == 0 then
			SOTA_CloseDashboard();
		end
	end
end

function module:RefreshStats()
	self.statsFrame:SetText("Loot prios counter: "..table.getn(SOTA.db.realm.ItemPriorities))
end

function SOTA_OpenDashboard()
	DashboardUIFrame:Show();
end

function SOTA_CloseDashboard()
	DashboardUIFrame:Hide();
end

function SOTA_ShowDashboardToolTip(object, message)
	GameTooltip:SetOwner(object, "ANCHOR_PRESERVE");
	GameTooltip:AddLine(message, 1, 1, 1);
	GameTooltip:Show();
end

function SOTA_HideDashboardToolTip()
	GameTooltip:Hide();
end