-- json.lua - Simple JSON encoder/decoder pour WoW 1.12

local SOTA = SOTAG

local json = {}
SOTA.json = json

-------------------------------------------------
-- Utilitaires
-------------------------------------------------

local function isArray(t)
    local max = 0
    local count = 0
    for k, _ in pairs(t) do
        if type(k) ~= "number" then
            return false
        end
        if k > max then
            max = k
        end
        count = count + 1
    end
    if max == 0 then
        return false
    end
    return max == count
end

local function escapeString(s)
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, "\"", "\\\"")
    s = string.gsub(s, "\b", "\\b")
    s = string.gsub(s, "\f", "\\f")
    s = string.gsub(s, "\n", "\\n")
    s = string.gsub(s, "\r", "\\r")
    s = string.gsub(s, "\t", "\\t")
    return s
end

-------------------------------------------------
-- Encode
-------------------------------------------------

local function encodeValue(v, out)
    local t = type(v)

    if t == "nil" then
        table.insert(out, "null")

    elseif t == "boolean" then
        table.insert(out, v and "true" or "false")

    elseif t == "number" then
        -- JSON n'aime pas NaN/inf, on les force à null
        --SOTA:Print("Encoding number:", v)
        --if v ~= v or v == math.huge or v == -math.huge then
        --    table.insert(out, "null")
        --else
            table.insert(out, tostring(v))
        --end

    elseif t == "string" then
        table.insert(out, "\"")
        table.insert(out, escapeString(v))
        table.insert(out, "\"")

    elseif t == "table" then
        if isArray(v) then
            table.insert(out, "[")
            local first = true
            local i = 1
            while v[i] ~= nil do
                if not first then
                    table.insert(out, ",")
                end
                first = false
                encodeValue(v[i], out)
                i = i + 1
            end
            table.insert(out, "]")
        else
            table.insert(out, "{")
            local first = true
            for k, val in pairs(v) do
                if type(k) ~= "string" then
                    -- JSON objet: clés string uniquement, on ignore le reste
                else
                    if not first then
                        table.insert(out, ",")
                    end
                    first = false
                    table.insert(out, "\"")
                    table.insert(out, escapeString(k))
                    table.insert(out, "\":")
                    encodeValue(val, out)
                end
            end
            table.insert(out, "}")
        end

    else
        -- Types non supportés -> null
        table.insert(out, "null")
    end
end

function json.encode(v)
    local out = {}
    encodeValue(v, out)
    return table.concat(out)
end

-------------------------------------------------
-- Decode
-------------------------------------------------

local function skipSpaces(s, i)
    local l = string.len(s)
    while i <= l do
        local c = string.sub(s, i, i)
        if c ~= " " and c ~= "\t" and c ~= "\n" and c ~= "\r" then
            break
        end
        i = i + 1
    end
    return i
end

local function parseLiteral(s, i, literal, value)
    if string.sub(s, i, i + string.len(literal) - 1) == literal then
        return value, i + string.len(literal)
    end
    return nil, i, "invalid literal"
end

local function parseNumber(s, i)
    local l = string.len(s)
    local start = i
    local c = string.sub(s, i, i)

    if c == "-" then
        i = i + 1
    end

    while i <= l do
        c = string.sub(s, i, i)
        if c < "0" or c > "9" then
            break
        end
        i = i + 1
    end

    if i <= l and string.sub(s, i, i) == "." then
        i = i + 1
        while i <= l do
            c = string.sub(s, i, i)
            if c < "0" or c > "9" then
                break
            end
            i = i + 1
        end
    end

    if i <= l then
        c = string.sub(s, i, i)
        if c == "e" or c == "E" then
            i = i + 1
            c = string.sub(s, i, i)
            if c == "+" or c == "-" then
                i = i + 1
            end
            while i <= l do
                c = string.sub(s, i, i)
                if c < "0" or c > "9" then
                    break
                end
                i = i + 1
            end
        end
    end

    local numStr = string.sub(s, start, i - 1)
    local num = tonumber(numStr)
    if not num then
        return nil, i, "invalid number"
    end
    return num, i
end

