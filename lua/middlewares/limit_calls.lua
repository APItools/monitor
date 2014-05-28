-- middleware
local count = 0
return function(req, res, trace)
  if count > 2 then
    res.status = 500
  end
  count = count + 1
end
