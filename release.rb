require 'yaml'

require 'pathname'
require 'coffee_script'

require 'erb'
require 'ostruct'

require 'uglifier'

require 'active_support/core_ext/hash/keys'

Encoding.default_external = 'UTF-8'
Encoding.default_internal = 'UTF-8'

module Release extend self

  def configs
    @configs ||= YAML.load_file('release.yml')
  end

  def config_for(name, output)
    config = configs.fetch(name)

    input = config.fetch('input')
    name = config.fetch('name')
    files = config.fetch('files')

    output = Pathname(output).join(name)
    input = Pathname(input)

    [input, output, files]
  end

  def tmpdir
    Dir.mktmpdir('assets')
  end

  def say(msg)
    puts msg if ENV['DEBUG']
  end

  def concat(files, compiler)
    contents = files.map(&:read)
    output = contents.join("\n")

    compiler.compile(output)
  end

  def uglifier(name)
    config = configs.fetch(name)
    options = config.fetch('uglify')
    options = options.deep_symbolize_keys

    puts "Compressing #{name} by uglifier with options: #{options}"
    Uglifier.new(options)
  end

  def app(output)
    input, output, files = config_for('app', output)

    compiled = coffee(input, tmpdir)
    app = concat(compiled, uglifier('app'))

    output.open('w') do |io|
      io.puts(app)
    end

    output
  end

  def vendor(output)
    pack('vendor', output)
  end

  def pack(name, output)
    input, output, files = config_for(name, output)

    files.map! { |file| input.join(file) } # create proper paths

    packed = concat(files, uglifier(name))

    output.open('w') do |io|
      io.puts(packed)
    end

    output
  end

  private :pack

  def coffee(input, output)
    base = Pathname(input)
    pattern = base.join('**').join('*.coffee')
    output = Pathname(output)

    paths = Pathname.glob(pattern).map do |file|
      begin
        compiled = CoffeeScript.compile(file)
      rescue ExecJS::RuntimeError
        warn "Error compiling #{file} : #{$!}"
        exit 1
      end

      relative_path = file.relative_path_from(base)

      full_path = output.join(relative_path).sub_ext('.js')
      full_path.dirname.mkpath
      full_path.open('w') do |io|
        io.puts compiled
        say "Compiled #{file} to #{full_path}"
      end

      full_path
    end

    # sort files so controllers.js is before controllers/whatever.js
    paths.sort_by { |file| file.relative_path_from(output).to_path }
  end

  def erb(src, config)
    context = OpenStruct.new(config)
    binding = context.instance_eval{ __send__(:binding) }

    ERB.new(src).result(binding)
  end

  def production?
    release == 'production'
  end

  def test?
    release == 'test'
  end

  def nginx(input)
    config = configs.fetch('nginx')

    config['logging'] = production? unless config.has_key?('logging')
    config['release'] = release

    if root = config['root']
      config['root'] = Pathname(root)
    end

    input = Pathname(input)
    dir = input.dirname

    config['include'].map! do |include|
      content = dir.join(include).read
      erb(content, config)
    end

    if test?
      brain = dir.join('brain.conf').read
      config['include'] << erb(brain, config)
    end

    nginx = erb(input.read, config)

    tmpfile = Tempfile.new('nginx')
    tmpfile.write(nginx)
    tmpfile.rewind
    tmpfile
  end

  private

  def release
    ENV['RELEASE']
  end
end
