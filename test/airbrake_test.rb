require 'test_helper'

begin
  require 'airbrake_notifier'
rescue LoadError
  warn "Install airbrake gem to run Airbrake tests."
end

if defined? AirbrakeNotifier
  context "Airbrake" do
    test "should be notified of an error" do
      exception = StandardError.new("BOOM")
      worker = Resque::Worker.new(:test)
      queue = "test"
      payload = {'class' => Object, 'args' => 66}

      Airbrake.expects(:notify_or_ignore).with(
        exception,
        :parameters => {:payload_class => 'Object', :payload_args => '66'})

      backend = Resque::Failure::Airbrake.new(exception, worker, queue, payload)
      backend.save
    end
  end
end
