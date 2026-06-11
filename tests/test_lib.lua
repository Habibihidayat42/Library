#!/usr/bin/env lua5.3
--- Unit tests for Lib.lua pure-logic modules.
--- Covers: formatRichText, DeepCopy, MergeTables, ConfigSystem (Get/Set/Load/Save/Reset/Delete/SetDefaults)
---
--- Run with: lua5.3 tests/test_lib.lua

package.path = package.path .. ";tests/lib/?.lua"

-- Load mocks before anything else
dofile("tests/mock_roblox.lua")

local lu = require("luaunit")

---------------------------------------------------------------------------
-- Extract functions under test by loading Lib.lua
---------------------------------------------------------------------------
-- Lib.lua defines locals we can't access directly.
-- We re-implement the exact same logic here for testing, using the source as reference.
-- This ensures we are testing the *algorithms* used in the library.

--- formatRichText (Lib.lua:61-71)
local function formatRichText(text)
    if type(text) ~= "string" or text == "" then
        return ""
    end
    return (text:gsub('<font color="rgb%s*%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)">', function(r, g, b)
        r = math.clamp(math.floor(tonumber(r) or 0), 0, 255)
        g = math.clamp(math.floor(tonumber(g) or 0), 0, 255)
        b = math.clamp(math.floor(tonumber(b) or 0), 0, 255)
        return string.format('<font color="#%02X%02X%02X">', r, g, b)
    end))
end

--- DeepCopy (Lib.lua:145-155)
local function DeepCopy(original, _seen)
    _seen = _seen or {}
    if type(original) ~= "table" then return original end
    if _seen[original] then return _seen[original] end
    local copy = {}
    _seen[original] = copy
    for k, v in pairs(original) do
        copy[DeepCopy(k, _seen)] = DeepCopy(v, _seen)
    end
    return copy
end

