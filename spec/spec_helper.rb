require 'bundler/setup'

Bundler.require :test

require 'http_helper'
require 'spec_helpers/fixtures_helper'
require 'jor_helper'
require 'cron_helper'

include JORHelper

def system_reset
  jor.reset!
  api_client.post("/api/system/reset")
end

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true

  config.include HTTPHelper
  config.include CronHelper
  config.include SimpleFixturesHelper

  config.order = 'random'

  config.before(:all) do
    system_reset()
  end

  config.before(:each) do
    jor.destroy_all
  end
end
