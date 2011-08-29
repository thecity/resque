$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
require 'resque/tasks'
require 'resque_scheduler/tasks'
task "resque:setup" => :environment do
  # Cache all our database columns on startup so they're handy
  ActiveRecord::Base.send(:subclasses).each { |klass|  klass.columns }
  # Bake in our queue heirarchy
  ENV['QUEUE'] = Resque::Backwards::PRIORITY_HASH.keys.sort.collect {|k| Resque::Backwards::PRIORITY_HASH[k]}.join(',')
  STDOUT.sync = STDERR.sync = true
end

desc "Alias for resque:work (To run workers on Heroku)"
task "jobs:work" => "resque:work"
