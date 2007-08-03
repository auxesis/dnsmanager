require File.dirname(__FILE__) + '/../test_helper.rb'
require 'lib/nsupdate'

class NSUpdateTest < Test::Unit::TestCase
	def test_000_we_have_the_mock_nsupdate
		output = faux_nsupdate do
			IO.popen('nsupdate', 'w') do |fd|
				fd.puts "blah de blah"
			end
		end
		
		assert_equal "blah de blah\n", output
	end

	def test_001_faux_nsupdate_cleans_up_after_exception
		real_path = ENV['PATH']
		begin
			faux_nsupdate(:wants_key => 'foo') do
				assert ENV['FAUX_NSUPDATE_KEY']
				assert_not_equal real_path, ENV['PATH']
				raise RuntimeError
			end
		rescue RuntimeError
		end
		
		assert_nil ENV['FAUX_NSUPDATE_KEY']
		assert_equal real_path, ENV['PATH']
	end
	
	def test_005_nsupdate_setup
		n = NSUpdate.new
		assert_nil n.instance_variable_get('@key')
		assert_equal '127.0.0.1', n.instance_variable_get('@server')
		assert_nil n.instance_variable_get('@zone')

		n = NSUpdate.new(:server => '127.0.0.2', :zone => 'example.org')
		assert_equal '127.0.0.2', n.instance_variable_get('@server')
		assert_equal 'example.org', n.instance_variable_get('@zone')

		n = NSUpdate.new(:key => 'flingle')
		assert_equal File.expand_path("#{RAILS_ROOT}/config/dns_keys/flingle.private"), n.instance_variable_get('@key')
	end

	def test_010_setting_variables
		n = NSUpdate.new
		n.server = '127.0.0.2'
		assert_equal '127.0.0.2', n.instance_variable_get('@server')
		n.zone = 'example.org'
		assert_equal 'example.org', n.instance_variable_get('@zone')
	end

	def test_020_simple_add
		output = faux_nsupdate do
			n = NSUpdate.new(:zone => 'example.org')
			n.add 'fred', :type => 'A', :data => '10.20.30.40', :ttl => 300
			n.send_update
		end
	end
	
	def test_030_simple_delete
		output = faux_nsupdate do
			n = NSUpdate.new(:zone => 'example.org')
			n.delete 'fred'
			n.send_update
		end
		
		assert_equal "server 127.0.0.1\n" +
		             "zone example.org\n" +
		             "update delete fred.example.org\n" +
		             "send\n",
		             output
	end
	
	def test_040_delete_with_opts
		output = faux_nsupdate do
			n = NSUpdate.new(:zone => 'example.org')
			n.delete 'fred', :type => 'CNAME', :data => 'george.example.org.'
			n.send_update
		end
		
		assert_equal "server 127.0.0.1\n" +
		             "zone example.org\n" +
		             "update delete fred.example.org CNAME george.example.org.\n" +
		             "send\n",
		             output
	end

	def test_100_timeout_is_deadly
		output = faux_nsupdate do
			n = NSUpdate.new(:zone => 'example.org', :server => 'timeout')
			n.add 'fred', :type => 'A', :data => '10.20.30.40', :ttl => 300
			assert_raise(NSUpdate::Error) { n.send_update }
		end
		
		assert_equal "server timeout\n" +
		             "zone example.org\n" +
		             "update add fred.example.org 300 A 10.20.30.40\n" +
		             "send\n",
		             output
	end

	def test_110_no_send_no_output
		output = faux_nsupdate do
			n = NSUpdate.new(:zone => 'example.org', :server => '127.0.0.1')
			n.add 'fred', :type => 'A', :data => '10.20.30.40', :ttl => 300
		end
		
		assert_equal "", output
	end
end
