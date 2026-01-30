local SOTA = SOTAG

--[[
--	Table functions:
--]]
function SOTA:RenumberTable(sourcetable)
    local index = 1;
    local temptable = {};
    for key, value in ipairs(sourcetable) do
        if value and table.getn(value) > 0 then
            temptable[index] = value;
            index = index + 1
        end
    end
    return temptable;
end

function SOTA:SortTableAscending(sourcetable, index)
    local doSort = true
    while doSort do
        doSort = false
        for n = table.getn(sourcetable), 2, -1 do
            local a = sourcetable[n - 1];
            local b = sourcetable[n];
            if (a[index]) > (b[index]) then
                sourcetable[n - 1] = b;
                sourcetable[n] = a;
                doSort = true;
            end
        end
    end
    return sourcetable;
end

function SOTA:SortTableDescending(sourcetable, index)
    local doSort = true
    while doSort do
        doSort = false
        for n = 1, table.getn(sourcetable) - 1, 1 do
            local a = sourcetable[n]
            local b = sourcetable[n + 1]
            if (a[index]) < (b[index]) then
                sourcetable[n] = b
                sourcetable[n + 1] = a
                doSort = true
            end
        end
    end
    return sourcetable;
end

function SOTA:CloneTable(sourcetable)
    local destinationtable = {};
    for n = 1, table.getn(sourcetable), 1 do
        destinationtable[n] = sourcetable[n];
    end
    return destinationtable;
end
