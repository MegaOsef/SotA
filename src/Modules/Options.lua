local SOTA = SOTAG

local module = SOTA:NewModule("Options", "AceEvent-2.0")

local ConfigurationDialogOpen	= false;

function module:OnEnable()
	getglobal("FrameConfigBiddingDisableDashboard"):SetChecked(SOTA.db.realm.DisableDashboard);
	self.prioLoadedStr = getglobal("FrameConfigBiddingPrioLoadedStr");
	self.bossDkpLoadedStr = getglobal("FrameConfigBiddingBossDkpLoadedStr");

	self:RefreshStrings()
end

function module:RefreshStrings()
	self.prioLoadedStr:SetText("Loaded: " .. table.getn(SOTA.db.realm.ItemPriorities) .. " items")
	self.bossDkpLoadedStr:SetText("Loaded: " .. table.getn(SOTA.db.realm.BossDkpList) .. " bosses")
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

	
	--	Store DKP in Public Notes:		
	if checkboxname == "FrameConfigMiscDkpPublicNotes" then
		if checkbox:GetChecked() then
			SOTA.db.realm.UseGuildNotes = SOTA_GUILDNOTE.USEPUBLIC;
		else
			SOTA.db.realm.UseGuildNotes = SOTA_GUILDNOTE.USEOFFICER;
		end
		return;
	end
end

-------------------------------
--- Boss DKP List Import/Export

function SOTA_Conf_ImportBossDkpList_close()
	getglobal("SOTA_ConfigurationImportBossDkpList"):Hide()
end

function SOTA_Conf_ImportBossDkpList_open()
	getglobal("SOTA_ConfigurationImportBossDkpList"):Show()
end

function SOTA_Conf_ImportBossDkpList_import()
	local jsonstr = getglobal("SOTA_ConfigurationImportBossDkpListScrollFrameMessage"):GetText()
	local bossDkpList, err = SOTA.json.decode(jsonstr)
	if not bossDkpList then
		SOTA:Print("Error while trying to parse json:", err)
		return
	end
	SOTA:Print("Imported boss dkp list with", table.getn(bossDkpList.bosses), "entries.")

	SOTA.db.realm.BossDkpList = bossDkpList.bosses
	module:RefreshStrings()

	getglobal("SOTA_ConfigurationImportBossDkpList"):Hide()
end

-------------------------------
--- Item Priorities Import/Export

function SOTA_Conf_ImportItemPriorities_close()
	getglobal("SOTA_ConfigurationImportItemPriorities"):Hide()
end

function SOTA_Conf_ImportItemPriorities_open()
	getglobal("SOTA_ConfigurationImportItemPriorities"):Show()
end

function SOTA_Conf_ImportItemPriorities_import()
	local jsonstr = getglobal("SOTA_ConfigurationImportItemPrioritiesScrollFrameMessage"):GetText()
	local itemPriorities, err = SOTA.json.decode(jsonstr)
	if not itemPriorities then
		SOTA:Print("Error while trying to parse json:", err)
		return
	end

	SOTA.db.realm.ItemPriorities = itemPriorities.items
	module:RefreshStrings()
	getglobal("SOTA_ConfigurationImportItemPriorities"):Hide()
end
