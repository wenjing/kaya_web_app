require 'benchmark'
require 'active_support'
require 'active_support/inflector'

module KayaBase

  # Force garbage collection
  def force_gc
    #puts ObjectSpace.count_objects
    10.times {ObjectSpace.garbage_collect}
    #puts ObjectSpace.count_objects
    #sleep wait_time if wait_time > 0
  end

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

  def exception_protected(try_limit=1)
    try_count = 0
    while true
      begin
        try_count += 1
        yield
        break
      rescue Exception => e
        if try_count >= try_limit
          puts e.to_s
          puts e.backtrace
          break
        end
      end
    end
  end

  def parallel_run(num, enum=nil, &block)
    return unless (num >= 0 && block)
    if num == 0
      if !enum
        block.call(0)
      else
        enum.each {|val| block.call(val)}
      end
    else
      threads = Array.new
      if !enum
        (0...num).each {|no|
          threads << Thread.protected_new {block.call(no)}
        }
      else
        assignments = ((0...enum.size).to_a.fill {|i| i%num}).shuffle
        (0...num).each {|no|
          threads << Thread.protected_new {
            enum.each_with_index {|val, index|
              block.call(val) if assignments[index] == no
            }
          }
        }
      end
      threads.each {|thread| thread.join}
    end
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
        if (Rails.logger && Rails.logger.level <= Logger::DEBUG)
          Rails.logger.add(Logger::DEBUG, "#{text}")
        else
          puts text 
        end
      end
    end
    def self.cdebug(*what)
      text = " --- "+format(*what)
      if (Rails.logger && Rails.logger.level <= Logger::DEBUG)
        Rails.logger.add(Logger::DEBUG, "#{text}")
      else
        puts text 
      end
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
                  :cpu_time, :cpu_time_str, :memory_usage, :memory_usage_str,
                  :exception_protected, :parallel_run

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
    # Faker mixin its own rand function into array, have to use send(:func) to use the original one
    seg = (seg_count * Object.send(:rand)).floor
    return self[seg] + Object.send(:rand) * (self[seg+1] - self[seg])
  end

  # Sample random distribution. An asymetry normal distribution defined by 3 values:
  # mean, left_limit, right_limit (3 sigma)
  def random_dist
    return 0.0 if size < 3
    raw = Statistics2.pnormaldist([0.0, 1.0].random)
    if raw <= 0.0
      sample = self[0] + raw * (self[0]-self[1])/3.0
      sample = [sample, self[1]].max
    else
      sample = self[0] + raw * (self[2]-self[1])/3.0
      sample = [sample, self[2]].min
    end
  end

  # Probability random selector. Randomly pick a value between 0 and 1.
  # Return the index that random value fall into.
  # For example: [0.3].random_prob => 0 if random<=0.3 otherwise 1
  def random_prob
    val = [0.0, 1.0].random
    res = each_with_index {|v,i| break i if val <= v}
    res = size if res.is_a?(Array)
    return res
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

  def parallel_each(num, &block)
    num <= 0 ? each(&block) : parallel_run(num, self, &block)
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

  def self.protected_new(&block)
    new {exception_protected {block.call}}
  end

end


