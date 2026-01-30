local SOTA = SOTAG

--
--	Job Control
--
function SOTA:AddJob(method, arg1, arg2)
    SOTA:Print("New job in queue")
    self.jobQueue[table.getn(self.jobQueue) + 1] = { method, arg1, arg2 }
end

function SOTA:GetNextJob()
    local job
    local cnt = table.getn(self.jobQueue)

    if cnt > 0 then
        job = self.jobQueue[1]
        for n = 2, cnt, 1 do
            self.jobQueue[n - 1] = self.jobQueue[n]
        end
        self.jobQueue[cnt] = nil
    end

    return job
end
