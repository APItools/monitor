require 'guard'
require 'guard/guard'
require 'guard/watcher'

module Guard
  class Concat < Guard
    def initialize(watchers=[], opts={})
      @opts = opts
      watchers << ::Guard::Watcher.new(matcher_regex)
      super(watchers, opts)
    end

    def start
      run_all if all_on_start?
    end

    def run_all
      concat
    end

    def run_on_changes(paths)
      concat
    end

    # The actual concat method
    #
    # scans the :files passed as options
    # supports * and expands them requiring all files in that path/folder

    def concat
      file_names = files.map do |file|
        single?(file) ? full_path(file) : expand(file)
      end

      content = file_names.flatten.reduce("") do |content, file|
        content << File.read(file)
        content << "\n"
      end

      File.open(output_file, "w"){ |f| f.write content.strip }

      UI.info "Concatenated #{file_names.join(', ')} to #{output_file}"
    end

    def full_path(file)
      path = "#{input_dir}/#{file}"
      path << ".#{type}" unless path =~ /\.#{type}$/
      path
    end

    def matcher_regex
      all_files = files.map{|f| f.sub(/\*$/, '.+') }.join("|")
      %r|^#{input_dir}/(#{all_files})\.#{type}$|
    end

    def files
      @opts.fetch(:files)
    end

    def input_dir
      @opts.fetch(:input_dir)
    end

    def type
      @opts.fetch(:type)
    end

    def output_file
      @output_file ||= "#{@opts.fetch(:output)}.#{type}"
    end

    def all_on_start?
      !!@opts[:all_on_start]
    end

    private

    # handle the star option (*)

    def single?(file)
      file !~ /\*/
    end

    def expand(file)
      Dir.glob full_path(file)
    end

  end
end
