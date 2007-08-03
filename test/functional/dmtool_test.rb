require File.dirname(__FILE__) + '/../test_helper'
load RAILS_ROOT + '/script/dmtool'
require 'tempfile'
require 'yaml'
require 'digest/sha1'

class DMToolTest < Test::Unit::TestCase
	def test_new_user
		with_pwfile({'user' => 'nopw'}) do |tmpfile|
			run_command(['password', 'newuser', 'password'])
			assert_equal({'user' => 'nopw', 'newuser' => Digest::SHA1::hexdigest('password')},
			             YAML::load_file(tmpfile))
		end
	end

	def test_change_password
		with_pwfile({'user' => 'nopw'}) do |tmpfile|
			run_command(['password', 'user', 'password'])
			assert_equal({'user' => Digest::SHA1::hexdigest('password')},
			             YAML::load_file(tmpfile))
		end
	end
end
