local M = {}

-- Store last used input method per filetype
M._state = {
  per_filetype = {}, -- { [filetype] = im_value }
  current_im = nil,  -- current input method
}

M.config = {
  default_im = "com.apple.keylayout.ABC", -- fallback IM
  restore_previous = true,                 -- restore IM on InsertEnter
  switch_on_leave = true,                  -- switch to default on InsertLeave
  get_im_cmd = nil,                        -- custom command to get current IM
  set_im_cmd = nil,                        -- custom command to set IM
  remember_im_per_ft = true,               -- track IM per filetype
}

-- Detect OS and set appropriate commands
local function detect_os_commands()
  local uname = vim.loop.os_uname().sysname
  
  if uname == "Darwin" then
    -- macOS: use im-select
    return {
      get = "im-select",
      set = "im-select %s",
    }
  elseif uname == "Linux" then
    -- Linux: try ibus first, fall back to fcitx
    if vim.fn.executable("ibus") == 1 then
      return {
        get = "ibus engine",
        set = "ibus engine %s",
      }
    elseif vim.fn.executable("fcitx-remote") == 1 then
      return {
        get = "fcitx-remote -n",
        set = "fcitx-remote -s %s",
      }
    elseif vim.fn.executable("fcitx5-remote") == 1 then
      return {
        get = "fcitx5-remote -n",
        set = "fcitx5-remote -s %s",
      }
    end
  elseif uname:match("Windows") then
    -- Windows: use im-select.exe
    return {
      get = "im-select.exe",
      set = "im-select.exe %s",
    }
  end
  
  return nil
end

-- Execute command and return trimmed output
local function execute(cmd)
  local handle = io.popen(cmd .. " 2>/dev/null")
  if not handle then return nil end
  
  local result = handle:read("*a")
  handle:close()
  
  if result then
    return vim.trim(result)
  end
  return nil
end

-- Get current input method
function M.get_current_im()
  local cmd = M.config.get_im_cmd
  if not cmd then return nil end
  
  local im = execute(cmd)
  if im and im ~= "" then
    M._state.current_im = im
    return im
  end
  return nil
end

-- Set input method
function M.set_im(im)
  if not im or im == "" then return false end
  
  local cmd = M.config.set_im_cmd
  if not cmd then return false end
  
  local set_cmd = string.format(cmd, im)
  execute(set_cmd)
  M._state.current_im = im
  return true
end

-- Get filetype of current buffer
local function get_filetype()
  return vim.bo.filetype or ""
end

-- Remember current IM for filetype
function M.remember_im(ft)
  if not M.config.remember_im_per_ft then return end
  
  ft = ft or get_filetype()
  local im = M.get_current_im()
  
  if im and ft ~= "" then
    M._state.per_filetype[ft] = im
  end
end

-- Restore IM for filetype
function M.restore_im(ft)
  if not M.config.restore_previous then return end
  
  ft = ft or get_filetype()
  local im = M._state.per_filetype[ft] or M.config.default_im
  
  if im then
    M.set_im(im)
  end
end

-- Switch to default IM
function M.switch_to_default()
  if M.config.switch_on_leave and M.config.default_im then
    M.set_im(M.config.default_im)
  end
end

-- Clear per-filetype memory
function M.clear_memory(ft)
  if ft then
    M._state.per_filetype[ft] = nil
  else
    M._state.per_filetype = {}
  end
end

-- Get all remembered IMs
function M.get_state()
  return vim.deepcopy(M._state.per_filetype)
end

-- Set IM for specific filetype
function M.set(ft, im)
  if ft and im then
    M._state.per_filetype[ft] = im
  end
end

-- Setup autocmds
local function setup_autocmds()
  local group = vim.api.nvim_create_augroup("SmartIM", { clear = true })
  
  -- Remember IM before leaving insert mode
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = function()
      M.remember_im()
      M.switch_to_default()
    end,
  })
  
  -- Restore IM when entering insert mode
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function()
      M.restore_im()
    end,
  })
  
  -- Remember IM when switching buffers
  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function()
      if vim.fn.mode():match("^[iR]") then
        M.remember_im()
      end
    end,
  })
end

-- Setup plugin
function M.setup(opts)
  opts = opts or {}
  
  -- Detect OS commands if not provided
  local os_cmds = detect_os_commands()
  if os_cmds then
    M.config.get_im_cmd = opts.get_im_cmd or os_cmds.get
    M.config.set_im_cmd = opts.set_im_cmd or os_cmds.set
  end
  
  -- Merge user config
  M.config = vim.tbl_deep_extend("force", M.config, opts)
  
  -- Validate commands are set
  if not M.config.get_im_cmd or not M.config.set_im_cmd then
    vim.notify(
      "smart-im.nvim: Could not detect input method commands. Please set get_im_cmd and set_im_cmd manually.",
      vim.log.levels.WARN
    )
    return
  end
  
  -- Setup autocmds
  setup_autocmds()
  
  -- Create user commands
  vim.api.nvim_create_user_command("SmartIMClear", function(args)
    M.clear_memory(args.args ~= "" and args.args or nil)
    vim.notify("smart-im.nvim: Memory cleared", vim.log.levels.INFO)
  end, {
    nargs = "?",
    desc = "Clear input method memory (optionally for specific filetype)",
  })
  
  vim.api.nvim_create_user_command("SmartIMStatus", function()
    local state = M.get_state()
    local lines = { "smart-im.nvim status:" }
    for ft, im in pairs(state) do
      table.insert(lines, string.format("  %s: %s", ft, im))
    end
    if vim.tbl_isempty(state) then
      table.insert(lines, "  (no remembered input methods)")
    end
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end, {
    desc = "Show remembered input methods per filetype",
  })
end

return M
