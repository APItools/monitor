require 'thin'
require 'jor'
require 'hiredis'

def start_server(identifier, app, port)
  Rack::Server.start(
      :app  => app,
      :Port => port,
      :pid  => "tmp/#{identifier}.pid"
  )
end

namespace :server do

  desc "Start jor server"
  task :jor do
    start_server :jor, JOR::Server.new(Redis.new(:driver => :hiredis)), 10902
  end

end
