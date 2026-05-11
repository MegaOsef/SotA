local SOTA = SOTAG

local module = SOTA:NewModule("Options", "AceEvent-3.0")

local ConfigurationDialogOpen	= false;

function module:OnEnable()
	getglobal("FrameConfigBiddingDisableDashboard"):SetChecked(SOTA.db.realm.DisableDashboard);
	getglobal("FrameConfigBiddingAutoAssignLoot"):SetChecked(SOTA.db.realm.AutoAssignLoot);
	getglobal("FrameConfigBiddingDryRunAssignLoot"):SetChecked(SOTA.db.realm.DryRunAssignLoot);
	self.prioLoadedStr = getglobal("FrameConfigBiddingPrioLoadedStr");
	self.bossDkpLoadedStr = getglobal("FrameConfigBiddingBossDkpLoadedStr");
	self.guildRosterRolesLoadedStr = getglobal("FrameConfigBiddingGuildRosterRolesLoadedStr");

	getglobal("FrameConfigBiddingEnableDebug"):SetChecked(SOTA.db.realm.IsDebugging);

	self:RefreshStrings()
end

function module:RefreshStrings()
	self.bossDkpLoadedStr:SetText(table.getn(SOTA.db.realm.BossDkpList) .. " bosses")
	self.prioLoadedStr:SetText(table.getn(SOTA.db.realm.ItemPriorities) .. " items")
	self.guildRosterRolesLoadedStr:SetText(table.getn(SOTA.db.realm.GuildRosterRoles) .. " players")
end

function SOTA_OpenConfigurationUI()
	FrameConfigBidding:Show();
end

function SOTA_CloseConfigurationUI()
	FrameConfigBidding:Hide();
end

function SOTA_HandleCheckbox(checkbox)
	local checkboxname = checkbox:GetName();

	--	Disable Dashboard:
	if checkboxname == "FrameConfigBiddingDisableDashboard" then
		if checkbox:GetChecked() then
			SOTA.db.realm.DisableDashboard = 1;
			SOTA_CloseDashboard();
		else
			SOTA.db.realm.DisableDashboard = 0;
		end
		return;
	end


	--	Auto-assign loot to auction winner:
	if checkboxname == "FrameConfigBiddingAutoAssignLoot" then
		if checkbox:GetChecked() then
			SOTA.db.realm.AutoAssignLoot = 1;
		else
			SOTA.db.realm.AutoAssignLoot = 0;
		end
		return;
	end

	--	Dry run loot assignment (print instead of assign):
	if checkboxname == "FrameConfigBiddingDryRunAssignLoot" then
		if checkbox:GetChecked() then
			SOTA.db.realm.DryRunAssignLoot = 1;
		else
			SOTA.db.realm.DryRunAssignLoot = 0;
		end
		return;
	end

	--	Enable Debug Mode:
	if checkboxname == "FrameConfigBiddingEnableDebug" then
		if checkbox:GetChecked() then
			SOTA.db.realm.IsDebugging = true
		else
			SOTA.db.realm.IsDebugging = false
		end
		return;
	end
end

-------------------------------
--- Boss DKP List Import/Export

function SOTA_Conf_ImportBossDkpList_open()
	SOTA:OpenTextModal(function(jsonstr)
		local bossDkpList, err = SOTA.json.decode(jsonstr)
		if not bossDkpList then
			SOTA:Print("Error while trying to parse json:", err)
			return
		end
		SOTA:Print("Imported boss dkp list with", table.getn(bossDkpList), "entries.")
		SOTA.db.realm.BossDkpList = bossDkpList
		module:RefreshStrings()
	end)
end

-------------------------------
--- Item Priorities Import/Export

function SOTA_Conf_ImportItemPriorities_open()
	SOTA:OpenTextModal(function(jsonstr)
		local itemPriorities, err = SOTA.json.decode(jsonstr)
		if not itemPriorities then
			SOTA:Print("Error while trying to parse json:", err)
			return
		end
		SOTA.db.realm.ItemPriorities = itemPriorities.items
		module:RefreshStrings()
	end)
end


-------------------------------
--- Guild Roster Roles Import

function SOTA_Conf_ImportGuildRosterRoles_open()
	SOTA:OpenTextModal(function(jsonstr)
		local guildRosterRoles, err = SOTA.json.decode(jsonstr)
		if not guildRosterRoles then
			SOTA:Print("Error while trying to parse json:", err)
			return
		end
		for n = 1, table.getn(guildRosterRoles), 1 do
			guildRosterRoles[n].name = SOTA:UCFirst(guildRosterRoles[n].name)
		end
		SOTA:Print("Imported guild roster roles with", table.getn(guildRosterRoles), "entries.")
		SOTA.db.realm.GuildRosterRoles = guildRosterRoles
		module:RefreshStrings()

		-- Reset and re-check raid against new config
		local dashboard = SOTA:GetModule("Dashboard", true)
		if dashboard then
			dashboard.warnedPlayers = {}
			dashboard:CheckRaidAgainstConfig()
		end
	end)
end

function SOTA:GetPlayerGuildRosterRole(playerName)
	playerName = SOTA:UCFirst(playerName)
	for n = 1, table.getn(SOTA.db.realm.GuildRosterRoles), 1 do
		if SOTA.db.realm.GuildRosterRoles[n].name == playerName then
			return SOTA.db.realm.GuildRosterRoles[n]
		end
	end
	return nil
end

-------------------------------
--- Guild Extract Module

function SOTA_Conf_ExportPlayersDKP_open()
	module:SendMessage("SOTA_GUILDEXTRACT_REQUEST")
end

-------------------------------
--- Transaction Import Module
function SOTA_Conf_TransactionImport_open()
	module:SendMessage("SOTA_IMPORTTOEXEC_REQUEST")
end
