local tableSerialization = {}

local function serializeTable(tbl)
    local result = "{"
    local isFirst = true
    for k, v in pairs(tbl) do
        if not isFirst then
            result = result .. ", "
        else
            isFirst = false
        end
        if type(k) == "number" then
            result = result .. "[" .. k .. "]"
        else
            result = result .. "[\"" .. k .. "\"]"
        end
        result = result .. "="
        if type(v) == "table" then
            result = result .. serializeTable(v)
        else
            result = result .. tostring(v)
        end
    end
    result = result .. "}"
    return result
end

function tableSerialization.serialize(tbl)
    return serializeTable(tbl)
end

function tableSerialization.deserialize(str)
    local func, err = load("return " .. str)
    if func then
        return func()
    else
        print("Error in deserialization:", err)
        return nil
    end
end

function tableSerialization.register()
    tableSerialization.serialize = tableSerialization.serialize
    tableSerialization.deserialize = tableSerialization.deserialize
end

return tableSerialization
