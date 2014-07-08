require 'rake/testtask'
require 'bundler/gem_tasks'

task :default => :test

Rake::TestTask.new do |t|
  t.pattern = 't/**/*.rb'
  t.verbose = true
end

begin
  require 'yard'
  YARD::Rake::YardocTask.new
rescue LoadError
end

