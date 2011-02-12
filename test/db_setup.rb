$LOAD_PATH << '.'
$LOAD_PATH << './test'
$LOAD_PATH << './lib'
load 'test_base.rb'
load 'test_user.rb'

UsersBuilder::build_admin
UsersBuilder::build_and_save
