unless $stdin.tty?
  interactor :off
end

guard 'coffeescript', all_on_start: true, input: 'app/assets/javascripts', output: 'app/assets/javascripts/compiled'

reload_nginx = proc do |m|
  next if m[1].end_with?('_spec') && m[1].start_with?('spec/') # do not reload because of specs
  puts "#{Time.now} - reloading nginx because of #{m.inspect}"
  `nginx -s reload -p . -c config/dev.conf`
end

guard :shell do
  watch(%r|^lua/(?!spec/)(.+)(?!_spec)\.lua$|, &reload_nginx)
  watch(%r|^nginx\.conf(.compiled)?$|, &reload_nginx)
  watch(%r|^config\/(.+?)\.conf$|, &reload_nginx)
end

require './release'

vendor = Release.configs.fetch('vendor')
app = Release.configs.fetch('app')

guard :concat, type: "js", files: vendor['files'],
      input_dir: vendor['input'],
      output: "app/assets/compiled/vendor",
      all_on_start: true

guard :concat, type: "js", files: app['files'],
      input_dir: "app/assets/javascripts/compiled",
      output: "app/assets/compiled/app",
      all_on_start: true

guard 'livereload' do
  watch(%r{app/assets/(\w+)/compiled/(.+\.css)$}){|m| "/#{m[1]}/#{m[2]}" }
end

$last_busted_run = []

def busted(*files)
  puts "Last run: #{$last_busted_run.inspect}"
  last_failed = $last_busted_run.compact.select{|run| !run.last }.map(&:first)
  puts "Last failed: #{last_failed.inspect}"
  run =  last_failed | files.flatten
  puts "Running: #{run.inspect}"

  busted = File.expand_path('script/busted')

  $last_busted_run = run.map do |file|
    next unless File.exists?(file)
    puts "Running busted #{file}"
    [file, system(busted, file)]
  end

  if $last_busted_run.empty?
    system(busted)
  end
end

guard :shell do
  watch(%r|lua/((?!spec/).+\.lua)$|) do |m|
    parts = m[1].split('/').reduce([]){ |acc, v| acc.push(([acc.last].compact + [v]).flatten) }
    parts.map!{|part| 'lua/spec/' + part.join('/') + '_spec.lua' }

    busted(*parts)
  end
  watch(%r|lua/spec/util/.+\.lua$|) {|m| busted() }
  watch(%r|lua/spec/.+_spec\.lua$|) {|m| busted(m[0]) }
end
