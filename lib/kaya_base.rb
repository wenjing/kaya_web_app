require 'benchmark'
require 'active_support'
require 'active_support/inflector'

module KayaBase

  # select the first none nil member from the parameters, otherwise return nil
  def select_if_not_nil(*values)
    values.each {|value| return value if value}
    return nil
  end

  def pluralize(number, text)
    return "#{number} #{number > 1 ? text.pluralize : text}"
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
    #cattr_accessor :debug_levels
    def self.debug(type, level, *what)
      return if @debug_levels.blank?
      if is_debug?(type, level)
        text = "[#{type.to_s.camelize} #{level.to_s}] "+format(*what)
        #text = "[#{type.to_s.humanize} #{level.to_s}] "+format(*what)
        #text = "[#{type.to_s.titlize} #{level.to_s}] "+format(*what)
        puts text
        Rails.logger.add(Logger::DEBUG, "#{text}") if Rails.logger
      end
    end
    def self.cdebug(*what)
      text = " --- "+format(*what)
      puts text
      Rails.logger.add(Logger::DEBUG, "#{text}") if Rails.logger
    end
    def self.set_debug(type, level)
      @debug_levels ||= Hash.new
      @debug_levels[type] = level
    end
    def self.set_debugs(levels)
      @debug_levels ||= Hash.new
      @debug_levels[type].merge(levels)
    end
    def self.clear_debug(type=nil)
      return if @debug_levels.blank?
      if type
        @debug_levels.delete(type)
      else
        @debug_levels.clear
      end
    end
    def self.is_debug?(type, level)
      return false if @debug_levels.blank?
      debug_level = @debug_levels[type]
      debug_level ||= @debug_levels[:all]
      return (debug_level && level <= debug_level)
    end
    def self.what_debugs
      return if @debug_levels.blank?
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
    KayaDebug.cdebug(*what)
  end
  def what_debugs
    return KayaDebug.what_debugs
  end

  # Prevent them be implemented into class as mixin
  module_function :debug, :set_debug, :set_debugs, :clear_debug, :is_debug?, :cdebug, :what_debugs,
                  :select_if_not_nil, :pluralize,
                  :cpu_time, :cpu_time_str, :memory_usage, :memory_usage_str

end

include KayaBase


require 'statistics2'
include Math
class Array

  # 2 levels random. First random select a segment. Then, random pick a value within
  # each segment.
  def random
    return 0.0 if size < 1
    seg_count = size - 1;
    return first if seg_count < 1
    seg = (seg_count * rand).floor
    return self[seg] + rand * (self[seg+1] - self[seg])
  end

  # Sample random distribution. An asymetry normal distribution defined by 3 values:
  # mean, left_limit, right_limit (3 sigma)
  def random_dist
    return 0.0 if size < 3
    raw = Statistics.pnormaldist([0.0, 1.0].random)
    if raw <= 0.0
      sample = self[0] + raw * (self[0]-self[1])/3.0
      sample = [sample, self[0]].max
    else
      sample = self[0] + raw * (self[2]-self[1])/3.0
      sample = [sample, self[2]].min
    end
  end

end

#  Add methods to Enumerable, which makes them available to Array
module Enumerable
 
  # Sum of an array of numbers
  def summ
    return self.inject(0) {|acc, i| acc + i}
  end

  # Average of an array of numbers
  def average
    return self.summ/self.length.to_f
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

  # Mean and sigma as a pair
  def mean_sigma
    return [mean, sigma]
  end

  # Get mean, sigma with errs (each sample's error)
  def mean_sigma_with_weight(weights)
    return [nil, nil] if empty? || weights.size != size
    ii = 0; sum_val = 0.0; sum_weight = 0.0
    (0...size).each {|ii|
      val, weight = self[ii], weights[ii]
      sum_val += val * weight
      sum_weight += weight
    }
    avg = sum_val / sum_weight
    sum_variance = 0.0
    (0...size).each {|ii|
      val, weight = self[ii], weights[ii]
      sum_variance += (val-avg) * (val-avg) * weight
    }
    return [avg, Math.sqrt(sum_variance/sum_weight)]
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


class Thread

  def self.trace_new(&block)
    new {
      begin
        block.call
      rescue Exception => e
        puts e.to_s
        puts e.backtrace
      end
    }
  end

end


require 'qq'
class Object

  def grep_methods(str)
    #methods.each {|m|
    #  puts m if (/^#{str}$/ =~ m)
    #}
    PP.pp((methods.select {|m| /^#{str}$/ =~ m}), ml)
    puts ml
  end

  def list_methods
    #grep_methods(".*")
    PP.pp(methods, ml)
    puts ml
  end

end

require 'json'
