require 'test_base'

class TestLoc
  @@peer_distance_range = (2..6)
  @@lerror_bad_dist = [2000, 400, 6000]
  @@lerror_good_dist = [20, 5, 50]
  attr_accessor :lng, :lat, :lerror_scale, :precision_ratio,
                :area_size, :capacity,
                :from_time, :to_time, :meet_count, :meets
  def initialize
    self.meets = []
  end
  def lerror
    good = [precision_ratio].random_prob == 0
    if good
      return (@@lerror_good_dist.random_dist * lerror_scale).ceil
    else
      return (@@lerror_bad_dist.random_dist * lerror_scale).ceil
    end
  end
  def peer_distance
    return @@peer_distance_range.between(sqrt(area_size.to_f/capacity.at_least(1.0)))
  end
  def display(indent)
    puts format("#{indent}location: lng=%f lat=%f scale=%.2f ratio=%.2f",
                lng, lat, lerror_scale, precision_ratio)
    puts format(" #{indent}time    : %s %+ds",
                from_time.time_ampm, (to_time-from_time).round)
    puts format(" #{indent}capacity: size=%d cap=%d dist=%.2f",
                area_size, capacity, peer_distance)
    puts format(" #{indent}meets   : %d/%d", meets.size, meet_count)
    meets.each {|meet| meet.display("#{indent}  ")}
  end
end

class LocationsBuilder
  @@count = 100
  @@lat_range = [37.5500, 37.2300]
  @@lng_range = [-121.7500, -122.3300]
  @@area_size_per_unit = 400
  @@capacity_per_unit_dist = [10, 2, 50]
  @@unit_count_dist = [5, 1, 20]
  @@precision_ratio_dist = [0.80, 0.3, 0.95]
  @@lerror_scale = [0.5, 2.0]
  @@meet_freq_per_unit_dist = [3, 0, 10]
  def self.build(from_time, to_time, count=nil)
    count ||= @@count
    locs = Array.new(count) {TestLoc.new}
    locs.each {|loc|
      loc.from_time = from_time
      loc.to_time = to_time
      loc.lat = @@lat_range.random
      loc.lng = @@lng_range.random
      loc.lerror_scale = @@lerror_scale.random
      loc.precision_ratio = @@precision_ratio_dist.random_dist
      unit_count = @@unit_count_dist.random_dist.ceil
      loc.area_size = @@area_size_per_unit * unit_count
      loc.capacity = (@@capacity_per_unit_dist.random_dist * unit_count).ceil
      loc.meet_count = (@@meet_freq_per_unit_dist.random_dist * unit_count).ceil
    }
    return locs
  end
end
