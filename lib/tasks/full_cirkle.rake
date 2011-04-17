namespace :db do
  desc "Migrate to full cirkle support "
  task :full_cirkle => :environment do
    #Rake::Task['db:reset'].invoke
    Meet.all.each {|v| if v.is_encounter?; v.extract_information.save; end}
    Meet.all.each {|v| if v.is_cirkle?; v.update_encounters_count.save; end}
    Meet.all.each {|v| if v.meet_type == 0; v.destroy; end}
    Meet.all.each {|v| if v.meet_type == 6 && v.encounters.empty?; v.destroy; end}
  end
end
