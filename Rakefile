require 'rubygems'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

task :default => [:spec]

RSpec::Core::RakeTask.new do |t|
  t.pattern = 'spec/*_spec.rb'
  t.ruby_opts = ['-w']
  # t.rspec_opts = ['-r', 'offline_only']
end
