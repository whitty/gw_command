require 'rubygems'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

task :default => [:spec]

#require 'rake/testtask'
#
## how to add dependencies:   => [:compile]
#Rake::TestTask.new :test do |t|
#  t.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
#  t.warning = true
#end


$rspec_opts = [ '-I', 'test', ]

RSpec::Core::RakeTask.new do |t|
  t.pattern = 'spec/*_spec.rb'
  t.ruby_opts = ['-w']
  t.rspec_opts = $rspec_opts # + ['-r', 'offline_only']
end

#RSpec::Core::RakeTask.new(:spec_online) do |t|
#  t.pattern = 'test/_*.rb'
#  t.ruby_opts = ['-w']
#  t.rspec_opts = $rspec_opts
#end
