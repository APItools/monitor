import 'tasks/release.rake'

namespace :github do
  task :release => 'rake:release' do
    version = Time.new.strftime('%Y%m%d%H%M')
    tar = Pathname("release-#{version}.tar.gz").expand_path

    system('tar', '-zcvf', tar.to_s, 'release')
    system('git', 'tag', '-a', version.to_s, '-m', "Release #{version}")
    system('git', 'push', '--tags')

    puts "Created release archive: #{tar}"
    puts "Upload it to: https://github.com/APItools/monitor/releases/new?tag=#{version}"

    puts "Version: #{version}"
  end
end

task github: ['github:release']
