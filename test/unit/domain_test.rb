require File::dirname(__FILE__) + '/../test_helper'
require 'lib/domain'

class DomainTest < Test::Unit::TestCase
	with_mocha do
		def test_10_domain_read
			mock_axfr(:master => '127.0.0.1', :domain => 'example.org')
			d = nil
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				d = Domain.new('example.org')
			end

			assert_equal Domain, d.class
			assert_equal 'example.org', d.domain
			assert_equal '127.0.0.1', d.master

			assert_equal Array, d['SOA'].class
			assert_equal 1, d['SOA'].length
			
			assert_equal DomainRecord, d['SOA'][0].class
			assert_equal 'SOA', d['SOA'][0].rrtype
			assert_equal '', d['SOA'][0].hostname
			assert_equal '( 1 2 3 4 5 )', d['SOA'][0].rrdata
			assert_equal 1200, d['SOA'][0].ttl
			
			assert_equal DomainRecord, d['NS'][0].class
			assert_equal 'NS', d['NS'][0].rrtype
			assert_equal '', d['NS'][0].hostname
			assert_equal 'ns1.example.org.', d['NS'][0].rrdata
			assert_equal 1200, d['NS'][0].ttl
			
			assert_equal DomainRecord, d['NS'][1].class
			assert_equal 'NS', d['NS'][1].rrtype
			assert_equal '', d['NS'][1].hostname
			assert_equal 'ns2.example.org.', d['NS'][1].rrdata

			assert_equal DomainRecord, d['A'][0].class
			assert_equal 'A', d['A'][0].rrtype
			assert_equal 'curly.example.org', d['A'][0].hostname
			assert_equal '192.168.1.2', d['A'][0].rrdata

			assert_equal DomainRecord, d['A'][1].class
			assert_equal 'A', d['A'][1].rrtype
			assert_equal 'larry', d['A'][1].hostname
			assert_equal '192.168.1.1', d['A'][1].rrdata
			assert_equal 19200, d['A'][1].ttl
			
			assert_equal DomainRecord, d['A'][2].class
			assert_equal 'A', d['A'][2].rrtype
			assert_equal 'moe', d['A'][2].hostname
			assert_equal '192.168.1.3', d['A'][2].rrdata

			assert_equal DomainRecord, d['CNAME'][0].class
			assert_equal 'CNAME', d['CNAME'][0].rrtype
			assert_equal 'baldie', d['CNAME'][0].hostname
			assert_equal 'curly', d['CNAME'][0].rrdata

			assert_equal DomainRecord, d['CNAME'][1].class
			assert_equal 'CNAME', d['CNAME'][1].rrtype
			assert_equal 'ns1', d['CNAME'][1].hostname
			assert_equal 'curly', d['CNAME'][1].rrdata
			
			assert_equal DomainRecord, d['MX'][0].class
			assert_equal 'MX', d['MX'][0].rrtype
			assert_equal '', d['MX'][0].hostname
			assert_equal '10 moe.example.org.', d['MX'][0].rrdata
		end
	end

	def test_05_faux_nsupdate
		nsupdate_output = nil
		with_domainfile({}) do
			nsupdate_output = faux_nsupdate do
				IO.popen("nsupdate", 'w') do |fd|
					fd.puts "zone notarealdomain"
					fd.puts "server dracula"
				end
			end
		end
		
		assert_equal "zone notarealdomain\nserver dracula\n", nsupdate_output
	end

	def test_06_faux_nsupdate_with_key
		with_domainfile({}) do
			full_key = File.expand_path(File.join(RAILS_ROOT, 'config', 'dns_keys', 'fooferore'))
			# Fail with no key
			nsupdate_output = faux_nsupdate(:wants_key => 'fooferore') do
				IO.popen("nsupdate", 'w') do |fd|
					fd.puts "zone notarealdomain"
					fd.puts "server dracula"
				end
			end
			assert_equal "", nsupdate_output

			# Fail with the wrong key
			nsupdate_output = faux_nsupdate(:wants_key => 'fooferore') do
				IO.popen("nsupdate -k someotherkey", 'w') do |fd|
					fd.puts "zone notarealdomain"
					fd.puts "server dracula"
				end
			end
			assert_equal "", nsupdate_output

			# But the right key... bellissimo!
			nsupdate_output = faux_nsupdate(:wants_key => 'fooferore') do
				IO.popen("nsupdate -k #{full_key}", 'w') do |fd|
					fd.puts "zone notarealdomain"
					fd.puts "server dracula"
				end
			end
			assert_equal "zone notarealdomain\nserver dracula\n", nsupdate_output
		end
		
	end

	def test_10_instantiate_invalid_domain
		with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
			assert_raise(ArgumentError) { Domain.new('invalid.org') }
		end
	end

	with_mocha do
		def test_20_find_domain_record
			mock_axfr(:master => '127.0.0.1', :domain => 'example.org')
			d = nil
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				d = Domain.new('example.org')
			end
			
			dr = d.find('larry__A__192.168.1.1')
			
			assert_equal DomainRecord, dr.class
			assert_equal 'larry', dr.hostname
			assert_equal 'A', dr.rrtype
			assert_equal 19200, dr.ttl
			assert_equal '192.168.1.1', dr.rrdata
		end
	end
	
	with_mocha do
		def test_21_find_unknown_domain_record
			mock_axfr(:master => '127.0.0.1', :domain => 'example.org')
			d = nil
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				d = Domain.new('example.org')
			end
			
			assert d.find('larry__A__127.0.0.1').nil?
		end
	end
	
	def test_30_record_deletion
		out = faux_nsupdate do
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				d = Domain.new('example.org')
				d.delete('renfield', 'CNAME', 'flies')
			end
		end

		assert_equal "zone example.org\nserver 127.0.0.1\nupdate delete renfield.example.org CNAME flies\nsend\n", out
	end

	def test_35_record_deletion_by_domain_record
		out = faux_nsupdate do
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				d = Domain.new('example.org')
				d.find('baldie__CNAME__curly').delete
			end
		end

		assert_equal "zone example.org\nserver 127.0.0.1\nupdate delete baldie.example.org CNAME curly\nsend\n", out
	end

	def test_30_record_addition
		out = faux_nsupdate do
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				d = Domain.new('example.org')
				d.add('bling', 'A', '256.256.256.256')
			end
		end
		
		assert_equal "zone example.org\nserver 127.0.0.1\nupdate add bling.example.org 86400 A 256.256.256.256\nsend\n", out

		out = faux_nsupdate do
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				d = Domain.new('example.org')
				d.add('bling', 'A', '256.256.256.256', 1000000)
			end
		end
		
		assert_equal "zone example.org\nserver 127.0.0.1\nupdate add bling.example.org 1000000 A 256.256.256.256\nsend\n", out
	end

	def test_30_replace
		out = faux_nsupdate do
			d = nil
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				d = Domain.new('example.org')
			end
			dr = d['A'][1]
			assert_equal 'larry', dr.hostname
			assert_equal '192.168.1.1', dr.rrdata
			
			newdr = dr.clone
			newdr.rrdata = '10.20.30.40'
			d.replace(dr, newdr)
		end
		
		assert_equal "zone example.org\nserver 127.0.0.1\nupdate delete larry.example.org A 192.168.1.1\nupdate add larry.example.org 19200 A 10.20.30.40\nsend\n", out
	end
end
