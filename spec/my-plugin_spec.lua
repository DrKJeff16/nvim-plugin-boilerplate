local assert = require('luassert') ---@type Luassert

describe('my-plugin', function()
  local M ---@type MyPlugin

  before_each(function()
    -- Clear module cache to get fresh instance
    package.loaded['my-plugin'] = nil
    M = require('my-plugin')
  end)

  describe('setup', function()
    it('should set default configuration', function()
      assert.is_true((pcall(M.setup)))
    end)

    it('should merge user configuration with defaults', function()
      assert.is_true((pcall(M.setup, {})))
    end)

    it('should handle nil options', function()
      assert.is_true((pcall(M.setup, nil)))
    end)

    for _, param in ipairs({ 1, false, '', function() end }) do
      it(('should throw error when called with param of type %s'):format(type(param)), function()
        assert.is_false((pcall(M.setup, param)))
      end)
    end
  end)
end)
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
