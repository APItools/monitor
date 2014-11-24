describe('lock', function()
  local lock = require 'lock'

  describe('around', function()
    it('returns the original values', function()
      local fun = function()  return 'a', 'b', 'c' end
      local a,b,c = lock.around('name', fun)
      assert.equal('a', a)
      assert.equal('b', b)
      assert.equal('c', c)
    end)

    it('returns nil and error message', function()
      local fun = function() error('error message') end
      local ok, msg = lock.around('name', fun)

      assert.falsy(ok)
      assert.equal('./spec/lock_spec.lua:14: error message', msg)
    end)
  end)
end)
