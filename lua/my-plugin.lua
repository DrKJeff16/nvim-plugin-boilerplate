---@class MyPlugin
local M = {}

---@param opts? MyPluginOpts
function M.setup(opts)
  require('my-plugin.util').validate({ opts = { opts, { 'table', 'nil' }, true } })

  require('my-plugin.config').setup(opts or {})

  -- ...
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
