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
    return format("%.3f", memory_usage) + "M"
  end

  def cpu_time
    return Benchmark.times.utime + Benchmark.times.stime
  end
  def cpu_time_str
    return format("%.3f", cpu_time) + "s"
  end

  class KayaDebug
    private_class_method :new
    @debug_levels = Hash.new
    def self.debug(type, level, *what)
      return if @debug_levels.empty?
      if is_debug?(type, level)
        text = "[#{type.to_s.camelize} #{level.to_s}] "+format(*what)
        #text = "[#{type.to_s.humanize} #{level.to_s}] "+format(*what)
        #text = "[#{type.to_s.titlize} #{level.to_s}] "+format(*what)
        puts text
        Rails.logger.add(Logger::DEBUG, "#{text}") if Rails.logger
      end
    end
    def self.set_debug(type, level)
      @debug_levels[type] = level
    end
    def self.set_debugs(levels)
      @debug_levels[type].merge(levels)
    end
    def self.clear_debug(type=nil)
      if type
        @debug_levels.delete(type)
      else
        @debug_levels.clear
      end
    end
    def self.is_debug?(type, level)
      return false if @debug_levels.empty?
      debug_level = @debug_levels[type]
      debug_level ||= @debug_levels[:all]
      return (debug_level && level <= debug_level)
    end
    def self.what_debugs
      @debug_levels.each_pair {|type, level|
        puts "[#{type.to_s.camelize} #{level.to_s}] "
      }
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
  def cdebug(*what)
    text = format(*what)
    puts text
    Rails.logger.add(Logger::DEBUG, "#{text}") if Rails.logger
  end
  def what_debugs
    return KayaDebug.what_debugs
  end

  # Prevent them be implemented into class as mixin
  module_function :debug, :set_debug, :set_debugs, :clear_debug, :is_debug?, :cdebug, :what_debugs,
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

  def safe_run(&block)
    safe_lock
    block.call if block
    safe_unlock
  end

  def safe_lock(&block)
    begin
      lock
    rescue ThreadError
    end
  end

  def safe_unlock
    begin
      unlock
    rescue ThreadError
    end
  end

end
