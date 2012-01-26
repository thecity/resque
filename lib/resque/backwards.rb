# Define some helpful methods that let us call Resque like delayed_job
module Resque
  
  require 'resque_scheduler'
  require 'newrelic_rpm'
  
  module Backwards
    
    PRIORITY_HASH = {-2 => 'control', -1 => 'critical',0 => 'urgent', 1 => 'high',2 => 'medium',3 => 'low',4 => 'slow',5 => 'slowest',6 => 'bulk'}
    
    # only for the scheduler
    def queue
      "low"
    end

    def before_perform_verify_connection
      ActiveRecord::Base.connection_handler.verify_active_connections!
    end
    
    def resque_send_later(method, *args)
      Resque.enqueue_with_queue("low",self.class, self.id, method, *args)
    end
    
    def resque_send_later_with_priority(priority,method,*args)
      priority_queue = Resque::Backwards::PRIORITY_HASH[priority]
      Resque.enqueue_with_queue(priority_queue,self.class, self.id, method, *args)
    end
    
    def resque_send_at_without_priority(run_at,method,*args)
      # from resque_scheduler
      Resque.enqueue_at(run_at, self.class, self.id, method,*args)
    end

    def resque_send_at_with_priority(priority,run_at,method,*args)
      priority_queue = Resque::Backwards::PRIORITY_HASH[priority]
      # from resque_scheduler
      Resque.enqueue_at_with_queue(priority_queue,run_at, self.class, self.id, method,*args)
    end
    
    module ClassMethods
      include NewRelic::Agent::Instrumentation::ControllerInstrumentation

      def before_perform_verify_connection
        ActiveRecord::Base.connection_handler.verify_active_connections!
      end
      
      # In Resque, classes that do jobs have to have a #perform method for them to do.
      # The inclusion in init.rb of this file in Module and Object
      # defines a #perform for everything that understands an ID, method, and args to execute
      # during Resque::Job#perform
      def perform(*args)
        AllModelObserver.enable_global_view
        id, method = args.shift(2)
        
        perform_action_with_newrelic_trace(:name => method, 
                                           :class_name => name, 
                                           :category => 'OtherTransaction/ResqueJob',
                                           :params => {:arguments => args}) do
          obj = id ? find_by_id(id) : self
          unless obj.blank?
            obj.send(method, *args)
          end
        end
      end
      
      def resque_send_later(method, *args)
        Resque.enqueue_with_queue("slowest",self, nil, method, *args)
      end

      def resque_send_later_with_priority(priority,method,*args)
        priority_queue = Resque::Backwards::PRIORITY_HASH[priority]
        Resque.enqueue_with_queue(priority_queue,self, nil, method, *args)
      end
      
      def resque_send_at_without_priority(run_at,method,*args)
        # from resque_scheduler
        Resque.enqueue_at(run_at, self, nil, method,*args)
      end
      
      def resque_send_at_with_priority(priority,run_at,method,*args)
        priority_queue = Resque::Backwards::PRIORITY_HASH[priority]
        # from resque_scheduler
        Resque.enqueue_at_with_queue(priority_queue,run_at, self, nil, method,*args)
      end

      # If you want to force a method to only run in resque in a send_later context.
      def resque_handle_asynchronously(method)
        aliased_method, punctuation = method.to_s.sub(/([?!=])$/, ''), $1
        with_method, without_method = "#{aliased_method}_with_send_later#{punctuation}", "#{aliased_method}_without_send_later#{punctuation}"
        define_method(with_method) do |*args|
          resque_send_later_with_priority(3,without_method, *args)
        end
        alias_method_chain method, :resque_send_later
      end

    end
  end                               
end