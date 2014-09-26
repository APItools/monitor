import 'tasks/jor.rake'
import 'tasks/sample.rake'
import 'tasks/dependencies.rake'

namespace :test do
  task :env do
    Dotenv.load ".env.test"
  end

  def args
    ARGV[1..-1]
  end

  desc "Run Lua tests"
  task lua: :env do
    exec Pathname('script/busted').expand_path.to_s
  end

  desc "Run API tests"
  task :api do
    exec('rspec', '--order', 'random')
  end

  desc "Run Angular tests"
  task :angular do
    require 'headless'

    if !system('karma', '--version') || `karma --version` !~ /Karma version:/
      puts 'Karma not found. Install it by: `npm install -g karma-cli`'
      exit(1)
    end

    headless = Headless.new.tap(&:start)
    at_exit { headless.destroy }

    exit system('karma', 'start', 'config/karma.conf.js', '--single-run', '--no-auto-watch', *args)
  end

  namespace :angular do
    desc "Run the angular test loop"
    task :watch do
      system('karma', 'start', 'config/karma.conf.js', '--no-single-run', '--auto-watch', *args)
    end
  end

  CUCUMBER_DRIVERS = %w[webkit selenium]
  desc "Run integration tests"
  task :integration do
    statuses = CUCUMBER_DRIVERS.map{|driver| system('cucumber', '-f', 'progress', '-p', driver) }
    exit statuses.all?
  end

  desc "Test sample generation"
  task :sample => %w[jor:clear sample:prepare sample:once]

  desc 'Run JMeter performance tests'
  task :performance do
    FileUtils.rm('tmp/jmeter.xml') rescue nil
    system('jmeter -n -t performance.jmx -D jmeter.save.saveservice.output_format=xml -l tmp/jmeter.xml')
  end
end

FAILED = "\033[31mFAILED\033[0m"
PASSED = "\033[32mPASSED\033[0m"

desc "Run all tests"
task test: %w[jor:clear]  do
  results = %w|lua api angular integration sample performance|.map do |kind|
    status = system("rake", "test:#{kind}")
    msg = "TEST FINISHED (#{kind}) "
    line = "\033[1m" + '+' + '-' * (msg.length + 8) + '+' + "\033[22m"

    msg += status ? PASSED : FAILED

    puts
    puts line
    puts "\033[1m| " + msg + " |\033[22m"
    puts line
    puts

    status
  end

  passed, _ = results.partition{|r| r }

  puts "(#{passed.count}/#{results.count}) tests passed"
  exit results.all?
end
