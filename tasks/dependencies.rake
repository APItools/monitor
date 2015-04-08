namespace :dependencies do
  dependencies = {
    test: %w[ busted-stable luajson luaexpat ],
    prod: %w[ luajson luaexpat ]
  }

  def check_luarocks(rocks)
    installed = `luarocks list`.split("\n").select{|line| line =~ /^\S/ }
    missing = rocks - installed
    if missing.size == 0
      puts "dependencies ok"
    else
      puts "missing dependencies: " + missing.join(", ")
      exit 1
    end
  end

  desc "checks lua TEST dependencies"
  task :test do
    check_luarocks(dependencies[:test])
  end

  desc "checks lua PRODUCTION dependencies"
  task :prod do
    check_luarocks(dependencies[:prod])
  end

  desc "installs all dependencises"
  task :install do
    unless system 'luarocks --version'
      warn 'missing luarocks'
      exit 1
    end

    required = dependencies.values.reduce(:|)
    installed = required.all? do |name|
      system 'luarocks', 'install', name
    end

    exit installed
  end
end
