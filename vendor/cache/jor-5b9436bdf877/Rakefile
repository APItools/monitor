require 'rake/testtask'
require 'bundler/gem_tasks'

desc 'Run all unit tests'

Rake::TestTask.new(:test) do |task|
  task.test_files = FileList['test/unit/**/*_test.rb']
  task.verbose = true
end

