namespace :db do
  desc "Fill database with random cirkle from existing meets"
  task :random_cirkle_up => :environment do
    #Rake::Task['db:reset'].invoke
    random_cirkle_up
  end
end

namespace :db do
  desc "Remove random cirkle created from existing meets"
  task :random_cirkle_down => :environment do
    #Rake::Task['db:reset'].invoke
    random_cirkle_down
  end
end

def random_cirkle_up
  cirkle_size = 1
  cirkle_count = (Meet.count.to_f/cirkle_size).ceil
  group_size = 1000
  group_count = (cirkle_count.to_f/group_size).ceil
  
  (0...group_count).each {|cirkle_group|
    cirkles_meets = {}
    cirkle_range = (cirkle_group*group_size...(cirkle_group+1)*group_size)
    Meet.all.each {|meet|
      next unless (meet.meet_type == 3 && !meet.cirkle_id)
      #cirkle_id = meet.id % cirkle_count
      cirkle_id = meet.id
      next if !cirkle_range.include?(cirkle_id)
      (cirkles_meets[cirkle_id] ||= Array.new) << meet
    }
    
    cirkles_meets.each_pair {|cirkle_id, meets|
      meets = meets.sort_by {|v| v.meet_time}
      first_meet = meets.first
      first_meet.extract_information(first_meet.mposts)
      first_meet.save_without_timestamping
      meets.slice(1..-1).each {|meet|
        meet.mposts.each {|mpost|
          if mpost.status == 0
            mpost.cirkle_id = first_meet.cirkle_id
            mpost.save_without_timestamping
            break
          end
        }
        meet.extract_information(meet.mposts)
        meet.save_without_timestamping
      }
      if cirkle_id%1000 == 0
        puts "#{cirkle_id} #{meets.size}"
        force_gc
      end
    }
  }
  force_gc
end

def random_cirkle_down
  Meet.all.each {|meet|
    if meet.is_cirkle?
      meet.destroy
    elsif meet.cirkle_id
      meet.cirkle_id = nil
      meet.save_without_timestamping
    end
  }
  Mpost.all.each {|mpost|
    if mpost.cirkle_id?
      mpost.cirkle_id = nil
      mpost.save_without_timestamping
    elsif mpost.is_cirkle_mpost?
      mpost.destroy
    end
  }
end
