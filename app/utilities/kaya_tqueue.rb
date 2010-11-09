# Dual source queue to sync a message passing scheme and a timer
# Use a single queue and 3 threads.
#   Main thread    : process real time data and push into queue to be processed
#   Timer thread   : push a specific message into queue at given time interval
#   Process thread : take in message feed from queue and process them at back ground
# Main and timer threads lightweight, only create and pass on messages. All the heavy
# lifting shall only be done by process thread.

require 'active_support/core_ext/module/aliasing'
require 'kaya_timer'

module KayaTQueue

  # Internally, defined these class variables:
  #   @tqueue_queue
  #   @tqueue_process_thread
  #   @tqueue_timer
  #   @tqueue_options
  def tqueue_started?
    # tqueue_timer is optional
    @tqueue_queue != nil && @tqueue_process_thread != nil
  end

  def tqueue_start(interval=0.0, options={}, &timer_block)
    # If it is already started, doing nothing here
    if !tqueue_started?
      tqueue_end # make sure we cleaned up everything
      @tqueue_options = options
      @tqueue_queue = Queue.new
      @tqueue_process_thread = Thread.new {
        performable_method = @tqueue_queue.pop
        performable_method.perform
      }
      if interval > 0.0
        @tqueue_timer = KayaTimer.new(:interval=>interval)
        @tqueue_timer.start({}, &timer_block)
      end
    end
  end

  def tqueue_end
    @tqueue_process_thread.terminate
    @tqueue_timer.stop
    @tqueue_options = nil
    @tqueue_queue = nil
    @tqueue_process_thread = nil
    @tqueue_timer = nil
  end

  alias_method :tqueue_check_start, :tqueue_start

  # Proxy class so we can call a method of myclass.mymethod by myclass.tqueue.mymethod
  class TQueueProxy < Struct.new(:queue, :target, :options)
    def initialize(queue, target, options)
      self.queue   = queue
      self.target  = target
      self.options = options
    end
    def method_missing(method, *args)
      queue.push({:payload_object => PreformableMethod.new(target, method.to_sym, args)}.merge(options))
    end
  end

  def tqueue(options={})
    queue = options.delete(:queue)
    queue ||= @tqueue_queue
    all_options = @tqueue_options.clone; all_options.merge!(@options)
    TQueueProxy.new(queue, self, all_options)
  end

  class PerformableMethod < Struct.new(:object, :method_name, :args)
    def initialize(object, method_name, args)
      raise NoMethodError, "undefined method `#{method_name}' for #{object.inspect}" unless object.respond_to?(method_name, true)
      self.object       = object
      self.args         = args
      self.method_name  = method_name.to_sym
    end
    def perform
      object.send(method_name, *args) if object
    end
    def respond_to?(symbol, include_private=false)
      super || object.respond_to?(symbol, include_private)
    end
  end

  module ClassMethods
    def tqueue_asynchronously(method, opts = {})
      aliased_method, punctuation = method.to_s.sub(/([?!=])$/, ''), $1
      with_method, without_method = "#{aliased_method}_with_tqueue#{punctuation}", "#{aliased_method}_without_tqueue#{punctuation}"
      define_method(with_method) {|*args|
        curr_opts = opts.clone
        curr_opts.each_key {|key|
          val = curr_opts[key]
          if val.is_a?(Proc)
            curr_opts[key] = val.arity == 1 ? val.call(self) : val.call
          end
        }
        tqueue(curr_opts).send(without_method, *args)
      }
      alias_method_chain method, :tqueue
    end
  end

end