local function parseString(s, i)
    local l = string.len(s)
    local out = {}

    -- on suppose que s[i] == '"'
    i = i + 1

    while i <= l do
        local c = string.sub(s, i, i)
        if c == "\"" then
            return table.concat(out), i + 1
        elseif c == "\\" then
            i = i + 1
            if i > l then
                return nil, i, "unterminated escape"
            end
            c = string.sub(s, i, i)
            if c == "\"" then
                table.insert(out, "\"")
            elseif c == "\\" then
                table.insert(out, "\\")
            elseif c == "/" then
                table.insert(out, "/")
            elseif c == "b" then
                table.insert(out, "\b")
            elseif c == "f" then
                table.insert(out, "\f")
            elseif c == "n" then
                table.insert(out, "\n")
            elseif c == "r" then
                table.insert(out, "\r")
            elseif c == "t" then
                table.insert(out, "\t")
            elseif c == "u" then
                -- On ignore les séquences \uXXXX (on les laisse brutes)
                -- On lit 4 hex et on les jette
                local hex = string.sub(s, i + 1, i + 4)
                if string.len(hex) < 4 then
                    return nil, i, "invalid unicode escape"
                end
                -- pas de vraie conversion, on met juste "?" pour marquer
                table.insert(out, "?")
                i = i + 4
            else
                -- escape inconnu
                table.insert(out, c)
            end
        else
            table.insert(out, c)
        end
        i = i + 1
    end

    return nil, i, "unterminated string"
end

local parseValue -- forward

local function parseArray(s, i)
    local arr = {}
    i = i + 1 -- skip '['
    i = skipSpaces(s, i)

    local c = string.sub(s, i, i)
    if c == "]" then
        return arr, i + 1
    end

    local idx = 1
    while true do
        local val
        val, i, err = parseValue(s, i)
        if err then return nil, i, err end
        arr[idx] = val
        idx = idx + 1

        i = skipSpaces(s, i)
        c = string.sub(s, i, i)
        if c == "]" then
            return arr, i + 1
        elseif c ~= "," then
            return nil, i, "expected ',' or ']' in array"
        end
        i = i + 1
        i = skipSpaces(s, i)
    end
end

local function parseObject(s, i)
    local obj = {}
    i = i + 1 -- skip '{'
    i = skipSpaces(s, i)

    local c = string.sub(s, i, i)
    if c == "}" then
        return obj, i + 1
    end

    while true do
        if string.sub(s, i, i) ~= "\"" then
            return nil, i, "expected string key"
        end
        local key
        key, i, err = parseString(s, i)
        if err then return nil, i, err end

        i = skipSpaces(s, i)
        if string.sub(s, i, i) ~= ":" then
            return nil, i, "expected ':' after key"
        end
        i = i + 1
        i = skipSpaces(s, i)

        local val
        val, i, err = parseValue(s, i)
        if err then return nil, i, err end
        obj[key] = val

        i = skipSpaces(s, i)
        c = string.sub(s, i, i)
        if c == "}" then
            return obj, i + 1
        elseif c ~= "," then
            return nil, i, "expected ',' or '}' in object"
        end
        i = i + 1
        i = skipSpaces(s, i)
    end
end

function parseValue(s, i)
    i = skipSpaces(s, i)
    local c = string.sub(s, i, i)

    if c == "{" then
        return parseObject(s, i)
    elseif c == "[" then
        return parseArray(s, i)
    elseif c == "\"" then
        return parseString(s, i)
    elseif c == "t" then
        return parseLiteral(s, i, "true", true)
    elseif c == "f" then
        return parseLiteral(s, i, "false", false)
    elseif c == "n" then
        return parseLiteral(s, i, "null", nil)
    else
        -- nombre ?
        if c == "-" or (c >= "0" and c <= "9") then
            return parseNumber(s, i)
        end
    end

    return nil, i, "unexpected character '" .. (c or "") .. "'"
end

function json.decode(s)
    local v, i, err = parseValue(s, 1)
    if err then
        return nil, err
    end
    i = skipSpaces(s, i)
    if i <= string.len(s) then
        -- Il reste des trucs après le JSON
        return nil, "trailing characters after JSON value"
    end
    return v
end
