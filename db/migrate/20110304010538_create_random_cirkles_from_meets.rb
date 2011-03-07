class CreateRandomCirklesFromMeets < ActiveRecord::Migration
  def self.up
    return
    cirkle_size = 10
    cirkle_count = (Meet.count.to_f/cirkle_size).ceil
    group_size = 50
    group_count = (cirkle_count.to_f/group_size).ceil

    (0...group_count).each {|cirkle_group|
      cirkles_meets = {}
      cirkle_range = (cirkle_group*group_size...(cirkle_group+1)*group_size)
      Meet.all.each {|meet|
        next unless meet.meet_type == 3
        cirkle_id = meet.id % cirkle_count
        next if !cirkle_range.include?(cirkle_id)
        (cirkles_meets[cirkle_id] ||= Array.new) << meet
      }

      cirkles_meets.each_pair {|cirkle_id, meets|
        meets = meets.sort_by {|v| v.meet_time}
        first_meet = meets.first
        first_meet.extract_information(first_meet.mposts)
        first_meet.save
        meets.slice(1..-1).each {|meet|
          meet.mposts.each {|mpost|
            if mpost.status == 0
              mpost.cirkle_id = first_meet.cirkle_id
              mpost.save
              break
            end
          }
          meet.extract_information(meet.mposts)
          meet.save
        }
        if cirkle_id%50 == 0
          puts "#{cirkle_id} #{meets.size}"
          force_gc
        end
        meets.clear
      }
    }
    force_gc
  end

  def self.down
    Meet.all.each {|meet|
      if meet.is_cirkle?
        meet.destroy
      elsif meet.cirkle_id
        meet.cirkle_id = nil
        meet.save
      end
    }
    Mpost.all.each {|mpost|
      if mpost.cirkle_id?
        mpost.cirkle_id = nil
        mpost.save
      end
    }
  end
end
