require 'kaya_base'

class KayaTimer

  attr_accessor :interval, :start_cycle, :end_cycle, :paused

  alias :paused? :paused

  def initialize(options={})
    set_options(options)
    @timer_thread = nil
    @timer_mutex = nil
    @timer_pauser = nil
    @run_block = nil
    self.paused = true
  end
  
  def ticking?
    @timer_thread && @timer_thread.alive?
  end

  def start(options={}, &block)
    set_options(options)
    stop
    if (block && interval > 0.0 && start_cycle >= 0 &&
        (!shall_check_end_cycle? || start_cycle <= end_cycle))
      @run_block = block
      @timer_mutex = Mutex.new
      @timer_pauser = Mutex.new
      @timer_thread = Thread.trace_new {
        start_countdown = start_cycle
        end_countdown = shall_check_end_cycle? ? (end_cycle+1) : 1
        while end_countdown > 0
          @timer_pauser.safe_run {}
          if start_countdown <= 0
            # Critital area to prevent conflict with main thread while run the block
            # However, it does not prevent between different timers, need to lock inside block
            debug(:kaya_timer, 2, "timer started ticking at %s", Time.now.getutc)
            critical {@run_block.call}
          else
            start_countdown -= 1
          end
          end_countdown -= 1 if shall_check_end_cycle?
          sleep(@interval.to_f) # interval can be in form like 10.seconds or 1.2minutes
        end
        debug(:kaya_timer, 1, "timer expired at %s", Time.now.getutc)
      }
      self.paused = false
      debug(:kaya_timer, 1, "started timer with interval of %.2fs at %s", interval.second, Time.now.getutc)
      return true
    end
    return false
  end

  def stop
    if ticking?
      @timer_thread.terminate
      @timer_thread.join
      debug(:kaya_timer, 1, "stopped timer with interval of %d at %s", interval, Time.now.getutc)
    end
    @timer_thread = nil
    @timer_mutex.safe_unlock if @timer_mutex; @timer_mutex = nil
    @timer_pauser.safe_unlock if @timer_pauser; @timer_pauser = nil
    @run_block = nil
    self.paused = true
  end

  def pause
    if ticking?
      #@timer_thread.stop
      @timer_pauser.safe_lock
      self.paused = true
      debug(:kaya_timer, 1, "paused timer with interval of %d at %s", interval, Time.now.getutc)
    end
  end

  def resume
    if ticking?
      #@timer_thread.run
      @timer_pauser.safe_unlock
      self.paused = true
      debug(:kaya_timer, 1, "resumed timer with interval of %d at %s", interval, Time.now.getutc)
    end
  end

  def immediate_run(&block)
    debug(:kaya_timer, 2, "run directly at %s", Time.now.getutc)
    block ||= @run_block
    critical {block.call} if block
  end

private

  def set_options(options)
    self.interval = options[:interval] if options[:interval]
    self.start_cycle = options[:start_cycle] if options[:start_cycle]
    self.end_cycle = options[:end_cycle] if options[:end_cycle]
    @mutex = options[:mutex] if options[:mutex]
    self.start_cycle ||= 0  # start from first cycle
    self.end_cycle ||= -1 # forever
    self.interval ||= 0.0 # do not start until a positive value is assigned
  end

  def shall_check_end_cycle?
    return end_cycle >= 0
  end

  def critical(&block)
    if ticking?
      this_mutex = @mutex ? @mutex: @timer_mutex
      this_mutex.safe_run {block.call}
    end
  end

end
