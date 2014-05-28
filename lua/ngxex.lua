local ngxex = {}

-- Reads the body data, even if it's so big it has been dumped in a file
ngxex.req_get_all_body_data = function()

  ngx.req.read_body()

  local data = ngx.req.get_body_data() -- returns nil when no data, or too large (so it's in a file)
  if not data then
    local file = ngx.req.get_body_file() -- returns nil when no data, or not in file
    if file then
      local f, err = io.open(file, "r")
      if f then
        data = f:read("*a")
        f:close()
      else
        ngx.log(ngx.ERR, 'could not read request body file: ' .. err)
      end
    end
  end

  return data -- will be nil if no body data, no file, or error when reading file

end

return ngxex
