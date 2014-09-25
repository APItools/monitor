import 'tasks/release.rake'

namespace :github do
  task :release => 'rake:release' do
    tar = Pathname('release.tar.gz').expand_path
    version = Time.new.strftime('%Y%m%d%H%M')

    Dir.chdir 'release' do
      system('git', 'add', '-A')
      system('git', 'commit', '-m', "APItools Monitor Release #{version}")
      system('git', 'push', 'origin', 'master')
      system('git', 'archive', '--format', 'tar.gz', '-o', tar.to_s, '--prefix', 'apitools-monitor/', 'HEAD')
    end

    system('git', 'tag', '-a', version.to_s, '-m', "Release #{version}")
    system('git', 'push', '--tags')

    puts "Created release archive: #{tar}"
    puts "Upload it to: https://github.com/APItools/monitor/releases/new"

    puts "Version: #{version}"
  end
end

task github: ['github:release']