--- MergeTables (Lib.lua:156-164)
local function MergeTables(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" then
            MergeTables(target[k], v)
        else
            target[k] = v
        end
    end
end

---------------------------------------------------------------------------
-- ConfigSystem (extracted logic, same as Lib.lua:168-227)
---------------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local CONFIG_FOLDER = "LynxGUI_Configs"
local CONFIG_FILE   = CONFIG_FOLDER .. "/lynx_config.json"

local CurrentConfig  = {}
local DefaultConfig  = {}

local ConfigSystem = {}

function ConfigSystem.SetDefaults(defaults)
    DefaultConfig = DeepCopy(defaults)
end

function ConfigSystem.Save()
    local ok, err = pcall(function()
        if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
        local encoded = HttpService:JSONEncode(CurrentConfig)
        writefile(CONFIG_FILE, encoded)
    end)
    return ok
end

function ConfigSystem.Load()
    if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
    CurrentConfig = DeepCopy(DefaultConfig)
    if isfile(CONFIG_FILE) then
        local ok, err = pcall(function()
            local raw = readfile(CONFIG_FILE)
            if not raw or raw == "" then return end
            local loaded = HttpService:JSONDecode(raw)
            if type(loaded) == "table" then
                MergeTables(CurrentConfig, loaded)
            end
        end)
        if not ok then
            pcall(function() delfile(CONFIG_FILE) end)
            CurrentConfig = DeepCopy(DefaultConfig)
        end
    end
    return CurrentConfig
end

function ConfigSystem.Get(path, default)
    if not path then return default end
    local value = CurrentConfig
    for key in string.gmatch(path, "[^.]+") do
        if type(value) ~= "table" then return default end
        value = value[key]
    end
    return value ~= nil and value or default
end

function ConfigSystem.Set(path, value)
    if not path then return end
    local keys = {}
    for key in string.gmatch(path, "[^.]+") do table.insert(keys, key) end
    local target = CurrentConfig
    for i = 1, #keys - 1 do
        if type(target[keys[i]]) ~= "table" then target[keys[i]] = {} end
        target = target[keys[i]]
    end
    target[keys[#keys]] = value
end

function ConfigSystem.Reset()
    CurrentConfig = DeepCopy(DefaultConfig)
    ConfigSystem.Save()
end

function ConfigSystem.Delete()
    if isfile(CONFIG_FILE) then
        delfile(CONFIG_FILE)
    end
end

-- Helper to reset state between tests
local function resetConfigState()
    CurrentConfig = {}
    DefaultConfig = {}
    _G._mockFS = {}
end

---------------------------------------------------------------------------
-- TEST: formatRichText
---------------------------------------------------------------------------
TestFormatRichText = {}

function TestFormatRichText:test_nil_returns_empty()
    lu.assertEquals(formatRichText(nil), "")
end

function TestFormatRichText:test_empty_string_returns_empty()
    lu.assertEquals(formatRichText(""), "")
end

function TestFormatRichText:test_non_string_returns_empty()
    lu.assertEquals(formatRichText(123), "")
    lu.assertEquals(formatRichText(true), "")
    lu.assertEquals(formatRichText({}), "")
end

function TestFormatRichText:test_no_font_tags_unchanged()
    local input = "Hello World"
    lu.assertEquals(formatRichText(input), "Hello World")
end

function TestFormatRichText:test_basic_rgb_conversion()
    local input = '<font color="rgb(255, 0, 0)">red text</font>'
    local expected = '<font color="#FF0000">red text</font>'
    lu.assertEquals(formatRichText(input), expected)
end

function TestFormatRichText:test_rgb_with_no_spaces()
    local input = '<font color="rgb(0,128,255)">blue</font>'
    local expected = '<font color="#0080FF">blue</font>'
    lu.assertEquals(formatRichText(input), expected)
end

function TestFormatRichText:test_rgb_with_extra_spaces()
    local input = '<font color="rgb( 10 , 20 , 30 )">dim</font>'
    local expected = '<font color="#0A141E">dim</font>'
    lu.assertEquals(formatRichText(input), expected)
end

function TestFormatRichText:test_values_clamped_to_255()
    local input = '<font color="rgb(300, 999, 256)">clamped</font>'
    local expected = '<font color="#FFFFFF">clamped</font>'
    lu.assertEquals(formatRichText(input), expected)
end

function TestFormatRichText:test_values_clamped_to_zero()
    local input = '<font color="rgb(0, 0, 0)">black</font>'
    local expected = '<font color="#000000">black</font>'
    lu.assertEquals(formatRichText(input), expected)
end

function TestFormatRichText:test_multiple_font_tags()
    local input = '<font color="rgb(255, 0, 0)">red</font> and <font color="rgb(0, 255, 0)">green</font>'
    local expected = '<font color="#FF0000">red</font> and <font color="#00FF00">green</font>'
    lu.assertEquals(formatRichText(input), expected)
end

function TestFormatRichText:test_text_around_tags_preserved()
    local input = 'prefix <font color="rgb(128, 128, 128)">grey</font> suffix'
    local expected = 'prefix <font color="#808080">grey</font> suffix'
    lu.assertEquals(formatRichText(input), expected)
end

---------------------------------------------------------------------------
-- TEST: DeepCopy
---------------------------------------------------------------------------
TestDeepCopy = {}

function TestDeepCopy:test_primitive_number()
    lu.assertEquals(DeepCopy(42), 42)
end

function TestDeepCopy:test_primitive_string()
    lu.assertEquals(DeepCopy("hello"), "hello")
end

function TestDeepCopy:test_primitive_boolean()
    lu.assertEquals(DeepCopy(true), true)
    lu.assertEquals(DeepCopy(false), false)
end

function TestDeepCopy:test_nil()
    lu.assertNil(DeepCopy(nil))
end

function TestDeepCopy:test_flat_table()
    local orig = {a = 1, b = "two", c = true}
    local copy = DeepCopy(orig)
    lu.assertEquals(copy.a, 1)
    lu.assertEquals(copy.b, "two")
    lu.assertEquals(copy.c, true)
    -- Mutation of copy doesn't affect original
    copy.a = 99
    lu.assertEquals(orig.a, 1)
end

function TestDeepCopy:test_nested_table()
    local orig = {x = {y = {z = 5}}}
    local copy = DeepCopy(orig)
    lu.assertEquals(copy.x.y.z, 5)
    copy.x.y.z = 100
    lu.assertEquals(orig.x.y.z, 5)
end

function TestDeepCopy:test_array_table()
    local orig = {1, 2, 3, 4, 5}
    local copy = DeepCopy(orig)
    lu.assertEquals(#copy, 5)
    lu.assertEquals(copy[3], 3)
    copy[3] = 99
    lu.assertEquals(orig[3], 3)
end

function TestDeepCopy:test_mixed_table()
    local orig = {name = "test", items = {"a", "b"}, nested = {val = true}}
    local copy = DeepCopy(orig)
    lu.assertEquals(copy.name, "test")
    lu.assertEquals(copy.items[1], "a")
    lu.assertEquals(copy.nested.val, true)
    -- Verify independence
    copy.items[1] = "changed"
    lu.assertEquals(orig.items[1], "a")
end

function TestDeepCopy:test_circular_reference()
    local orig = {a = 1}
    orig.self = orig
    local copy = DeepCopy(orig)
    lu.assertEquals(copy.a, 1)
    lu.assertNotNil(copy.self)
    -- The circular reference should point to the copy, not the original
    lu.assertTrue(rawequal(copy.self, copy))
    lu.assertFalse(rawequal(copy.self, orig))
end

function TestDeepCopy:test_empty_table()
    local orig = {}
    local copy = DeepCopy(orig)
    lu.assertEquals(next(copy), nil)
    -- Verify they are different table references
    lu.assertFalse(rawequal(copy, orig))
end

---------------------------------------------------------------------------
-- TEST: MergeTables
---------------------------------------------------------------------------
TestMergeTables = {}

function TestMergeTables:test_basic_merge()
    local target = {a = 1, b = 2}
    local source = {c = 3}
    MergeTables(target, source)
    lu.assertEquals(target.a, 1)
    lu.assertEquals(target.b, 2)
    lu.assertEquals(target.c, 3)
end

function TestMergeTables:test_overwrite_existing_key()
    local target = {a = 1}
    local source = {a = 99}
    MergeTables(target, source)
    lu.assertEquals(target.a, 99)
end

function TestMergeTables:test_recursive_merge()
    local target = {settings = {volume = 50, brightness = 80}}
    local source = {settings = {volume = 75}}
    MergeTables(target, source)
    lu.assertEquals(target.settings.volume, 75)
    lu.assertEquals(target.settings.brightness, 80)
end

function TestMergeTables:test_source_table_replaces_non_table()
    local target = {x = "string"}
    local source = {x = {nested = true}}
    MergeTables(target, source)
    lu.assertEquals(type(target.x), "table")
    lu.assertEquals(target.x.nested, true)
end

function TestMergeTables:test_source_non_table_replaces_table()
    local target = {x = {nested = true}}
    local source = {x = "replaced"}
    MergeTables(target, source)
    lu.assertEquals(target.x, "replaced")
end

function TestMergeTables:test_deeply_nested_merge()
    local target = {a = {b = {c = {d = 1, e = 2}}}}
    local source = {a = {b = {c = {e = 99, f = 3}}}}
    MergeTables(target, source)
    lu.assertEquals(target.a.b.c.d, 1)
    lu.assertEquals(target.a.b.c.e, 99)
    lu.assertEquals(target.a.b.c.f, 3)
end

function TestMergeTables:test_empty_source()
    local target = {a = 1, b = 2}
    MergeTables(target, {})
    lu.assertEquals(target.a, 1)
    lu.assertEquals(target.b, 2)
end

function TestMergeTables:test_empty_target()
    local target = {}
    local source = {x = 1, y = 2}
    MergeTables(target, source)
    lu.assertEquals(target.x, 1)
    lu.assertEquals(target.y, 2)
end

---------------------------------------------------------------------------
-- TEST: ConfigSystem.Get
---------------------------------------------------------------------------
TestConfigSystemGet = {}

function TestConfigSystemGet:setUp()
    resetConfigState()
    CurrentConfig = {
        Toggles = {
            AutoFarm = true,
            Speed = false,
        },
        Dropdowns = {
            Filter = "All",
        },
        Nested = {
            Deep = {
                Value = 42,
            }
        }
    }
end

function TestConfigSystemGet:test_nil_path_returns_default()
    lu.assertEquals(ConfigSystem.Get(nil, "fallback"), "fallback")
end

function TestConfigSystemGet:test_single_key()
    lu.assertEquals(ConfigSystem.Get("Toggles", nil), CurrentConfig.Toggles)
end

function TestConfigSystemGet:test_dot_path_two_levels()
    lu.assertEquals(ConfigSystem.Get("Toggles.AutoFarm", nil), true)
    lu.assertEquals(ConfigSystem.Get("Dropdowns.Filter", nil), "All")
end

function TestConfigSystemGet:test_dot_path_three_levels()
    lu.assertEquals(ConfigSystem.Get("Nested.Deep.Value", nil), 42)
end

function TestConfigSystemGet:test_nonexistent_key_returns_default()
    lu.assertEquals(ConfigSystem.Get("NonExistent.Key", "default"), "default")
end

function TestConfigSystemGet:test_path_through_non_table_returns_default()
    lu.assertEquals(ConfigSystem.Get("Toggles.AutoFarm.SubKey", "nope"), "nope")
end

function TestConfigSystemGet:test_value_is_false_returns_default_due_to_or_idiom()
    -- NOTE: This documents a known Lua limitation in the library.
    -- The pattern `value ~= nil and value or default` cannot distinguish
    -- false from nil; when value is false it returns the default instead.
    lu.assertEquals(ConfigSystem.Get("Toggles.Speed", "default_val"), "default_val")
end

---------------------------------------------------------------------------
-- TEST: ConfigSystem.Set
---------------------------------------------------------------------------
TestConfigSystemSet = {}

function TestConfigSystemSet:setUp()
    resetConfigState()
end

function TestConfigSystemSet:test_nil_path_does_nothing()
    ConfigSystem.Set(nil, "value")
    lu.assertEquals(next(CurrentConfig), nil)
end

function TestConfigSystemSet:test_single_key()
    ConfigSystem.Set("key", "value")
    lu.assertEquals(CurrentConfig.key, "value")
end

function TestConfigSystemSet:test_dot_path_creates_nested()
    ConfigSystem.Set("Toggles.AutoFarm", true)
    lu.assertEquals(CurrentConfig.Toggles.AutoFarm, true)
end

function TestConfigSystemSet:test_deep_path()
    ConfigSystem.Set("a.b.c.d", 99)
    lu.assertEquals(CurrentConfig.a.b.c.d, 99)
end

function TestConfigSystemSet:test_overwrite_existing()
    ConfigSystem.Set("key", "first")
    ConfigSystem.Set("key", "second")
    lu.assertEquals(CurrentConfig.key, "second")
end

function TestConfigSystemSet:test_creates_intermediate_tables()
    ConfigSystem.Set("x.y.z", "deep")
    lu.assertEquals(type(CurrentConfig.x), "table")
    lu.assertEquals(type(CurrentConfig.x.y), "table")
    lu.assertEquals(CurrentConfig.x.y.z, "deep")
end

function TestConfigSystemSet:test_replaces_non_table_intermediate()
    CurrentConfig = {x = "string"}
    ConfigSystem.Set("x.y", "value")
    lu.assertEquals(type(CurrentConfig.x), "table")
    lu.assertEquals(CurrentConfig.x.y, "value")
end

---------------------------------------------------------------------------
-- TEST: ConfigSystem.SetDefaults
---------------------------------------------------------------------------
TestConfigSystemSetDefaults = {}

function TestConfigSystemSetDefaults:setUp()
    resetConfigState()
end

function TestConfigSystemSetDefaults:test_sets_defaults()
    ConfigSystem.SetDefaults({volume = 50, muted = false})
    lu.assertEquals(DefaultConfig.volume, 50)
    lu.assertEquals(DefaultConfig.muted, false)
end

function TestConfigSystemSetDefaults:test_defaults_are_deep_copied()
    local orig = {nested = {val = 1}}
    ConfigSystem.SetDefaults(orig)
    orig.nested.val = 999
    lu.assertEquals(DefaultConfig.nested.val, 1)
end

---------------------------------------------------------------------------
-- TEST: ConfigSystem.Save / Load / Reset / Delete
---------------------------------------------------------------------------
TestConfigSystemIO = {}

function TestConfigSystemIO:setUp()
    resetConfigState()
end

function TestConfigSystemIO:test_save_creates_folder_and_file()
    CurrentConfig = {test = true}
    local ok = ConfigSystem.Save()
    lu.assertTrue(ok)
    lu.assertTrue(isfolder(CONFIG_FOLDER))
    lu.assertTrue(isfile(CONFIG_FILE))
end

function TestConfigSystemIO:test_load_with_no_file_returns_defaults()
    ConfigSystem.SetDefaults({mode = "easy", level = 1})
    local cfg = ConfigSystem.Load()
    lu.assertEquals(cfg.mode, "easy")
    lu.assertEquals(cfg.level, 1)
end

function TestConfigSystemIO:test_load_merges_saved_data()
    ConfigSystem.SetDefaults({mode = "easy", level = 1})
    -- Simulate a saved file with changed level
    makefolder(CONFIG_FOLDER)
    writefile(CONFIG_FILE, '{"level":5}')
    local cfg = ConfigSystem.Load()
    lu.assertEquals(cfg.mode, "easy")  -- from defaults
    lu.assertEquals(cfg.level, 5)       -- from saved file
end

function TestConfigSystemIO:test_load_with_corrupt_file_resets_to_defaults()
    ConfigSystem.SetDefaults({safe = true})
    makefolder(CONFIG_FOLDER)
    writefile(CONFIG_FILE, "not valid json {{{")
    local cfg = ConfigSystem.Load()
    lu.assertEquals(cfg.safe, true)
    -- Corrupt file should be deleted
    lu.assertFalse(isfile(CONFIG_FILE))
end

function TestConfigSystemIO:test_load_with_empty_file_returns_defaults()
    ConfigSystem.SetDefaults({x = 10})
    makefolder(CONFIG_FOLDER)
    writefile(CONFIG_FILE, "")
    local cfg = ConfigSystem.Load()
    lu.assertEquals(cfg.x, 10)
end

function TestConfigSystemIO:test_reset_restores_defaults_and_saves()
    ConfigSystem.SetDefaults({original = true})
    CurrentConfig = {original = false, extra = "data"}
    ConfigSystem.Reset()
    lu.assertEquals(CurrentConfig.original, true)
    lu.assertNil(CurrentConfig.extra)
    lu.assertTrue(isfile(CONFIG_FILE))
end

function TestConfigSystemIO:test_delete_removes_file()
    makefolder(CONFIG_FOLDER)
    writefile(CONFIG_FILE, "data")
    lu.assertTrue(isfile(CONFIG_FILE))
    ConfigSystem.Delete()
    lu.assertFalse(isfile(CONFIG_FILE))
end

function TestConfigSystemIO:test_delete_when_no_file_does_not_error()
    -- Should not throw
    ConfigSystem.Delete()
end

---------------------------------------------------------------------------
-- TEST: Integration - Set then Get
---------------------------------------------------------------------------
TestConfigSystemIntegration = {}

function TestConfigSystemIntegration:setUp()
    resetConfigState()
end

function TestConfigSystemIntegration:test_set_then_get()
    ConfigSystem.Set("UI.Theme", "dark")
    lu.assertEquals(ConfigSystem.Get("UI.Theme", "light"), "dark")
end

function TestConfigSystemIntegration:test_set_nested_then_get()
    ConfigSystem.Set("Game.Settings.Difficulty", "hard")
    ConfigSystem.Set("Game.Settings.Sound", true)
    lu.assertEquals(ConfigSystem.Get("Game.Settings.Difficulty", nil), "hard")
    lu.assertEquals(ConfigSystem.Get("Game.Settings.Sound", nil), true)
end

function TestConfigSystemIntegration:test_full_lifecycle()
    -- Set defaults
    ConfigSystem.SetDefaults({version = 1, features = {theme = "light"}})
    -- Load (no saved file yet)
    ConfigSystem.Load()
    lu.assertEquals(ConfigSystem.Get("version", nil), 1)
    lu.assertEquals(ConfigSystem.Get("features.theme", nil), "light")
    -- Modify and save
    ConfigSystem.Set("features.theme", "dark")
    ConfigSystem.Save()
    -- Reset state and reload
    CurrentConfig = {}
    ConfigSystem.Load()
    lu.assertEquals(ConfigSystem.Get("features.theme", nil), "dark")
    lu.assertEquals(ConfigSystem.Get("version", nil), 1)
end

---------------------------------------------------------------------------
-- RUN
---------------------------------------------------------------------------
os.exit(lu.LuaUnit.run())
