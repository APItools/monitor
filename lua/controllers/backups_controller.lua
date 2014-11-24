local concurredis    = require "concurredis"
local crontab  = require "crontab"
local redis = require 'resty.redis'
local Config = require 'models.config'

local backups = {}

function backups.export()
  crontab.shutdown()
  concurredis.save()

  crontab.initialize()

  local folder_path = os.getenv('SLUG_REDIS_DUMP_FOLDER_PATH')
  local file_path   = folder_path .. 'dump.rdb'

  ngx.header["Content-Type"]        = 'application/octet-stream';
  ngx.header["Content-Disposition"] = 'attachment; filename="dump.rdb"';

  ngx.exec('/redis/dump/dump.rdb')
end

function backups.valid(file)
  local valid = os.execute('redis-check-dump ' .. file)
  return valid == 0 or valid == true
end

function backups.import(params)
  local folder_path = assert(os.getenv('SLUG_REDIS_DUMP_FOLDER_PATH'), 'missing SLUG_REDIS_DUMP_FOLDER_PATH variable')
  local dump_file   = folder_path .. 'dump.rdb'

  local uploaded_file = ngx.var.http_x_file

  if not backups.valid(uploaded_file) then
    ngx.log(0, 'Refusing to import corrupted rdb file')
    return ngx.exit(422)
  end

  crontab.halt()
  concurredis.config('save', '')

  assert(os.rename(uploaded_file, dump_file))

  pcall(concurredis.shutdown)

  -- TODO: wait until redis starts again

  local connected
  local red = redis:new()
  local sleep = 0.1
  local growth = 1.2
  local loaded = false

  while not connected do
    ngx.sleep(sleep)
    connected = red:connect(concurredis.host, concurredis.port)
    sleep = sleep * growth
  end

  while not loaded do
    ngx.sleep(sleep)

    local info = red:info('persistence')
    local loading = info:match('loading:(%d)')

    if loading == '0' then
      loaded = true
    end

    sleep = sleep * growth
  end

  red:close()

  Config.flush() -- flush cache
  --redis should be started here (by the process manager)
  crontab.initialize()
end


backups.skip_csrf = true

return backups
