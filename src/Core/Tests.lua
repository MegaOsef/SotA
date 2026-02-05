local SOTA = SOTAG

--[[
--	Unit tests for Misc.lua functions
--]]

local TestResults = {
	passed = 0,
	failed = 0,
	tests = {}
}

local function Assert(condition, testName, message)
	if condition then
		TestResults.passed = TestResults.passed + 1
		table.insert(TestResults.tests, {
			name = testName,
			passed = true,
			message = ""
		})
		return true
	else
		TestResults.failed = TestResults.failed + 1
		table.insert(TestResults.tests, {
			name = testName,
			passed = false,
			message = message or "Assertion failed"
		})
		return false
	end
end

local function AssertEquals(actual, expected, testName)
	local passed = actual == expected
	if passed then
		TestResults.passed = TestResults.passed + 1
		table.insert(TestResults.tests, {
			name = testName,
			passed = true,
			message = ""
		})
	else
		TestResults.failed = TestResults.failed + 1
		table.insert(TestResults.tests, {
			name = testName,
			passed = false,
			message = string.format("Expected %s but got %s", tostring(expected), tostring(actual))
		})
	end
	return passed
end

--[[
--	Test: GetTimestamp
--]]
local function Test_GetTimestamp()
	local timestamp = SOTA:GetTimestamp()
	Assert(timestamp ~= nil and timestamp ~= "", "GetTimestamp returns non-empty string", "Timestamp should not be empty")
	Assert(string.find(timestamp, ":") ~= nil, "GetTimestamp contains colons", "Timestamp should contain colons for HH:MM:SS format")
end

--[[
--	Test: GetDateTimestamp
--]]
local function Test_GetDateTimestamp()
	local timestamp = SOTA:GetDateTimestamp()
	Assert(timestamp ~= nil and timestamp ~= "", "GetDateTimestamp returns non-empty string", "Timestamp should not be empty")
	Assert(string.find(timestamp, "/") ~= nil, "GetDateTimestamp contains slashes", "Timestamp should contain date separators")
	Assert(string.find(timestamp, ":") ~= nil, "GetDateTimestamp contains colons", "Timestamp should contain time separators")
end

--[[
--	Test: GetDateTimestampId
--]]
local function Test_GetDateTimestampId()
	local timestamp = SOTA:GetDateTimestampId()
	Assert(timestamp ~= nil and timestamp ~= "", "GetDateTimestampId returns non-empty string", "Timestamp should not be empty")
	Assert(string.len(timestamp) == 14, "GetDateTimestampId has correct length", "ID should be 14 characters (YYYYMMDDHHmmss)")
end

--[[
--	Test: UCFirst
--]]
local function Test_UCFirst()
	AssertEquals(SOTA:UCFirst("hello"), "Hello", "UCFirst capitalizes first letter")
	AssertEquals(SOTA:UCFirst("HELLO"), "Hello", "UCFirst lowercases rest of string")
	AssertEquals(SOTA:UCFirst("hELLO"), "Hello", "UCFirst handles mixed case")
	AssertEquals(SOTA:UCFirst(""), "", "UCFirst handles empty string")
	AssertEquals(SOTA:UCFirst(nil), "", "UCFirst handles nil input")
end

