--- Minimal Roblox API mocks for unit-testing Lib.lua pure-logic functions.
--- This file stubs out just enough of the Roblox environment so that
--- require("Lib") can load without errors.

-- math.clamp is Roblox-specific
if not math.clamp then
    function math.clamp(val, min, max)
        if val < min then return min end
        if val > max then return max end
        return val
    end
end

-- table.clear is Roblox-specific (Lua 5.3 doesn't have it)
if not table.clear then
    function table.clear(t)
        for k in pairs(t) do
            t[k] = nil
        end
    end
end

-- Stub services
local function mockService(name)
    local svc = {}
    if name == "HttpService" then
        function svc:JSONEncode(obj)
            -- minimal JSON encode for testing
            if type(obj) == "table" then
                local parts = {}
                for k, v in pairs(obj) do
                    local key = '"' .. tostring(k) .. '"'
                    local val
                    if type(v) == "string" then
                        val = '"' .. v .. '"'
                    elseif type(v) == "boolean" then
                        val = tostring(v)
                    elseif type(v) == "number" then
                        val = tostring(v)
                    elseif type(v) == "table" then
                        val = self:JSONEncode(v)
                    else
                        val = '"' .. tostring(v) .. '"'
                    end
                    parts[#parts + 1] = key .. ":" .. val
                end
                return "{" .. table.concat(parts, ",") .. "}"
            elseif type(obj) == "string" then
                return '"' .. obj .. '"'
            else
                return tostring(obj)
            end
        end
        function svc:JSONDecode(str)
            -- Mimics Roblox behavior: throws error on invalid JSON
            if not str or str == "" then
                error("Cannot parse empty string")
            end
            -- Convert JSON to Lua table syntax
            local lua_str = str:gsub("%[", "{"):gsub("%]", "}")
            lua_str = lua_str:gsub('"(%w+)"%s*:', '["%1"]=')
            lua_str = lua_str:gsub(":true", "=true"):gsub(":false", "=false")
            local fn = load("return " .. lua_str)
            if fn then
                local ok, result = pcall(fn)
                if ok and type(result) == "table" then return result end
            end
            error("Cannot parse JSON: " .. tostring(str))
        end
    end
    if name == "TextService" then
        function svc:GetTextSize(text, size, font, bounds)
            return { X = #text * 7, Y = size }
        end
    end
    if name == "Players" then
        svc.LocalPlayer = { Name = "TestPlayer", UserId = 12345 }
    end
    return svc
end

-- Stub game:GetService
game = game or {}
game.GetService = function(self, name)
    return mockService(name)
end

-- Instance / Color3 / UDim2 / Enum stubs (minimal, to allow loading)
Instance = Instance or {}
function Instance.new(class)
    local inst = { _class = class, _children = {} }
    local mt = {
        __index = function(t, k)
            return rawget(t, k)
        end,
        __newindex = function(t, k, v)
            rawset(t, k, v)
        end
    }
    setmetatable(inst, mt)
    return inst
end

Color3 = Color3 or {}
function Color3.fromRGB(r, g, b) return {R = r/255, G = g/255, B = b/255} end

UDim2 = UDim2 or {}
function UDim2.new(...) return {type = "UDim2", args = {...}} end

UDim = UDim or {}
function UDim.new(s, o) return {Scale = s, Offset = o} end

Vector2 = Vector2 or {}
function Vector2.new(x, y) return {X = x, Y = y} end

NumberSequence = NumberSequence or {}
function NumberSequence.new(keypoints) return {Keypoints = keypoints} end
NumberSequenceKeypoint = NumberSequenceKeypoint or {}
function NumberSequenceKeypoint.new(t, v) return {Time = t, Value = v} end

Enum = Enum or {}
Enum.Font = { Gotham = "Gotham", GothamBold = "GothamBold", GothamMedium = "GothamMedium" }
Enum.TextXAlignment = { Left = "Left", Center = "Center", Right = "Right" }
Enum.TextYAlignment = { Top = "Top", Center = "Center", Bottom = "Bottom" }
Enum.TextTruncate = { AtEnd = "AtEnd", None = "None" }
Enum.ZIndexBehavior = { Sibling = "Sibling" }
Enum.AutomaticSize = { Y = "Y" }
Enum.ScrollingDirection = { Y = "Y" }
Enum.SortOrder = { LayoutOrder = "LayoutOrder" }

-- CoreGui stub
CoreGui = { _children = {} }
function CoreGui:FindFirstChild(name)
    return self._children[name]
end

-- Roblox global stubs
task = task or {}
task.wait = function(t) end
task.delay = function(t, fn) end
task.defer = function(fn) end
task.cancel = function(t) end

pcall = pcall or function(fn, ...)
    local ok, result = xpcall(fn, function(err) return err end, ...)
    return ok, result
end

-- Filesystem stubs (used by ConfigSystem)
_G._mockFS = {}

function isfolder(path)
    return _G._mockFS[path .. "/"] ~= nil
end

function makefolder(path)
    _G._mockFS[path .. "/"] = true
end

function isfile(path)
    return _G._mockFS[path] ~= nil
end

function readfile(path)
    return _G._mockFS[path]
end

function writefile(path, content)
    _G._mockFS[path] = content
end

function delfile(path)
    _G._mockFS[path] = nil
end

-- setclipboard stub
function setclipboard(text) end

-- _G stubs
_G.AutoSaveEnabled = true
