require 'cron_helper'

World(CronHelper)

AfterStep '@cron' do
  run_cron
end
