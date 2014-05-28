local luajson = require 'json'

local error_handler = {}

local function get_status_and_message_from(err)
  local status, message, traceback = ngx.HTTP_INTERNAL_SERVER_ERROR, "Unknown error"
  if type(err) == 'table' then
    status  =   err.status or status
    message =   err.message or message
    traceback = err.traceback
  else
    message = err
  end
  return tonumber(status), tostring(message), traceback
end

error_handler.execute = function(f, report)
  local traceback
  local capture_traceback = function(err)
    traceback = debug.traceback()
    return err
  end

  local result = { xpcall(f, capture_traceback) }
  local ok, err = result[1], result[2]
  if not ok then
    local status, message, traceback2 = get_status_and_message_from(err)

    if report then report(status, message, traceback or traceback2) end

    ngx.log(0, "\n++++++++++++ ERROR: " .. message .. "\n" .. traceback .. "\n++++++++++++\n")
  end

  return unpack(result)
end

error_handler.execute_and_report = function(f)
  return error_handler.execute(f, function(status, message, trace)
    if not ngx.headers_sent then
      local msg    = {['error'] = message}
      local is_dev = os.getenv('SLUG_ENV') == 'dev'

      if is_dev then
        msg.traceback = trace
      else
        msg.error = message:gsub('^.+%.lua:%d+: ', '')
      end

      ngx.status = status
      ngx.print(luajson.encode(msg))
    end
  end)
end

return error_handler
