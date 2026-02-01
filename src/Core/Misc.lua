local SOTA = SOTAG

local QUALITY_COLORS = {
	{0, "Poor",				{ 157,157,157 } },	--9d9d9d
	{1, "Common",			{ 255,255,255 } },	--ffffff
	{2, "Uncommon",			{  30,255,  0 } },	--1eff00
	{3, "Rare",				{   0,112,255 } },	--0070ff
	{4, "Epic",				{ 163, 53,238 } },	--a335ee
	{5, "Legendary",		{ 255,128,  0 } }	--ff8000
}

local CLASS_COLORS = {
	{ "Druid",				{ 255,125, 10 } },	--255 	125 	10		1.00 	0.49 	0.04 	#FF7D0A
	{ "Hunter",				{ 171,212,115 } },	--171 	212 	115 	0.67 	0.83 	0.45 	#ABD473 
	{ "Mage",				{ 105,204,240 } },	--105 	204 	240 	0.41 	0.80 	0.94 	#69CCF0 
	{ "Paladin",			{ 245,140,186 } },	--245 	140 	186 	0.96 	0.55 	0.73 	#F58CBA
	{ "Priest",				{ 255,255,255 } },	--255 	255 	255 	1.00 	1.00 	1.00 	#FFFFFF
	{ "Rogue",				{ 255,245,105 } },	--255 	245 	105 	1.00 	0.96 	0.41 	#FFF569
	{ "Shaman",				{ 245,140,186 } },	--245 	140 	186 	0.96 	0.55 	0.73 	#F58CBA
	{ "Warlock",			{ 148,130,201 } },	--148 	130 	201 	0.58 	0.51 	0.79 	#9482C9
	{ "Warrior",			{ 199,156,110 } }	--199 	156 	110 	0.78 	0.61 	0.43 	#C79C6E
}

--[[
--	Misc. utility functions:
--]]
function SOTA:GetTimestamp()
	return date("%H:%M:%S", time());
end

function SOTA:GetDateTimestamp()
	return date("%Y/%m/%d %H:%M:%S", time());
end

function SOTA:GetDateTimestampId()
	return date("%Y%m%d%H%M%S", time());
end

--[[
--	Convert a msg so first letter is uppercase, and rest as lower case.
--]]
function SOTA:UCFirst(msg)
	if not msg then
		return ""
	end	

	local f = string.sub(msg, 1, 1)
	local r = string.sub(msg, 2)
	return string.upper(f) .. string.lower(r)
end

function SOTA:GetQualityColor(quality)
	for n=1, table.getn(QUALITY_COLORS), 1 do
		local q = QUALITY_COLORS[n];
		if q[1] == quality then
			return q[3]
		end
	end
	
	-- Unknown quality code; can't happen! Let's just return poor quality!
	return QUALITY_COLORS[1][3];
end

function SOTA:GetClassColorCodes(classname)
	local colors = { 128,128,128 }
	classname = self:UCFirst(classname);

	local cc;
	for n=1, table.getn(CLASS_COLORS), 1 do
		cc = CLASS_COLORS[n];
		if cc[1] == classname then
			return cc[2];
		end
	end

	return colors;
end

function SOTA:FindItemPriority(itemId)
	local prioTableCounter = table.getn(SOTA.db.realm.ItemPriorities)
	for n = 1, prioTableCounter, 1 do
		local p = SOTA.db.realm.ItemPriorities[n]
		if p.item_id == itemId then
			return p
		end
	end
	return nil
end

function SOTA:GetItemIDFromLink(itemLink)
	local _, _, itemId = string.find(itemLink, "item:(%d+):")
	return tonumber(itemId)
end

function SOTA:FindBossDkpFromTriggerName(triggerName)
	local bossDkpList = SOTA.db.realm.BossDkpList
	for n = 1, table.getn(bossDkpList), 1 do
		if bossDkpList[n].triggerName == triggerName then
			return bossDkpList[n]
		end
	end
	return nil
end

function SOTA:FormatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor(math.mod(seconds, 3600) / 60)
    local s = math.floor(math.mod(seconds, 60))

    if h > 0 then
        return string.format("%dh %dm %ds", h, m, s)
    elseif m > 0 then
        return string.format("%dm %02ds", m, s)
    else
        return string.format("%ds", s)
    end
end
