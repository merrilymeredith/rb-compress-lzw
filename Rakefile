require 'rake/testtask'

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'lzw'


task :default => :test

desc "Builds the gem"
task :gem do
  sh "gem build compress-lzw.gemspec"
end

desc "Installs the gem"
task :install => :gem do
  sh "gem install compress-lzw-#{LZW::VERSION}.gem --no-rdoc --no-ri"
end

Rake::TestTask.new do |t|
  t.pattern = 't/**/*.rb'
  t.verbose = true
end

begin
  require 'yard'
  YARD::Rake::YardocTask.new
rescue LoadError
end