--[[
--	Test: GetQualityColor
--]]
local function Test_GetQualityColor()
	local poorColor = SOTA:GetQualityColor(0)
	Assert(poorColor ~= nil, "GetQualityColor(0) returns color", "Should return color for poor quality")
	--Assert(#poorColor == 3, "GetQualityColor returns RGB tuple", "Color should have 3 components (R,G,B)")
	
	local epicColor = SOTA:GetQualityColor(4)
	Assert(epicColor ~= nil, "GetQualityColor(4) returns color", "Should return color for epic quality")
	
	local unknownColor = SOTA:GetQualityColor(99)
	AssertEquals(unknownColor, poorColor, "GetQualityColor returns poor quality for unknown")
end

--[[
--	Test: GetClassColorCodes
--]]
local function Test_GetClassColorCodes()
	local druidColor = SOTA:GetClassColorCodes("Druid")
	--Assert(druidColor ~= nil and #druidColor == 3, "GetClassColorCodes returns valid RGB for Druid", "Should return RGB tuple")
	
	local hunterColor = SOTA:GetClassColorCodes("HUNTER")
	Assert(hunterColor ~= nil, "GetClassColorCodes handles uppercase class names", "Should find class regardless of case")
	
	local unknownColor = SOTA:GetClassColorCodes("Blargon")
	--Assert(unknownColor ~= nil and #unknownColor == 3, "GetClassColorCodes returns default for unknown class", "Should return gray RGB")
end

--[[
--	Test: GetItemIDFromLink
--]]
local function Test_GetItemIDFromLink()
	local itemLink = "|cff9d9d9d|Hitem:1234:0:0:0:0:0:0:0:1:0|h[Poor Item]|h|r"
	local itemId = SOTA:GetItemIDFromLink(itemLink)
	AssertEquals(itemId, 1234, "GetItemIDFromLink extracts correct item ID")
	
	local invalidLink = "not an item link"
	local invalidId = SOTA:GetItemIDFromLink(invalidLink)
	AssertEquals(invalidId, nil, "GetItemIDFromLink returns nil for invalid link")
end

--[[
--	Test: FormatTime
--]]
local function Test_FormatTime()
	local formatted1 = SOTA:FormatTime(45)
	AssertEquals(formatted1, "45s", "FormatTime formats seconds")
	
	local formatted2 = SOTA:FormatTime(125)
	Assert(string.find(formatted2, "m") ~= nil, "FormatTime shows minutes for larger durations", "Should show minutes")
	
	local formatted3 = SOTA:FormatTime(3661)
	Assert(string.find(formatted3, "h") ~= nil, "FormatTime shows hours for durations >= 1 hour", "Should show hours")
end

--[[
--	Test: RealZoneToRaidName
--]]
local function Test_RealZoneToRaidName()
	local raidName = SOTA:RealZoneToRaidName("Naxxramas")
	AssertEquals(raidName, "Naxxramas", "RealZoneToRaidName finds Naxxramas")
	
	local raidName2 = SOTA:RealZoneToRaidName("Temple of Ahn'Qiraj")
	AssertEquals(raidName2, "Ahn'Qiraj Temple", "RealZoneToRaidName finds Ahn'Qiraj")
	
	local unknownZone = SOTA:RealZoneToRaidName("Unknown Zone")
	AssertEquals(unknownZone, nil, "RealZoneToRaidName returns nil for unknown zone")
end

--[[
--	Run all tests
--]]
function SOTA:RunTests()
	-- Reset results
	TestResults = {
		passed = 0,
		failed = 0,
		tests = {}
	}

	SOTA:Print("========== Running Unit Tests ==========")
	
	Test_GetTimestamp()
	Test_GetDateTimestamp()
	Test_GetDateTimestampId()
	Test_UCFirst()
	Test_GetQualityColor()
	Test_GetClassColorCodes()
	Test_GetItemIDFromLink()
	Test_FormatTime()
	Test_RealZoneToRaidName()

	SOTA:Print("========== Test Results ==========")
	for n = 1, table.getn(TestResults.tests), 1 do
		local test = TestResults.tests[n]
		local status = test.passed and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"
		SOTA:Print(string.format("%s - %s", status, test.name))
		if not test.passed then
			SOTA:Print(string.format("    %s", test.message))
		end
	end
	
	SOTA:Print("========== Summary ==========")
	SOTA:Print(string.format("Passed: |cff00ff00%d|r", TestResults.passed))
	SOTA:Print(string.format("Failed: |cffff0000%d|r", TestResults.failed))
	SOTA:Print(string.format("Total:  %d", TestResults.passed + TestResults.failed))
	
	return TestResults.failed == 0
end