require 'pp'
class Object

  def list_methods(str=".*")
    PP.pp(methods.sort.select {|m| /^#{str}.*$/ =~ m})
  end

  def to_params(*vars)
    res = Hash.new
    vars.each {|var|
      var = var.to_sym
      res[var] = send(var) if respond_to?(var)
    }
    return res
  end

end


require 'json'
require 'rest_client'
module RestClient
  class Resource
    def cookies(cookies)
      @cookies = cookies
      return self
    end
    def get_json(params={}, headers={})
      rsp = nil
      3.times {
        rsp = get_with_payload(params, headers_json(headers)) {|response, request, res, &block| response}
        self.cookies(rsp.cookies) if rsp.ok?
        break if !rsp.network_error?
      }
      return rsp
    end
    def put_json(params={}, headers={})
      rsp = nil
      3.times {
        rsp = put(params, headers_json(headers)) {|response, request, res, &block| response}
        self.cookies(rsp.cookies) if rsp.ok?
        break if !rsp.network_error?
      }
      return rsp
    end
    def post_json(params={}, headers={})
      rsp = nil
      3.times {
        rsp = post(params, headers_json(headers)) {|response, request, res, &block| response}
        self.cookies(rsp.cookies) if rsp.ok?
        break if !rsp.network_error?
      }
      return rsp
    end
    def delete_json(params={}, headers={})
      rsp = nil
      3.times {
        rsp = delete_with_payload(params, headers_json(headers)) {|response, request, res, &block| response}
        self.cookies(rsp.cookies) if rsp.ok?
        break if !rsp.network_error?
      }
      return rsp
    end
    private
      def headers_json(headers={})
        return {:cookies=>@cookies, :content_type => :json, :accept => :json}.merge(headers)
      end
      def get_with_payload(payload=nil, additional_headers={}, &block)
        headers = (options[:headers] || {}).merge(additional_headers)
        Request.execute(options.merge(
                :method => :get,
                :url => url,
                :payload => payload,
                :headers => headers), &(block || @block))
      end
      def delete_with_payload(payload=nil, additional_headers={}, &block)
        headers = (options[:headers] || {}).merge(additional_headers)
        Request.execute(options.merge(
                :method => :delete,
                :url => url,
                :payload => payload,
                :headers => headers), &(block || @block))
      end
  end
  module Response
    def body_json(key=nil)
      return nil unless ok?
      return key ? JSON::parse(body)[key] : JSON::parse(body)
    end
    def ok?
      return code >= 200 && code < 300
    end
    def network_error?
      return code == 502
    end
  end
end

class Time
  def time_only
    return strftime("%H:%M:%S")
  end

  def time_ampm
    return strftime("%I:%M:%S%p")
  end

  def date_only
    return strftime("%Y-%m-%d")
  end
end

class Range
  def between(val)
    if first < last
      return [[val, first].max, last].min
    else
      return [[val, last].max, first].min
    end
  end

  def overlap(range)
    res_first = range.between(first)
    res_last = range.between(last)
    if (include?(res_first) && range.include?(res_first))
      if include?(res_last) && range.include?(res_last)
        return (res_first..res_last)
      else
        return (res_first...res_last)
      end
    end
    return nil
  end
end

class Hash
  def transform(&block)
    return merge(self) {|k,v1,v2| block.call(v1)}
  end

  def transform!(&block)
    return merge!(self) {|k,v1,v2| block.call(v1)}
  end

  def sort_by_key(&block)
    return sort_by {|x| block ? block.call(x[0]) : x[0]}
  end

  def sort_by_value(&block)
    return sort_by {|x| block ? block.call(x[1]) : x[1]}
  end
end

module KayaMath
  def at_least(val)
    return [self, val].max
  end

  def at_most(val)
    return [self, val].min
  end
end

class Fixnum
  include KayaMath
end

class Float
  include KayaMath
end

module Rails
  @@kaya_dbmutex = nil
  def self.kaya_dblock(&block)
    if @@kaya_dbmutex 
      @@kaya_dbmutex.safe_run(&block)
    else
      block.call
    end
  end
  def self.kaya_dblock=(flag)
    @@kaya_dbmutex = flag ? Mutex.new : nil
  end
  def self.kaya_dblock?
    return @@kaya_dbmutex != nil
  end
end

require 'time'
require 'active_record'
module Cursorize
  module Base
    # Parameters:
    #   :after_time, :before_time, :from_index, :to_index, :max_count
    # If all params are missing, the whole array is returned.
    # Assuming the array is sorted by time and each array member has a time method,
    # default is :time, which can be changed by option.
    def self.cursorize_cursor(params, filters)
      cursor = Hash.new
      # For backward compatibility, still keep max_count and to_index
      limit = params["limit"] || params["max_count"] 
      limit = limit.to_i.at_least(0) if limit.present?
      offset = params["offset"] || params["from_index"]
      offset = offset.to_i.at_least(0) if offset.present?
      to_index = params["to_index"]
      if to_index.present? # calculate limit from it
        to_limit = to_index.to_i
        to_limit = to_limit - offset + 1 if offset
        to_limit = [to_limit, limit].min if limit.present?
        limit = to_limit.at_least(0)
      end
      cursor[:limit] = limit if limit.present?
      cursor[:offset] = offset if offset.present?
      params.delete("limit"); params.delete("max_count"); params.delete("offset")
      params.delete("from_index"); params.delete("to_index");

      params.each {|key, value|
        type, attr = *key.split("_", 2)
        next if (type.blank? || attr.blank?)
        next unless (filters.blank? || filters == attr.to_sym || filters.include?(attr.to_sym))
        if (type == "order" && ["ASC", "DESC"].include?(value.upcase)) # only one type of sort
          (cursor[:order]||=Hash.new)[attr] = value.upcase
        elsif (type == "before" || type == "after") # Time
          ii = type == "after" ? 0 : 1
          ((cursor[:where]||=Hash.new)[attr]||=Array.new)[ii] = Time.zone.parse(value)
        elsif (type == "from" || type == "to") # Fixnum
          ii = type == "from" ? 0 : 1
          ((cursor[:where]||=Hash.new)[attr]||=Array.new)[ii] = value.to_i
        elsif (type == "larger" || type == "smaller") # Float
          ii = type == "larger" ? 0 : 1
          ((cursor[:where]||=Hash.new)[attr]||=Array.new)[ii] = value.to_f
        elsif (type == "start" || type == "end") # String
          ii = type == "start" ? 0 : 1
          ((cursor[:where]||=Hash.new)[attr]||=Array.new)[ii] = value
        end
      }
      return cursor
    end
  end

  module ActiveRecord
    def self.enable!
      ::ActiveRecord::Base.class_eval do
        extend ActiveRecord
        # Optimistic lock 
        def opt_lock_protected(retries = 5, &block)
          begin
            block.call
          rescue ::ActiveRecord::StaleObjectError
            reload
            retry if (retries -= 1) > 0
          end
        end
      end
      # support on associations and scopes
      [::ActiveRecord::Relation, ::ActiveRecord::Associations::AssociationCollection].each do |klass|
        klass.send(:include, ActiveRecord)
      end
    end

    def cursorize(params={}, options={})
      res = self.where("") # a fake where, make it a relation object
      table = self.table_name()
      cursor = Cursorize::Base.cursorize_cursor(params, options[:only])
      return res if cursor.empty?
      
      if cursor[:where].present?
        cursor[:where].each {|attr, value|
          res = res.where("#{table}.#{attr} >= ?", value[0]) if value[0].present?
          res = res.where("#{table}.#{attr} <= ?", value[1]) if value[1].present?
        }
      end
      # Sort
      if cursor[:order].present?
        cursor[:order].each {|attr, value|
          res = res.order("#{table}.#{attr} #{value}")
        }
      end
        # SQL requires offset paring with limit. User very large number as limit missing.
      if cursor[:offset].present?
        res = res.offset(cursor[:offset].at_least(0))
        cursor[:limit] = 10000000 unless cursor[:limit].present?
      end
      res = res.limit(cursor[:limit].at_least(0)) if cursor[:limit].present?
      return res
    end
  end
  # Better use railtie, but it is only for plugin modules. This is not and 
  # won't be initialized.
  ActiveRecord.enable!
end

class Array
  def cursorize(params, options={}, &block)
    cursor = Cursorize::Base.cursorize_cursor(params, options[:only])
    return self if (empty? || cursor.empty?)

    # Filter by block function
    collections = block ? (self.select {|v| block.call(v)}) : self
    # Filter by condition
    where = cursor[:where]
    if where
      collections = collections.select {|v|
        where.all? {|attr, value| # check all conditions
          v_value = v.respond_to?(attr) ? v.send(attr) : nil
          (v_value.nil? && options[:allow_nil]) ||
          (!v_value.nil? && (value[0].nil? || v_value >= value[0]) &&
                            (value[1].nil? || v_value <= value[1]))
        }
      }
    end
    # Sort, only by the first one
    order = cursor[:order].present? ? cursor[:order].first : nil
    if order.present?
      attr, value = *order
      collections = collections.sort {|x,y|
        x_value = x.respond_to?(attr) ? x.send(attr) : nil
        y_value = y.respond_to?(attr) ? y.send(attr) : nil
        ( x_value.nil? &&  y_value.nil? ?  0 :
         !x_value.nil? &&  y_value.nil? ? -1 :
          x_value.nil? && !y_value.nil? ?  1 :
          x_value <=> y_value) * (value == "ASC" ? 1 : -1)
      }
    end
    offset = (cursor[:offset] || 0).at_least(0)
    limit = (cursor[:limit]||collections.size).at_most(collections.size-offset).at_least(0)
    return collections.slice(offset, limit) || []
  end
end

module ActiveRecord
  class Base

  def save_without_timestamping
    class << self
      def record_timestamps; false; end
    end

    save

    class << self
      remove_method :record_timestamps
    end
  end  
  end
end
