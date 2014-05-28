local inspect = require 'inspect'
local luajson = require 'json'

local args = ngx.req.get_uri_args()
local code = args.code
if not code then
	ngx.exit(403)
end

local client_id = os.getenv("SLUG_CLIENT_ID") -- '75a7ae9e68e3fd530b9a'
local client_secret = os.getenv("SLUG_CLIENT_SECRET") -- 'c32ac5de4902387bb1fb5f128235641c8b05faa5'

--
local protocol, host = string.match(ngx.var.uri, "/auth/(https?)/(.-)$" )

local res = ngx.location.capture('/__gh', {method = ngx.HTTP_POST,
                               body = 'client_id=' .. client_id ..
                                 "&client_secret=" .. client_secret ..
                                 "&code=" .. code
                              })

local access_token = luajson.decode(res.body).access_token
ngx.redirect(protocol .. "://"  .. host .. "/api/auth/callback?access_token=" .. access_token)

-- ngx.say(inspect(res))
