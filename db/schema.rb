# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110107005447) do

  create_table "chatters", :force => true do |t|
    t.integer  "user_id"
    t.string   "photo_content_type"
    t.string   "photo_file_name"
    t.integer  "photo_file_size"
    t.datetime "photo_updated_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "meet_id"
    t.text     "content"
    t.integer  "status",             :default => 0
  end

  add_index "chatters", ["created_at"], :name => "index_chatters_on_created_at"
  add_index "chatters", ["meet_id"], :name => "index_chatters_on_meet_id"
  add_index "chatters", ["user_id"], :name => "index_chatters_on_user_id"

  create_table "invitations", :force => true do |t|
    t.integer  "meet_id"
    t.integer  "user_id"
    t.text     "invitee"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "message"
  end

  add_index "invitations", ["created_at"], :name => "index_invitations_on_created_at"
  add_index "invitations", ["meet_id"], :name => "index_invitations_on_meet_id"
  add_index "invitations", ["user_id"], :name => "index_invitations_on_user_id"

  create_table "meets", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.datetime "time"
    t.string   "location"
    t.string   "street_address"
    t.string   "city"
    t.string   "state"
    t.string   "zip"
    t.string   "country"
    t.string   "image_url"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.decimal  "lng"
    t.decimal  "lat"
    t.float    "lerror"
    t.boolean  "collision"
    t.string   "host_id"
    t.integer  "lock_version",   :default => 0, :null => false
    t.integer  "hoster_id"
    t.text     "cached_info"
    t.integer  "type"
  end

  add_index "meets", ["host_id"], :name => "index_meets_on_host_id", :unique => true
  add_index "meets", ["hoster_id"], :name => "index_meets_on_hoster_id"
  add_index "meets", ["time"], :name => "index_meets_on_time"

  create_table "mpost_records", :force => true do |t|
    t.integer  "mpost_id"
    t.datetime "time"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "mpost_records", ["time"], :name => "index_mpost_records_on_time"

  create_table "mposts", :force => true do |t|
    t.integer  "user_id"
    t.integer  "meet_id"
    t.datetime "time"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float    "lerror"
    t.string   "user_dev"
    t.text     "devs"
    t.decimal  "lng",        :precision => 15, :scale => 10
    t.decimal  "lat",        :precision => 15, :scale => 10
    t.string   "note"
    t.integer  "host_mode"
    t.boolean  "collision"
    t.string   "host_id"
    t.integer  "status",                                     :default => 0
  end

  add_index "mposts", ["created_at"], :name => "index_mposts_on_created_at"
  add_index "mposts", ["meet_id"], :name => "index_mposts_on_meet_id"
  add_index "mposts", ["time"], :name => "index_mposts_on_time"
  add_index "mposts", ["user_id"], :name => "index_mposts_on_user_id"

  create_table "mviews", :force => true do |t|
    t.integer  "user_id"
    t.integer  "meet_id"
    t.string   "name"
    t.string   "location"
    t.datetime "time"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "mviews", ["user_id", "meet_id"], :name => "index_mviews_on_user_id_and_meet_id", :unique => true

  create_table "relationships", :force => true do |t|
    t.integer  "follower_id"
    t.integer  "followed_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "relationships", ["followed_id"], :name => "index_relationships_on_followed_id"
  add_index "relationships", ["follower_id"], :name => "index_relationships_on_follower_id"

  create_table "users", :force => true do |t|
    t.string   "name"
    t.string   "email"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "encrypted_password"
    t.string   "salt"
    t.boolean  "admin",              :default => false
    t.string   "photo_file_name"
    t.string   "photo_content_type"
    t.integer  "photo_file_size"
    t.datetime "photo_updated_at"
    t.integer  "lock_version",       :default => 0,     :null => false
    t.integer  "status",             :default => 0
  end

  add_index "users", ["email"], :name => "index_users_on_email", :unique => true

end
