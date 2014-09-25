import 'tasks/dependencies.rake'
import 'tasks/test.rake'
require 'dotenv'

OPENRESTY_VERSION = 'openresty -V'
OPENRESTY = 'openresty -c config/nginx.conf -p release'

desc "Run all the things and run tests"
task :integrate do
  Rake::Task['dependencies:test'].execute
  Rake::Task['test'].execute
end

desc 'Run openresty from release folder'
task :openresty do
  Dotenv.load('.env')
  exec(OPENRESTY)
end

namespace :integrate do
  task :start do
    puts "Starting openresty: #{OPENRESTY}"
    system(OPENRESTY_VERSION)
    exec(OPENRESTY)
  end

  task :stop do
    cmd = OPENRESTY + ' -s stop'
    puts "Stopping openresty: #{cmd}"
    system(cmd)
  end
end
