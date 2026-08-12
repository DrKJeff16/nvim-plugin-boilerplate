local util = require('my-plugin.util')

---@class MyPlugin.Config
local M = {}

---@return MyPluginOpts defaults
function M.get_defaults()
  ---@class MyPluginOpts
  local defaults = { bar = false, debug = false, foo = true }
  return defaults
end

local config = M.get_defaults()

---@return MyPluginOpts config
function M.get()
  return config
end

---@param k string
---@param v any
function M.set(k, v)
  local default = M.get_defaults()[k]
  if default ~= nil then
    config[k] = v
  end
end

---@param opts? MyPluginOpts
function M.setup(opts)
  util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  config = vim.tbl_deep_extend('force', M.get_defaults(), opts or {})
  vim.g.MyPlugin_setup = 1 -- OPTIONAL for `health.lua`, delete if you want to
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
