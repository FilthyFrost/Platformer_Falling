--[[
    Minimal JSON encoder/decoder for Cave Fall Editor
    Supports: strings, numbers, booleans, null, arrays, objects
    No external dependencies.
]]

local json = {}

-- Encode Lua value to JSON string
function json.encode(val)
    local t = type(val)
    if val == nil then
        return "null"
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "number" then
        if val ~= val then return "null" end -- NaN
        if val == math.huge or val == -math.huge then return "null" end
        return tostring(val)
    elseif t == "string" then
        -- Escape special characters
        local escaped = val:gsub('[\\"\b\f\n\r\t]', {
            ["\\"] = "\\\\", ['"'] = '\\"',
            ["\b"] = "\\b", ["\f"] = "\\f",
            ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t",
        })
        return '"' .. escaped .. '"'
    elseif t == "table" then
        -- Detect array vs object
        local isArray = true
        local maxIndex = 0
        for k, _ in pairs(val) do
            if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
                isArray = false
                break
            end
            if k > maxIndex then maxIndex = k end
        end
        if isArray and maxIndex == #val then
            -- Array
            local parts = {}
            for i = 1, #val do
                parts[i] = json.encode(val[i])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            -- Object
            local parts = {}
            for k, v in pairs(val) do
                local key = type(k) == "string" and k or tostring(k)
                table.insert(parts, json.encode(key) .. ":" .. json.encode(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

-- Pretty-print JSON with indentation
function json.encodePretty(val, indent)
    indent = indent or ""
    local nextIndent = indent .. "  "
    local t = type(val)

    if t ~= "table" then
        return json.encode(val)
    end

    -- Detect array vs object
    local isArray = true
    local maxIndex = 0
    for k, _ in pairs(val) do
        if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
            isArray = false
            break
        end
        if k > maxIndex then maxIndex = k end
    end
    if isArray and maxIndex == #val then
        if #val == 0 then return "[]" end
        local parts = {}
        for i = 1, #val do
            parts[i] = nextIndent .. json.encodePretty(val[i], nextIndent)
        end
        return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
    else
        local parts = {}
        -- Sort keys for consistent output
        local keys = {}
        for k in pairs(val) do table.insert(keys, k) end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            local key = type(k) == "string" and k or tostring(k)
            table.insert(parts, nextIndent .. json.encode(key) .. ": " .. json.encodePretty(val[k], nextIndent))
        end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
    end
end

-- Decode JSON string to Lua value
function json.decode(str)
    local pos = 1

    local function skipWhitespace()
        pos = str:find("[^ \t\n\r]", pos) or (#str + 1)
    end

    local function peek()
        skipWhitespace()
        return str:sub(pos, pos)
    end

    local function consume(expected)
        skipWhitespace()
        if str:sub(pos, pos) ~= expected then
            error("JSON: expected '" .. expected .. "' at position " .. pos)
        end
        pos = pos + 1
    end

    local parseValue -- forward declaration

    local function parseString()
        consume('"')
        local result = {}
        while pos <= #str do
            local c = str:sub(pos, pos)
            pos = pos + 1
            if c == '"' then
                return table.concat(result)
            elseif c == '\\' then
                local esc = str:sub(pos, pos)
                pos = pos + 1
                if esc == '"' then table.insert(result, '"')
                elseif esc == '\\' then table.insert(result, '\\')
                elseif esc == '/' then table.insert(result, '/')
                elseif esc == 'b' then table.insert(result, '\b')
                elseif esc == 'f' then table.insert(result, '\f')
                elseif esc == 'n' then table.insert(result, '\n')
                elseif esc == 'r' then table.insert(result, '\r')
                elseif esc == 't' then table.insert(result, '\t')
                elseif esc == 'u' then
                    local hex = str:sub(pos, pos + 3)
                    pos = pos + 4
                    local code = tonumber(hex, 16)
                    if code < 128 then
                        table.insert(result, string.char(code))
                    end
                end
            else
                table.insert(result, c)
            end
        end
        error("JSON: unterminated string")
    end

    local function parseNumber()
        skipWhitespace()
        local startPos = pos
        if str:sub(pos, pos) == '-' then pos = pos + 1 end
        while str:sub(pos, pos):match("[%d%.eE%+%-]") do pos = pos + 1 end
        local numStr = str:sub(startPos, pos - 1)
        return tonumber(numStr)
    end

    local function parseArray()
        consume('[')
        local arr = {}
        if peek() == ']' then pos = pos + 1; return arr end
        while true do
            table.insert(arr, parseValue())
            skipWhitespace()
            if str:sub(pos, pos) == ']' then pos = pos + 1; return arr end
            consume(',')
        end
    end

    local function parseObject()
        consume('{')
        local obj = {}
        if peek() == '}' then pos = pos + 1; return obj end
        while true do
            local key = parseString()
            consume(':')
            obj[key] = parseValue()
            skipWhitespace()
            if str:sub(pos, pos) == '}' then pos = pos + 1; return obj end
            consume(',')
        end
    end

    parseValue = function()
        skipWhitespace()
        local c = str:sub(pos, pos)
        if c == '"' then return parseString()
        elseif c == '{' then return parseObject()
        elseif c == '[' then return parseArray()
        elseif c == 't' then pos = pos + 4; return true
        elseif c == 'f' then pos = pos + 5; return false
        elseif c == 'n' then pos = pos + 4; return nil
        elseif c == '-' or c:match("%d") then return parseNumber()
        else error("JSON: unexpected character '" .. c .. "' at position " .. pos)
        end
    end

    local result = parseValue()
    return result
end

return json
