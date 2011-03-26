namespace :db do
  desc "Update meet chatter counts"
  task :update_chatters => :environment do
    //Rake::Task['db:reset'].invoke
    Meet.all.each {|v| v.update_chatters_count.save}
  end
end
