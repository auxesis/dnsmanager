require File.dirname(__FILE__) + '/../test_helper.rb'
require 'lib/dig'

class DigTest < Test::Unit::TestCase
	def test_000_we_have_the_mock_dig
		faux_dig do
			assert_equal "I really love this stuff\n", `dig notarealdomain`
		end
	end

	def test_001_faux_dig_cleans_up_after_exception
		real_path = ENV['PATH']
		begin
			faux_dig(:wants_key => 'foo') do
				assert ENV['FAUX_DIG_KEY']
				assert_not_equal real_path, ENV['PATH']
				raise RuntimeError
			end
		rescue RuntimeError
		end
		
		assert_nil ENV['FAUX_DIG_KEY']
		assert_equal real_path, ENV['PATH']
	end
	
	def test_005_dig_setup
		d = Dig.new
		assert_equal '127.0.0.1', d.instance_variable_get('@server')
		assert_nil d.instance_variable_get('@key')
		
		d = Dig.new(:server => '127.0.0.2')
		assert_equal '127.0.0.2', d.instance_variable_get('@server')
		
		d = Dig.new(:key => 'flingle')
		assert_equal File.expand_path("#{RAILS_ROOT}/config/dns_keys/flingle.private"), d.instance_variable_get('@key')
	end

	def test_010_query_a_domain
		faux_dig do
			d = Dig.new

			# This may be considered 'knowing a bit too much about how something
			# works', but it's less fragile than blindly asserting that some line
			# or another is in the output, when the file's contents might change
			# in the future.
			assert_equal File.read(File.dirname(__FILE__) + '/../fixtures/example.org'),
			             d.axfr('example.org')
		end
	end

	def test_020_query_a_domain_with_a_key
		faux_dig(:wants_key => 'mykeyiscool.private') do
			d = Dig.new(:key => 'mykeyiscool')
			
			assert_equal File.read(File.dirname(__FILE__) + '/../fixtures/example.org'),
			             d.axfr('example.org')
		end
	end
	
	def test_100_failure_is_deadly
		faux_dig do
			# Querying anything other than the localhost is an error with faux dig
			d = Dig.new(:server => '127.0.0.2')
			assert_raise(Dig::Error) { d.axfr('example.org') }
		end
	end

	def test_110_the_wrong_key_is_deadly
		faux_dig(:wants_key => 'something') do
			d = Dig.new(:key => 'nothing')
			assert_raise(Dig::Error) { d.axfr('example.org') }
		end
	end

	def test_120_no_key_when_we_expect_one_is_deadly
		faux_dig(:wants_key => 'something') do
			d = Dig.new
			assert_raise(Dig::Error) { d.axfr('example.org') }
		end
	end

	def test_130_dig_with_nonzero_return_raises_exception
		faux_dig do
			d = Dig.new
			assert_raise(Dig::Error) { d.axfr('nonzeroexitcodeplz') }
			begin
				d.axfr('nonzeroexitcodeplz')
			rescue Dig::Error => e
				assert_equal "Call to dig failed for an unknown reason.", e.message
			else
				assert false, "We should have caught an exception, dammit!"
			end
		end
	end
end
