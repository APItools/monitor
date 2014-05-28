-- TODO: LICENSE from lapis

local Config = require'models.config'

local json = require("cjson")
local env = require 'env'
local encode_base64, decode_base64, hmac_sha1
do
  local _obj_0 = ngx
  encode_base64, decode_base64, hmac_sha1 = _obj_0.encode_base64, _obj_0.decode_base64, _obj_0.hmac_sha1
end

local default_expires = 60 * 60 * 8;
local enabled = env.enabled('SLUG_CSRF_PROTECTION')

local generate_token
generate_token = function(req, key, expires)
  if expires == nil then
    expires = os.time() + default_expires
  end
  local msg = encode_base64(json.encode({
    key = key,
    expires = expires
  }))
  local signature = encode_base64(hmac_sha1(Config.csrf_secret(), msg))
  return msg .. "." .. signature
end

local validate_token
validate_token = function(token, key)
  if not (token) then
    return nil, "missing csrf token"
  end
  local msg, sig = token:match("^(.*)%.(.*)$")
  sig = ngx.decode_base64(sig)
  if not (sig == ngx.hmac_sha1(Config.csrf_secret(), msg)) then
    return nil, "invalid csrf token"
  end
  msg = json.decode(ngx.decode_base64(msg))
  if not (msg.key == key) then
    return nil, "invalid csrf token"
  end
  if not (not msg.expires or msg.expires > os.time()) then
    return nil, "csrf token expired"
  end
  return true
end

local assert_token
assert_token = function(...)
  local assert_error
  do
    local _obj_0 = require("lapis.application")
    assert_error = _obj_0.assert_error
  end
  return assert_error(validate_token(...))
end

return {
  generate_token = generate_token,
  validate_token = validate_token,
  assert_token = assert_token,
  expires = default_expires,
  enabled = enabled
}
