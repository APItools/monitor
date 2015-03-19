local concurredis = require "concurredis"
local crontab     = require "crontab"
local Config      = require "models.config"

local backups = {}

local AOF = 'appendonly.aof'
local RDB = 'dump.rdb'

function backups.export(params)
  crontab.shutdown()
  concurredis.save()

  crontab.initialize()

  local file = params.file or RDB -- AOF

  ngx.header["Content-Type"]        = 'application/octet-stream';
  ngx.header["Content-Disposition"] = 'attachment; filename="' .. file ..'"';

  ngx.exec('/redis/dump/' .. file)
end

function backups.valid(uploaded, expected)
  local valid

  if expected == RDB then
    valid = os.execute('redis-check-dump ' .. uploaded)
  elseif expected == AOF then
    valid = os.execute('redis-check-aof ' .. uploaded)
  else
    ngx.log(ngx.ERROR, 'Unknown ' .. expected .. ' file uploaded: ' .. uploaded)
  end

  return valid == 0 or valid == true
end

function backups.import(params)
  local file = params.file or 'dump.rdb'
  local folder_path = assert(os.getenv('SLUG_REDIS_DUMP_FOLDER_PATH'), 'missing SLUG_REDIS_DUMP_FOLDER_PATH variable')
  local dump_file   = folder_path .. file

  local uploaded_file = ngx.var.http_x_file

  if not backups.valid(uploaded_file, file) then
    ngx.log(0, 'Refusing to import corrupted ' .. file .. ' file')
    return ngx.exit(422)
  end

  crontab.halt()
  concurredis.config('save', '')

  assert(os.rename(uploaded_file, dump_file))

  concurredis.restart()

  Config.flush() -- flush cache
  --redis should be started here (by the process manager)
  crontab.initialize()
end


backups.skip_csrf = true

return backups
