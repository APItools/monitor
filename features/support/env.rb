require 'capybara'
require 'capybara/cucumber'
require 'capybara-screenshot'
require 'capybara-screenshot/cucumber'
require 'headless'

require 'jor_helper'
require 'http_helper'

begin
require 'pry'
rescue LoadError
end

def driver
  driver = ENV['DRIVER'] || ENV['driver']
  require "capybara/#{driver}"
  driver ? driver.to_sym : :selenium
rescue LoadError
  return :selenium
end

Capybara.configure do |config|
  config.default_driver = driver
  config.run_server = false
  config.app_host = 'http://localhost:7071'
  config.default_wait_time = 10
  config.save_and_open_page_path = 'tmp/capybara'
end

World(JORHelper)
World(HTTPHelper)

Before do
  jor.reset!
  api_client.post('/api/system/reset')
end
