-- Hyprland layout switcher module
-- This module provides functions to get and set keyboard layouts in Hyprland
--
-- Performance optimization:
-- - Keyboard name and available layouts are cached on first use
-- - Only the active layout index is queried on each get_current_layout() call
-- - This reduces hyprctl overhead from 2-3 queries per operation to just 1
--
-- API:
-- - get_current_layout() - Get current keyboard layout
-- - switch_layout(layout) - Switch to a specific layout
-- - get_info() - Get cached keyboard info (for debugging)
-- - reset_cache() - Reset cache if keyboard config changes

local M = {}

-- Cache for keyboard info (initialized once on first use)
local cache = {
	keyboard_name = nil,
	layouts = nil,
	initialized = false,
}

local function execute(cmd)
	local handle = io.popen(cmd .. " 2>/dev/null")
	if not handle then
		return nil
	end
	local result = handle:read("*a")
	handle:close()
	if result then
		result = result:gsub("^%s*(.-)%s*$", "%1") -- trim
	end
	return result
end

local function json_decode(str)
	return vim.json.decode(str)
end

-- Initialize cache by querying hyprctl once
local function init_cache()
	if cache.initialized then
		return cache.keyboard_name ~= nil and cache.layouts ~= nil
	end

	cache.initialized = true

	-- Get keyboard devices
	local devices_output = execute("hyprctl devices -j")
	if not devices_output then
		return false
	end

	local devices_data = json_decode(devices_output)
	if not devices_data or not devices_data.keyboards then
		return false
	end

	-- Find main keyboard and extract info
	for _, keyboard in ipairs(devices_data.keyboards) do
		if keyboard.main then
			cache.keyboard_name = keyboard.name

			-- Parse layouts from keyboard.layout field
			local layouts = {}
			for layout in keyboard.layout:gmatch("[^,]+") do
				table.insert(layouts, (layout:gsub("^%s*(.-)%s*$", "%1")))
			end
			cache.layouts = layouts
			break
		end
	end

	return cache.keyboard_name ~= nil and cache.layouts ~= nil
end

local function get_current_layout()
	if not init_cache() then
		return nil
	end

	-- Only query for the active layout index
	local output = execute("hyprctl devices -j")
	if not output then
		return nil
	end

	local data = json_decode(output)
	if not data or not data.keyboards then
		return nil
	end

	-- Find main keyboard and get active layout index
	for _, keyboard in ipairs(data.keyboards) do
		if keyboard.main then
			local index = keyboard.active_layout_index or 0
			return cache.layouts[index + 1]
		end
	end

	return nil
end

local function switch_layout(target_layout)
	if not init_cache() then
		return false
	end

	-- Find the index of the target layout in cached layouts
	local target_idx = nil
	for i, layout in ipairs(cache.layouts) do
		if layout == target_layout then
			target_idx = i - 1 -- Hyprland uses 0-based indexing
			break
		end
	end

	if not target_idx then
		return false
	end

	-- Switch to the target layout using cached keyboard name
	local switch_cmd = string.format("hyprctl switchxkblayout %s %d", cache.keyboard_name, target_idx)
	local result = execute(switch_cmd)

	return result ~= nil
end

-- Reset cache (useful if keyboard configuration changes)
local function reset_cache()
	cache.keyboard_name = nil
	cache.layouts = nil
	cache.initialized = false
end

-- Get cached keyboard info (for debugging)
local function get_info()
	if not init_cache() then
		return nil
	end
	return {
		keyboard = cache.keyboard_name,
		layouts = vim.deepcopy(cache.layouts),
	}
end

-- Public API
M.get_current_layout = get_current_layout
M.switch_layout = switch_layout
M.reset_cache = reset_cache
M.get_info = get_info

return M
