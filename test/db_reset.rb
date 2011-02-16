$LOAD_PATH << '.'
$LOAD_PATH << './test'
$LOAD_PATH << './lib'
load 'test_base.rb'
load 'test_user.rb'
load 'test_feature.rb'
load 'test_stress.rb'

FeaturesTest::destroy_all
StressTest::destroy_all
UsersBuilder::destroy_all
