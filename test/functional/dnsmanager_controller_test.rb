require File.dirname(__FILE__) + '/../test_helper'
require 'dnsmanager_controller'
require 'lib/nsupdate'

# Re-raise errors caught by the controller.
class DnsmanagerController; def rescue_action(e) raise e end; end

class DnsmanagerControllerTest < Test::Unit::TestCase
	def setup
		@controller = DnsmanagerController.new
		@request    = ActionController::TestRequest.new
		@response   = ActionController::TestResponse.new
		
		# Mock out the real password file with one of our own construction
		@orig_pwfile = $pwfile
		@tmpfile = Tempfile.new('dct')
		$pwfile = @tmpfile.path
		@tmpfile.close
		pwdata = { 'user' => Digest::SHA1::hexdigest('password') }
		File.open($pwfile, 'w') { |fd| YAML.dump(pwdata, fd) }
		http_login('user', 'password')
	end

	def teardown
		@tmpfile.unlink
		$pwfile = @orig_pwfile
	end

	def test_access_denied
		unlogin
		get :index
		
		assert_response 401
		assert_equal 'Basic realm="DNS Manager"', @response.headers['WWW-Authenticate']
	end

	def test_empty_zone
		with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
			get :zone
		
			assert_response :success
			assert_tag :tag => 'select',
			           :attributes => { :name => 'domain' },
			           :children => { :count => 2,
			                          :only => {:tag => 'option'}
			                        }
			                        
			assert_tag :tag => 'input', :attributes => { :type => 'submit', :name => 'commit', :value => "Change Domain" }
			assert_no_tag :tag => 'a', :attributes => { :href => '/dnsmanager/add' }, :content => 'Add Record'
		end
	end

	def test_sorted_domain_list
		with_domainfile('example.org' => {'master' => '127.0.0.1'},
		                'something.com' => {'master' => '127.0.0.1'},
		                'xyzzy.net' => {'master' => '127.0.0.1'},
		                'abba.biz' => {'master' => '127.0.0.1'},
		                'hezmatt.org' => {'master' => '127.0.0.1'}) do
			get :zone
		end
		
		assert_equal [['---', ''],
		              ['abba.biz'],
		              ['example.org'],
		              ['hezmatt.org'],
		              ['something.com'],
		              ['xyzzy.net']],
		             assigns(:domainlist)
	end

	with_mocha do
		def test_select_a_domain
			mock_axfr(:master => '127.0.0.1', :domain => 'something.com')
			with_domainfile('something.com' => {'master' => '127.0.0.1'}) do
				post :zone, {:domain => 'something.com', :commit => 'Change Domain'}
			end
			
			assert_response :success
			assert_equal 'something.com', session[:domain]
			assert_tag :tag => 'option', :attributes => {:value => 'something.com', :selected => 'selected'}, :content => 'something.com'
		end
	end

	def test_select_a_domain_we_dont_have
		# FIXME: Write this test
	end

	with_mocha do
		def test_show_domain
			mock_axfr(:master => '127.0.0.1', :domain => 'example.org')
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				get :zone, {}, {:domain => 'example.org'}
			end
			
			assert_equal DomainRecord, assigns['soa'].class
			assert_equal 2, assigns['ns'].length
			assert_equal 3, assigns['aliases'].length
			assert_equal 3, assigns['hosts'].length
			
			assert_response :success
			assert_tag :tag => 'tr',
			           :child =>
			           {
			                :tag => 'td',
			                :content => 'larry'
			               }

			assert_tag :tag => 'td',
			           :child => {
			             :tag => 'a',
			             :attributes => { :href => '/dnsmanager/delete/baldie__CNAME__curly.example.org.' },
			             :content => '(delete)'
			           }

			assert_tag :tag => 'a', :attributes => { :href => '/dnsmanager/add' }, :content => 'Add Record'
			assert_tag :tag => 'a', :attributes => { :href => '/dnsmanager/edit/baldie__CNAME__curly.example.org.' }, :content => '(edit)'
			assert_tag :tag => 'a', :attributes => { :href => '/dnsmanager/edit/__MX__10+moe.example.org.' }, :content => '(edit)'
			assert_tag :tag => 'option', :attributes => {:value => 'example.org', :selected => 'selected'}, :content => 'example.org'
		end
	end
	
	with_mocha do
		def test_show_domain_using_a_key
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1',
			          :key => 'Kexample.org.+157.+random')
			with_domainfile('example.org' => {'master' => '127.0.0.1', 'key' => 'Kexample.org.+157.+random'}) do
				get :zone, {}, {:domain => 'example.org'}
			end
			
			# If we got *something*, we'll consider it a win
			assert_equal DomainRecord, assigns['soa'].class
		end
	end

	with_mocha do
		def test_delete_a_record
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			NSUpdate.expects(:new).with(:zone => 'example.org',
			                            :server => '127.0.0.1',
			                            :key => nil).returns(n = mock())
			n.expects(:delete).with('larry', :type => 'A', :data => '192.168.1.1')
			n.expects(:send_update)

			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				get :delete, { :id => "larry__A__192.168.1.1" }, { :domain => 'example.org' }
			end
			
			assert_response :redirect
			assert_redirected_to :action => 'zone'
			assert_equal "Record <tt>larry A 192.168.1.1</tt> has been deleted.", flash[:notice]
		end
	end

	with_mocha do
		def test_delete_mx_record
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			NSUpdate.expects(:new).with(:zone => 'example.org',
			                            :server => '127.0.0.1',
			                            :key => nil).returns(n = mock())
			n.expects(:delete).with('', :type => 'MX', :data => '10 moe.example.org.')
			n.expects(:send_update)

			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				get :delete, { :id => "__MX__10+moe.example.org." }, { :domain => 'example.org' }
			end
			
			assert_response :redirect
			assert_redirected_to :action => 'zone'
			
			assert_equal "Record <tt> MX 10 moe.example.org.</tt> has been deleted.", flash[:notice]
		end
	end

	with_mocha do
		def test_delete_a_record_with_key
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1',
			          :key => 'Kexample.org.+157+00000')
			NSUpdate.expects(:new).with(:zone => 'example.org',
			                            :server => '127.0.0.1',
			                            :key => 'Kexample.org.+157+00000'
			                           ).returns(n = mock())
			n.expects(:delete).with('larry', :type => 'A', :data => '192.168.1.1')
			n.expects(:send_update)

			with_domainfile('example.org' => {'master' => '127.0.0.1', 'key' => 'Kexample.org.+157+00000'}) do
				get :delete, { :id => "larry__A__192.168.1.1" }, { :domain => 'example.org' }
			end
			
			assert_response :redirect
			assert_redirected_to :action => 'zone'
			
			assert_equal "Record <tt>larry A 192.168.1.1</tt> has been deleted.", flash[:notice]
		end
	end
	
	with_mocha do
		def test_add_display
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				get :add, {}, {:domain => 'example.org'}
			end
			
			assert_response :success
			
			assert_tag :label, :attributes => { :for => 'hostname' }, :content => 'Hostname:'
			assert_tag :input, :attributes => { :type => 'text', :name => 'hostname' }
			assert_tag :label, :attributes => { :for => 'ttl' }, :content => 'TTL:'
			assert_tag :input, :attributes => { :type => 'text', :name => 'ttl' }
			assert_tag :label, :attributes => { :for => 'rrtype' }, :content => 'Type:'
			assert_tag :input, :attributes => { :type => 'text', :name => 'rrtype' }
			assert_tag :label, :attributes => { :for => 'rrdata' }, :content => 'Data:'
			assert_tag :input, :attributes => { :type => 'text', :name => 'rrdata' }
			assert_tag :input, :attributes => { :type => 'submit', :name => 'commit', :value => 'Add Record' }
		end
	end

	with_mocha do
		def test_add_post
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			NSUpdate.expects(:new).with(:zone => 'example.org',
			                            :server => '127.0.0.1',
			                            :key => nil
			                           ).returns(n = mock())
			n.expects(:add).with('hissy', :type => 'TXT', :ttl => '300', :data => "he's an adder!")
			n.expects(:send_update)

			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				post :add,
				     { :hostname => "hissy",
				       :ttl => 300,
				       :rrtype => "TXT",
				       :rrdata => "he's an adder!",
				       :commit => 'Add Record'
				     },
				     { :domain => 'example.org' }
			end
			
			assert_response :redirect
			assert_redirected_to :action => 'zone'
			
			assert_equal "Record <tt>hissy 300 TXT he's an adder!</tt> has been added.", flash[:notice]
		end
	end
	
	with_mocha do
		def test_add_post_with_key
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1',
			          :key => 'Kexample.org.+157+00000')
			NSUpdate.expects(:new).with(:zone => 'example.org',
			                            :server => '127.0.0.1',
			                            :key => 'Kexample.org.+157+00000'
			                           ).returns(n = mock())
			n.expects(:add).with('hissy', :type => 'TXT', :ttl => '300', :data => "he's an adder!")
			n.expects(:send_update)

			with_domainfile('example.org' => {'master' => '127.0.0.1', 'key' => 'Kexample.org.+157+00000'}) do
				post :add,
				     { :hostname => "hissy", :ttl => 300, :rrtype => "TXT", :rrdata => "he's an adder!", :commit => 'Add Record' },
				     { :domain => 'example.org' }
			end
			
			assert_response :redirect
			assert_redirected_to :action => 'zone'
			
			assert_equal "Record <tt>hissy 300 TXT he's an adder!</tt> has been added.", flash[:notice]
		end
	end

	with_mocha do
		def test_add_relative_cname
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			NSUpdate.expects(:new).with(:zone => 'example.org',
			                            :server => '127.0.0.1',
			                            :key => nil
			                           ).returns(n = mock())
			n.expects(:add).with('hissy', :type => 'CNAME', :ttl => '300', :data => "foo.example.org")
			n.expects(:send_update)

			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				post :add,
				     { :hostname => "hissy", :ttl => 300, :rrtype => "CNAME", :rrdata => "foo", :commit => 'Add Record' },
				     { :domain => 'example.org' }
			end
			
			assert_response :redirect
			assert_redirected_to :action => 'zone'
			
			assert_equal "Record <tt>hissy 300 CNAME foo.example.org</tt> has been added.", flash[:notice]
		end
	end

	with_mocha do
		def test_add_absolute_cname
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			NSUpdate.expects(:new).with(:zone => 'example.org',
			                            :server => '127.0.0.1',
			                            :key => nil
			                           ).returns(n = mock())
			n.expects(:add).with('hissy', :type => 'CNAME', :ttl => '300', :data => "foo.com")
			n.expects(:send_update)

			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				post :add,
				     { :hostname => "hissy", :ttl => 300, :rrtype => "CNAME", :rrdata => "foo.com.", :commit => 'Add Record' },
				     { :domain => 'example.org' }
			end
			
			assert_response :redirect
			assert_redirected_to :action => 'zone'
			
			assert_equal "Record <tt>hissy 300 CNAME foo.com</tt> has been added.", flash[:notice]
		end
	end

	with_mocha do
		def test_edit_unknown_record
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				get :edit, { :id => 'flahflah__A__127.0.0.1' }, { :domain => 'example.org'}
			end

			assert_response :redirect
			assert_redirected_to :action => 'zone'
			
			assert_equal "Could not find record with ID <tt>flahflah__A__127.0.0.1</tt>", flash[:error]
		end
	end

	with_mocha do
		def test_edit_begin
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				get :edit, { :id => 'moe__A__192.168.1.3' }, { :domain => 'example.org' }
			end
			
			assert_response :success
			
			assert_tag :tag => 'form',
			           :attributes => { 'method' => 'post',
			                            'action' => '/dnsmanager/edit/moe__A__192.168.1.3'
			                          }

			assert_tag :tag => 'input',
			           :attributes => { 'type' => 'text',
			                            'name' => 'hostname',
			                            'value' => 'moe'
			                          }

			assert_tag :tag => 'input',
			           :attributes => { 'type' => 'text',
			                            'name' => 'ttl',
			                            'value' => '1200'
			                          }

			assert_tag :tag => 'input',
			           :attributes => { 'type' => 'text',
			                            'name' => 'rrtype',
			                            'value' => 'A'
			                          }

			assert_tag :tag => 'input',
			           :attributes => { 'type' => 'text',
			                            'name' => 'rrdata',
			                            'value' => '192.168.1.3'
			                          }

			assert_tag :tag => 'input',
			           :attributes => { 'type' => 'submit',
			                            'name' => 'commit',
			                            'value' => 'Update Record'
			                          }
		end
	end

	with_mocha do
		def test_edit_update
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			NSUpdate.expects(:new).with(:zone => 'example.org',
			                            :server => '127.0.0.1',
			                            :key => nil
			                           ).returns(n = mock())
			n.expects(:delete).with('baldie', :type => 'CNAME', :data => 'curly.example.org')
			n.expects(:add).with('hissy', :type => 'CNAME', :ttl => '450', :data => "shiny.example.org")
			n.expects(:send_update)

			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				post :edit, { :id => 'baldie__CNAME__curly',
				              :hostname => 'baldie',
				              :ttl => '450',
				              :rrtype => 'CNAME',
				              :rrdata => 'shiny',
				              :commit => 'Update Record'
				            },
			               { :domain => 'example.org' }
			end
			
			assert_response :redirect
			assert_redirected_to :action => 'zone'
		end
	end
	
	with_mocha do
		def test_mx_edit_begin
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				get :edit, { :id => '__MX__10+moe.example.org.' }, { :domain => 'example.org' }
			end
			
			assert_response :success
			
			assert_tag :tag => 'form',
			           :attributes => { 'method' => 'post',
			                            'action' => '/dnsmanager/edit/__MX__10+moe.example.org.'
			                          }

			assert_tag :tag => 'input',
			           :attributes => { 'type' => 'text',
			                            'name' => 'hostname',
			                            'value' => ''
			                          }

			assert_tag :tag => 'input',
			           :attributes => { 'type' => 'text',
			                            'name' => 'ttl',
			                            'value' => '1200'
			                          }

			assert_tag :tag => 'input',
			           :attributes => { 'type' => 'text',
			                            'name' => 'rrtype',
			                            'value' => 'MX'
			                          }

			assert_tag :tag => 'input',
			           :attributes => { 'type' => 'text',
			                            'name' => 'rrdata',
			                            'value' => '10 moe.example.org.'
			                          }

			assert_tag :tag => 'input',
			           :attributes => { 'type' => 'submit',
			                            'name' => 'commit',
			                            'value' => 'Update Record'
			                          }
		end
	end

	with_mocha do
		def test_edit_update
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			NSUpdate.expects(:new).with(:zone => 'example.org',
			                            :server => '127.0.0.1',
			                            :key => nil
			                           ).returns(n = mock())
			n.expects(:delete).with('', :type => 'MX', :data => '10 moe.example.org.')
			n.expects(:add).with('', :type => 'MX', :ttl => '450', :data => "20 curly.example.org.")
			n.expects(:send_update)

			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				post :edit, { :id => '__MX__10+moe.example.org.',
				              :hostname => '',
				              :ttl => '450',
				              :rrtype => 'MX',
				              :rrdata => '20 curly.example.org.',
				              :commit => 'Update Record'
				            },
				            { :domain => 'example.org'
				            }
			end
			
			assert_response :redirect
			assert_redirected_to :action => 'zone'
		end
	end
	
	with_mocha do
		def test_edit_update_with_key
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1',
			          :key => 'Kexample.org.+157+00000')
			NSUpdate.expects(:new).with(:zone => 'example.org',
			                            :server => '127.0.0.1',
			                            :key => 'Kexample.org.+157+00000'
			                           ).returns(n = mock())
			n.expects(:delete).with('baldie', :type => 'CNAME', :data => 'curly.example.org.')
			n.expects(:add).with('baldie', :type => 'CNAME', :ttl => '450', :data => "shiny.example.org.")
			n.expects(:send_update)

			with_domainfile('example.org' => {'master' => '127.0.0.1', 'key' => 'Kexample.org.+157+00000'}) do
				post :edit, { :id => 'baldie__CNAME__curly.example.org.',
				              :hostname => 'baldie',
				              :ttl => '450',
				              :rrtype => 'CNAME',
				              :rrdata => 'shiny',
				              :commit => 'Update Record'
				            },
				            { :domain => 'example.org' }
			end
			
			assert_response :redirect
			assert_redirected_to :action => 'zone'
		end
	end
	
	with_mocha do
		def test_add_an_ns_record
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			NSUpdate.expects(:new).with(:zone => 'example.org',
			                            :server => '127.0.0.1',
			                            :key => nil
			                           ).returns(n = mock())
			n.expects(:add).with('', :type => 'NS', :ttl => '300', :data => "ns69.example.com.")
			n.expects(:send_update)

			out = nil
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				post :add,
				     { :hostname => "", :ttl => 300, :rrtype => "NS", :rrdata => "ns69.example.com.", :commit => 'Add Record' },
				     { :domain => 'example.org' }
			end
			
			assert_response :redirect
			assert_redirected_to :action => 'zone'
		end
	end
	
	with_mocha do
		def test_edit_update_for_ns_record
			mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
			NSUpdate.expects(:new).with(:zone => 'example.org',
			                            :server => '127.0.0.1',
			                            :key => nil
			                           ).returns(n = mock())
			n.expects(:delete).with('', :type => 'NS', :data => 'ns1.example.org.')
			n.expects(:add).with('', :type => 'NS', :ttl => '450', :data => "ns3.example.org.")
			n.expects(:send_update)

			out = nil
			with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
				post :edit, { :id => '__NS__ns1.example.org.',
				              :hostname => '',
				              :ttl => '450',
				              :rrtype => 'NS',
				              :rrdata => 'ns3.example.org.',
				              :commit => 'Update Record'
				            },
				            { :domain => 'example.org' }
			end
			
			assert_response :redirect
			assert_redirected_to :action => 'zone'
		end
	end

	def test_add_fails_because_the_key_was_wrong
		# FIXME: write this test
	end

	def test_edit_fails_because_the_original_record_doesnt_exist
		# FIXME: write this test
	end
	
	def test_delete_fails_because_the_record_doesnt_exist
		# FIXME: write this test
	end
	
	def test_add_fails_because_of_a_server_timeout
		# FIXME: write this test
	end
end
