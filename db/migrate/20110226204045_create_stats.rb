class CreateStats < ActiveRecord::Migration
  def self.up
    create_table :stats do |t|
      t.float :avg_meet_lag

      t.timestamps
    end
    stats = Stats.create(:avg_meet_lag=>0.0)
    Meet.all.reverse_each {|meet| meet.record_avg_meet_lag}
  end

  def self.down
    drop_table :stats
  end
end
