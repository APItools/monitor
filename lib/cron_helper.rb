module CronHelper
  def run_cron
    post(host + '/api/system/cron/flush')
  end
end
