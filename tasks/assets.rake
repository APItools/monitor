require './release'

namespace :assets do

  task :javascripts, :output do |t, args|

    output = args[:output] or raise "Missing output argument"
    app = Release.app(output)
    vendor = Release.vendor(output)
  end

  task :stylesheets, :output do |t, args|
    output = args[:output] or raise "Missing output argument"
    system 'compass', 'compile', '--quiet', '--relative-assets',
           '-e', 'production',
           '--css-dir', output.to_s, '--images-dir', output.join('images').to_s

    FileUtils.cp_r(Dir['app/assets/stylesheets/*.css'], output)
  end

  task :fonts, :output do |t, args|
    output = args[:output] or raise "Missing output argument"
    FileUtils.cp_r 'app/vendor/font-awesome/font', output
  end

  task :images, :output do |t, args|
    output = args[:output] or raise "Missing output argument"
    FileUtils.cp_r 'app/assets/images', output
  end
end
