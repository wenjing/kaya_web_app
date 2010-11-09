require 'benchmark'

module KayaBase

  # select the first none nil member from the parameters, otherwise return nil
  def select_if_not_nil(*values)
    values.each {|value| return value if value}
    return nil
  end

  def memory_usage
    return `ps -o rss= -p #{Process.pid}`.to_i/1024.0
  end
  def memory_usage_str
    return ("%.3f" % memory_usage) + "M"
  end

  def cpu_time
    return Benchmark.times.utime + Benchmark.times.stime
  end
  def cpu_time_str
    return ("%.3f" % cpu_time) + "s"
  end

  class KayaDebug
    @debug_levels = Hash
    def debug(type, level, *what)
      debug_level = @debug_options.empty? ? nil : @debug_options[type]
      if (debug_level && debug_level <= level) 
        text = type.to_s+": "+format(*what)
        logger.add Logger::INFO, "#{text}" if logger
      end
    end
    def set_debug(type, level)
      @debug_levels[type] = level
    end
    def set_debugs(levels)
      @debug_levels[type].merge(levels)
    end
    def clear_debug(type=nil)
      if type
        @debug_levels.clear
      else
        @debug_levels.delete(type)
      end
    end
    def is_debug?(type, level)
      return !@debug_options.empty && @debug_options[type] && @debug_options[type] <= level
    end
  end

  def debug(type, level, *what)
    KayaDebug.debug(type, level, *what)
  end
  def set_debug(type, level)
    KayaDebug.set_debug(type, level)
  end
  def set_debugs(levels)
    KayaDebug.set_debug(levels)
  end
  def clear_debug(type=nil)
    KayaDebug.clear_debug(type)
  end
  def is_debug?(type, level)
    return KayaDebug.is_debug?(type, level)
  end
  def nondebug(*what)
    text = format(*what)
    puts text
    logger.add Logger::INFO, "#{text}" if logger
  end

  # Prevent them be implemented into class as mixin
  module_function :debug, :set_debug, :set_debugs, :clear_debug,
                  :select_if_not_nil, :cpu_time, :cpu_time_str,
                  :memory_usage, :memory_usage_str

end

include KayaBase


#  Add methods to Enumerable, which makes them available to Array
module Enumerable
 
  # Sum of an array of numbers
  def sum
    return self.inject(0) {|acc, i| acc + i}
  end

  # Average of an array of numbers
  def average
    return self.sum/self.length.to_f
  end
 
  # Variance of an array of numbers
  def sample_variance
    avg = self.average
    sum = self.inject(0) {|acc, i| acc + (i-avg)**2}
    return (1/self.length.to_f*sum)
  end
 
  # Standard deviation of an array of numbers
  def standard_deviation
    return Math.sqrt(self.sample_variance)
  end

  alias :sigma :standard_deviation
  alias :mean  :average

  # Mean and Stddev as a pair
  def mean_sigma
    return [mean, sigma]
  end
 
end  #  module Enumerable


class Mutex

  def safe_lock(&block)
    begin
      lock
    rescue ThreadError
    end
    block.call
    begin
      unlock
    rescue ThreadError
    end
  end

end
