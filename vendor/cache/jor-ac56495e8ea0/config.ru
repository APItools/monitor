require File.dirname(__FILE__) + "/lib/jor.rb"
Rack::Handler::Thin.run(JOR::Server.new(Redis.new(:driver => :hiredis)), :Port => 10902) 
