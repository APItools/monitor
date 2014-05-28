local statsd = {}

local Methods = {}
local mt      = {__index = Methods }

local function get_dict(self)
  local dict = ngx.shared[self.dict]
  if not dict then
    error('The dictionary ' .. self.dict .. ' was not found. Please create it by adding `lua_shared_dict ' .. self.dict .. ' 20k;` to the ngx config file')
  end
  return dict
end

function Methods:time(bucket, time)
  self:register(bucket, time, "ms")
end

function Methods:count(bucket, n)
  self:register(bucket, n, 'c')
end

function Methods:gauge(bucket, value)
  self:register(bucket, value, 'g')
end

function Methods:incr(bucket, n)
  self:count(bucket, 1)
end

function Methods:register(bucket, amount, suffix)
  local dict = get_dict(self)

  dict:add('last_id', 0)
  local last_id = assert(dict:incr('last_id', 1))
  if self.namespace then bucket = self.namespace .. '.' .. bucket end

  assert(dict:set(last_id, bucket .. ":" .. tostring(amount) .. "|" .. suffix))
end

function Methods:flush(force)
  local dict = get_dict(self)

  local last_id         = tonumber(dict:get('last_id'), 10) or 0
  local last_flushed_id = tonumber(dict:get('last_flushed_id'), 10) or 0

  if force or last_id - last_flushed_id > self.buffer_size then
    assert(dict:set('last_flushed_id', last_id))
    local buffer, len = {}, 0
    for i=last_flushed_id + 1, last_id do
      local val, err = dict:get(i)
      if val then
        len = len + 1
        buffer[len] = val
      else
        ngx.log(ngx.ERR, '[statsd] cant get value from key ' .. tostring(i) .. ' err: ' .. err)
      end
      dict:delete(i)
    end

    if len > 0 then
      local udp = ngx.socket.udp()

      local ok, err = udp:setpeername(self.host, self.port)
      if not ok then ngx.log(ngx.ERR, err) end

      ok, err = udp:send(table.concat(buffer, '\n'))
      if not ok then ngx.log(ngx.ERR, err) end

      udp:close()
    end
  end
end

statsd.new = function(host, port, namespace, dict, buffer_size)
  return setmetatable({
    host        = host or '127.0.0.1',
    port        = port or 8125,
    namespace   = namespace, -- or nil
    dict        = dict or 'statsd',
    buffer_size = buffer_size or 10
  }, mt)
end

return statsd
