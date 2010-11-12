# Dual source queue to sync a message passing scheme and a timer
# Use a single queue and 3 threads.
#   Main thread    : process real time data and push into queue to be processed
#   Timer thread   : push a specific message into queue at given time interval
#   Process thread : take in message feed from queue and process them at back ground
# Main and timer threads lightweight, only create and pass on messages. All the heavy
# lifting shall only be done by process thread.

require 'active_support/core_ext/module/aliasing'
require 'kaya_base'
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

  def tqueue_start(interval=0.0, start_cycle=0, options={}, &timer_block)
    # If it is already started, doing nothing here
    if !tqueue_started?
      tqueue_end # make sure we cleaned up everything
      @tqueue_options = options
      @tqueue_queue = Queue.new
      @tqueue_process_thread = Thread.trace_new {
        while true
          payload = @tqueue_queue.pop
          performable_method = payload[:payload_object]
          #options = payload.delete(:payload_object)
          performable_method.perform
        end
      }
      if interval > 0.0 && timer_block
        @tqueue_timer = KayaTimer.new(:interval=>interval)
        @tqueue_timer.start({:start_cycle=>start_cycle}, &timer_block)
      end
      debug(:kaya_tqueue, 1, "started tqueue %sat %s",
            (@tqueue_timer ? "with timer #{format("%.2fs", interval.to_f)} " : ""),
            Time.now.getutc)

    end
  end

  def tqueue_end
    if tqueue_started?
      @tqueue_process_thread.terminate
      @tqueue_process_thread.join
      @tqueue_timer.stop if @tqueue_timer
      debug(:kaya_tqueue, 1, "ended tqueue at %s", Time.now.getutc)
    end
    @tqueue_options = nil
    @tqueue_queue = nil
    @tqueue_process_thread = nil
    @tqueue_timer = nil
  end

  alias_method :tqueue_check_start, :tqueue_start

  # Proxy class so we can call a method of myclass.mymethod by myclass.tqueue.mymethod
  class TQueueProxy
    attr_accessor :queue, :target, :options
    def initialize(queue, target, options)
      self.queue   = queue
      self.target  = target
      self.options = options
    end
    def method_missing(method, *args, &block)
      # This could be call when tqueue is not started yet. In such case, the queue will be nil.
      # We shall not panic, just simply ignore it.
      if queue
        performable = PerformableMethod.new(target, method, args, block)
        queue.push(options.merge(:payload_object=>performable))
        debug(:kaya_tqueue, 2, "pushed into queue for method %s %s %s on class %s",
              method.to_s, args.to_s, block.to_s, target.class.to_s)
      end
    end
  end

  def tqueue(options={})
    queue = options.delete(:queue)
    queue ||= @tqueue_queue
    all_options = options.clone
    all_options.merge!(@tqueue_options) if @tqueue_options
    TQueueProxy.new(queue, self, all_options)
  end

  class PerformableMethod
    attr_accessor :object, :method, :args, :block
    def initialize(object, method, args, block)
      raise NoMethodError, "undefined method `#{method}' for #{object.inspect}" unless object.respond_to?(method, true)
      self.object       = object
      self.method       = method.to_sym
      self.args         = args
      self.block        = block
    end
    def perform
      object.send(method, *args, &block) if object
      debug(:kaya_tqueue, 2, "invoked method %s %s %s on class %s from queue",
            method.to_s, args.to_s, block.to_s, object.class.to_s)
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


class KayaTQueueTest
  include KayaTQueue
  def run(&block)
    block.call if block
  end
end
