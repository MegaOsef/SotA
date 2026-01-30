local SOTA = SOTAG

local SOTA_TITLE						= "SotA"

function SOTA:Broadcast(channel, msg)
    if msg and channel and msg ~= "" then
        SendChatMessage(string.format("[%s] %s", SOTA_TITLE, msg), channel);
    end
end

function SOTA:Whisper(receiver, msg)
    if receiver == UnitName("player") then
        self:Print(msg);
    else
        SendChatMessage(msg, "WHISPER", nil, receiver);
    end
end
