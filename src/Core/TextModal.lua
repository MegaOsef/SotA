local SOTA = SOTAG

local textModalCallback = nil

function SOTA:OpenTextModal(onValidate)
	local frame = getglobal("SOTA_TextModal")
	local editBox = getglobal("SOTA_TextModalScrollFrameMessage")
	local validateBtn = getglobal("SOTA_TextModalScrollFrameValidate")

	editBox:SetText("")
	validateBtn:Show()
	textModalCallback = onValidate
	frame:Show()
end

function SOTA:OpenTextModalReadOnly(text)
	local frame = getglobal("SOTA_TextModal")
	local editBox = getglobal("SOTA_TextModalScrollFrameMessage")
	local validateBtn = getglobal("SOTA_TextModalScrollFrameValidate")

	editBox:SetText(text or "")
	validateBtn:Hide()
	textModalCallback = nil
	frame:Show()
end

function SOTA_TextModal_validate()
	if textModalCallback then
		local editBox = getglobal("SOTA_TextModalScrollFrameMessage")
		local text = editBox:GetText()
		textModalCallback(text)
	end
	SOTA_TextModal_close()
end

function SOTA_TextModal_close()
	getglobal("SOTA_TextModal"):Hide()
	textModalCallback = nil
end
