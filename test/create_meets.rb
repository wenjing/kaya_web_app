require 'kaya_base'

class Meet
  attr_accessor :name, :users, :loc, :time, :mposts,
                :loc_x, :loc_y, :loc_size

  def trigger_range
    return *mposts.minmax_by {|mpost| mpost.time}
  end

  def post_range
    return *mposts.minmax_by {|mpost| mpost.post_time}
  end

  def x_range
    return [loc_x, loc_x+loc_size]
  end
  def y_range
    return [loc_y, loc_y+loc_size]
  end

  def display(indent)
    puts format("#{indent}%s %s %d/%d",
                name, time.time_ampm, mposts.size, users.size)
    trigger_start, trigger_end = *trigger_range
    post_start, post_end = *post_range
    puts format("#{indent} trigger: %+ds %+ds",
                (trigger_start.time-time).round, (trigger_end.time-time).round)
    puts format("#{indent} post   : %+ds %+ds",
                (post_start.post_time-time).round, (post_end.post_time-time).round)
    mposts.each {|mpost| mpost.display("#{indent}  ")}
  end
end

class MeetsBuilder
  @@occupancy = [0.5, 1.0]
  @@orphan_ratio_prob = [0.03] # 3% chance that someone creates orphan event
  @@user_count_range = (2..50)
  @@dist_between_meets = [6, 15]

  def self.build(loc, users, serial)
    loc.meets = Array.new(loc.meet_count) {Meet.new}
    return loc.meets if loc.meets.empty?
    total_user_count = (loc.capacity * @@occupancy.random).ceil
    avg_user_per_meet = total_user_count/loc.meet_count
    avg_user_per_meet = 2 if avg_user_per_meet < 2
    user_count_range = [2, @@user_count_range.between(3*avg_user_per_meet)]
    loc.meets.each {|meet|
      break if users.empty? # exhaust all users
      serial += 1
      meet.name = "meet_#{format('%06d', serial)}"
      meet.loc = loc
      meet.time = [loc.from_time, loc.to_time].random
      orphan_meet = @@orphan_ratio_prob.random_prob == 0
      user_count = orphan_meet ? 1 : [users.size, user_count_range.random.round].min
      meet.users = users.slice!(0...user_count)
      meet.mposts = Array.new
      meet.loc_size = (loc.peer_distance * sqrt(meet.users.size)).floor
    }
    loc.meets = loc.meets.reject {|meet| !meet.users || meet.users.empty? }
    row_count = sqrt(loc.meets.size.to_f).ceil.at_least(2)
    row_no = 0
    loc_x, loc_y = 0.0, 0.0
    loc.meets.each {|meet|
      meet.loc_x, meet.loc_y = loc_x.floor, loc_y.floor
      loc_dist = @@dist_between_meets.random
      loc_x += meet.loc_size+loc_dist; loc_y += meet.loc_size+loc_dist
      row_no += 1
      if row_no >= row_count
        loc_x = 0.0
        row_no = 0
      end
    }
    loc.meets.sort_by! {|meet| meet.time}
    return loc.meets
  end
end
