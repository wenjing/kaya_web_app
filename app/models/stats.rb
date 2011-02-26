# == Schema Information
# Schema version: 20110226204045
#
# Table name: stats
#
#  id           :integer         not null, primary key
#  avg_meet_lag :float
#  created_at   :datetime
#  updated_at   :datetime
#

class Stats < ActiveRecord::Base

  @@EMV_PERIOD = 100
  @@EMV_COVERAGE = 0.99 # 99%
  # PERIOD = log(1-COVERAGE)/log(1-ALPHA)
  @@EMV_ALPHA = 1-Math.exp(Math.log(1-@@EMV_COVERAGE)/@@EMV_PERIOD)

  def update_avg_meet_lag(meet)
    self.avg_meet_lag ||= 0.0
    self.avg_meet_lag = (1-@@EMV_ALPHA) * avg_meet_lag + @@EMV_ALPHA * meet.meet_lag
  end
end
