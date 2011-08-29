require 'resque'

# Make resque workers start the NewRelic agent
Resque.before_first_fork do
  NewRelic::Agent.manual_start(:dispatcher => :resque)
end
# Won't actually be done since we don't fork, but w/e
Resque.after_fork do
  NewRelic::Agent.after_fork(:force_reconnect => false)
end

# Make any class a Resque job with exponential backoff
Object.send(:include, Resque::Backwards)   
Module.send(:include, Resque::Backwards::ClassMethods)
Module.send(:include, Resque::Plugins::ExponentialBackoff)