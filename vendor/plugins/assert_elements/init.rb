# inject hpricot test helper into test::unit for test environment
if RAILS_ENV == 'test'
  require 'hpricot'
  require 'hpricot_patches'
  require 'hpricot_test_helper'
  Test::Unit::TestCase.send(:include, HpricotTestHelper)
end