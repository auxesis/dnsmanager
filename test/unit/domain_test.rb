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
			assert_equal 'curly.example.org.', d['CNAME'][0].rrdata

			assert_equal DomainRecord, d['CNAME'][1].class
			assert_equal 'CNAME', d['CNAME'][1].rrtype
			assert_equal 'ns1', d['CNAME'][1].hostname
			assert_equal 'curly.example.org.', d['CNAME'][1].rrdata
			
			assert_equal DomainRecord, d['MX'][0].class
			assert_equal 'MX', d['MX'][0].rrtype
			assert_equal '', d['MX'][0].hostname
			assert_equal '10 moe.example.org.', d['MX'][0].rrdata
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

	with_mocha do
		def test_30_record_deletion
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			NSUpdate.expects(:new).with(:server => '127.0.0.1',
			                            :zone => 'example.org',
			                            :key => nil).returns(n = mock())
			n.expects(:delete).with('renfield', :type => 'CNAME', :data => 'flies')
			n.expects(:send_update)

			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				d = Domain.new('example.org')
				d.delete('renfield', 'CNAME', 'flies')
			end
		end
	end
	
	with_mocha do
		def test_35_record_deletion_by_domain_record
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			NSUpdate.expects(:new).with(:server => '127.0.0.1',
			                            :zone => 'example.org',
			                            :key => nil).returns(n = mock())
			n.expects(:delete).with('baldie', :type => 'CNAME', :data => 'curly.example.org.')
			n.expects(:send_update)
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				d = Domain.new('example.org')
				d.find('baldie__CNAME__curly.example.org.').delete
			end
		end
	end
	
	with_mocha do
		def test_30_record_addition
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			NSUpdate.expects(:new).with(:server => '127.0.0.1',
			                            :zone => 'example.org',
			                            :key => nil).returns(n = mock())
			n.expects(:add).with('bling', :type => 'A', :ttl => 86400, :data => '256.256.256.256')
			n.expects(:send_update)
			
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				d = Domain.new('example.org')
				d.add('bling', 'A', '256.256.256.256')
			end
		end
	end

	with_mocha do
		def test_31_record_addition_with_long_ttl
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			NSUpdate.expects(:new).with(:server => '127.0.0.1',
			                            :zone => 'example.org',
			                            :key => nil).returns(n = mock())
			n.expects(:add).with('bling', :type => 'A', :ttl => 1000000, :data => '256.256.256.256')
			n.expects(:send_update)
			
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				d = Domain.new('example.org')
				d.add('bling', 'A', '256.256.256.256', 1000000)
			end
		end
	end

	with_mocha do
		def test_30_replace
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			NSUpdate.expects(:new).with(:server => '127.0.0.1',
			                            :zone => 'example.org',
			                            :key => nil).returns(n = mock())
			n.expects(:delete).with('larry', :type => 'A', :data => '192.168.1.1')
			n.expects(:add).with('larry', :type => 'A', :ttl => 19200, :data => '10.20.30.40')
			n.expects(:send_update)
			
			d = nil
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				d = Domain.new('example.org')
			end
			dr = d['A'][1]
			assert_equal 'larry', dr.hostname
			assert_equal '192.168.1.1', dr.rrdata
			assert_equal 19200, dr.ttl
			
			newdr = dr.clone
			newdr.rrdata = '10.20.30.40'
			d.replace(dr, newdr)
		end
	end

	with_mocha do
		def test_31_replace_with_relative_cname_target
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			NSUpdate.expects(:new).with(:server => '127.0.0.1',
			                            :zone => 'example.org',
			                            :key => nil).returns(n = mock())
			n.expects(:delete).with('baldie', :type => 'CNAME', :data => 'curly.example.org.')
			n.expects(:add).with('baldie', :type => 'CNAME', :ttl => 666, :data => 'fluffy.example.org.')
			n.expects(:send_update)
			
			d = nil
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				d = Domain.new('example.org')
			end
			dr = d['CNAME'][0]
			assert_equal 'baldie', dr.hostname
			assert_equal 'CNAME', dr.rrtype
			assert_equal 'curly.example.org.', dr.rrdata
			assert_equal 1200, dr.ttl
			
			newdr = dr.clone
			newdr.ttl = 666
			newdr.rrdata = 'fluffy'
			d.replace(dr, newdr)
		end
	end
end
