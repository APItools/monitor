namespace :lint do
  task :coffee do
    files = Dir['app/assets/javascripts/**/*.coffee']
    exec('coffeelint', *files)
  end

  task :scss do
    files = Dir['app/assets/stylesheets/**/*.scss']
    exec('scss-lint', *files)
  end

  task :lua do
    files = Dir['lua/**/*.lua']
    exec('scripts/lua-releng', *files)
  end
end
