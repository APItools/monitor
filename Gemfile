source 'https://rubygems.org'

gem 'rake'

gem 'compass', '~> 1.0.0'
gem 'bootstrap-sass', '~> 2.3'
gem 'compass-flexbox'
gem 'sass-css-importer'
gem 'coffee-script'
gem 'uglifier'
gem 'dotenv'

gem 'bourbon', '>= 3.2.0.beta'
gem 'neat'

gem 'jor', github: 'apitools/jor', branch: 'master', require: false

gem 'httpclient'
gem 'activesupport'

group :development, :test do
  gem 'statsd-ruby', require: 'statsd'
  gem 'thin', require: false
end

group :development do
  gem 'foreman'

  gem 'guard-coffeescript', require: false
  gem 'guard-shell', require: false
  gem 'guard-concat', github: 'mikz/guard-concat', require: false
  gem 'guard-livereload', require: false

  gem 'pry'
  gem 'pry-byebug'
  gem 'pry-rescue'
  gem 'pry-stack_explorer'

  gem 'scss-lint'
end

group :test do
  gem 'headless'

  gem 'rspec_api_documentation'
  gem 'rack-client'
  gem 'rack-test'
  gem 'json_spec'

  gem 'rspec'
  gem 'cucumber'
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'capybara-webkit'
  gem 'capybara-screenshot'
  gem 'capybara-angular'

  # rather use nodejs
  #gem 'therubyracer'

  gem 'json'
end
