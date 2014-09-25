require 'pathname'
require './release'

namespace :release do
  release = Pathname('release')
  DEFAULT_PATHS = {
      release: release,
      assets: release.join('app/assets'),
      nginx: release.join('config'),
      lua: release.join('lua'),
      html: release.join('app')
  }

  # TODO: kill the optional folder and hardcore everything
  # it was bad idea from the beginning, we should have an object to hold the release folder info
  def get_output(args, type)
    args.with_defaults(output: DEFAULT_PATHS.fetch(type.to_sym))

    output = args[:output]

    FileUtils.mkdir_p(output)

    output
  end

  desc "Release just assets"
  task :assets, :output do |t, args|
    assets = get_output(args, :assets)

    parallel(%w[assets:stylesheets assets:images assets:fonts assets:javascripts], assets)
  end

  desc "Release just lua code"
  task :lua, :output do |t, args|
    output = get_output(args, :lua)

    FileUtils.cp_r('./lua/.', output)
  end

  desc "Release files for docker (docker, make)"
  task :docker, :output do |t, args|
    output = get_output(args, :release)

    FileUtils.cp('config/Dockerfile', output)

    config = output.join('config')

    FileUtils.cp('config/supervisor.conf', config)
    FileUtils.cp('config/logrotate.conf', config)
  end

  desc "Release license file"
  task :license, :output do |t, args|
    output = get_output(args, :release)
    FileUtils.cp('README.md', output)
    FileUtils.cp('LICENSE.txt', output)
    FileUtils.cp('CONTRIBUTING.md', output)
  end

  desc "Release just html code"
  task :html, :output do |t, args|
    output = get_output(args, :html)

    FileUtils.cp_r('./app/views/.', output)
    FileUtils.cp_r('./app/vendor/angular-ui-bootstrap/template', output)

    FileUtils.cp_r('./app/vendor/active-docs', output)
    FileUtils.cp_r('./app/vendor/zeroclipboard', output)

    FileUtils.cp_r('./public/.', output)
  end

  desc "Release nginx config"
  task :nginx, :output do |t, args|
    output = get_output(args, :nginx)

    nginx = Release.nginx('config/nginx.conf.erb')

    FileUtils.mv nginx.path, output.join('nginx.conf')
    FileUtils.cp 'config/mime.types', output
    FileUtils.cp 'config/http_call.conf', output
    FileUtils.cp 'config/env.conf', output
  end

  desc "Create logs folders"
  task :logs, :output do |t, args|
    output = get_output(args, :release)
    output.join('logs').mkdir
  end

  def git(cmd)
    puts "running: git #{cmd}"
    `git #{cmd}`.strip
  end

  task :push, :output do |t, args|
    output = get_output(args, :release).to_s + '/'

    git('fetch origin')
    git('update-ref origin/release remotes/origin/release')

    git("add -Af #{output}")
    user =  git('config --get user.name').chomp
    email = git('config --get user.email').chomp

    msg = "Release by #{user} <#{email}>"

    tree = git(%'write-tree --missing-ok --prefix #{output}')
    commit = git(%'commit-tree -p origin/release -m "#{msg}" #{tree}')

    git(%'push origin #{commit}:release')
    git(%'update-ref origin/release #{commit}')

    # TODO: do some funky stuff with show ref to prevent clashes
    # git show-ref origin/release

    git('reset -- release')
  end

  task :cleanup, :output do |t, args|
    output = Pathname.new(args[:output])

    if output.exist? or output.directory?
      warn "WARNING: #{output.expand_path} already exists.\nWill remove it, ok? (y/n) [n]"
      while char = get_char
        case char.downcase
          when 'n', "\n"
            puts "Not deleting the release folder. Bye!"
            exit 1
          when 'y'
            children = output.children - [output.join('.git')]
            children.each { |ch| ch.rmtree }

            warn "#{children.join(' ')} removed"
            break
        end
      end
    end
  end

end

def git_revision
  `git rev-parse --short HEAD`.strip
end

desc 'Relase brainslug'

def get_char
  return 'y' if ARGV.include?('-y')

  unless $stdin.tty?
    warn "Can't run in non interactive mode. Pass -y to force release."
    exit(1)
  end

  $stdin.getc.chr
end

def parallel(tasks, *params)
  threads = tasks.map do |task|
    pid = fork do
      Rake::Task[task].invoke(*params)
    end

    Thread.new do
      pid, status = Process.wait2(pid)

      if status.exitstatus > 0
        puts "Subprocess #{pid} failed with #{status}"
        exit 1
      end
    end
  end

  threads.map(&:join)
end

def tasks(tasks, *params)
  tasks.map do |task|
    Rake::Task[task].invoke(*params)
  end
end

task :release, :version do |t, args|
  version = args[:version] || "git:#{git_revision}"
  output = DEFAULT_PATHS[:release]
  Rake::Task['release:cleanup'].invoke(output)

  ENV['RELEASE'] ||= 'production'

  Dotenv.load ".env#{ENV['RELEASE']}"

  puts "Releasing brainslug (#{version}) ENV=#{ENV['RELEASE']}"

  tasks(%w[release:assets release:lua release:html release:nginx release:logs release:docker release:license])
end
