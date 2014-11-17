require 'test/unit'
require 'rack/test'
require 'json'
require 'hiredis'
require 'redis'

$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))
Dir[File.dirname(__FILE__) + '/test_helpers/**/*.rb'].each { |file| require file }
Dir[File.dirname(__FILE__) + '/unit/test_case.rb'].each { |file| require file }

require 'jor'
