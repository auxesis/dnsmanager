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
		get :add, :domain => 'example.org'
		
		assert_response 401
		assert_equal 'Basic realm="DNS Manager"', @response.headers['WWW-Authenticate']
	end

	def test_delete_a_record
		assert_routing '/example.org/delete/fake_id',
		               :controller => 'dnsmanager',
		               :action => 'delete',
		               :domain => 'example.org',
		               :id => 'fake_id'
		               
		mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
		NSUpdate.expects(:new).with(:zone => 'example.org',
		                            :server => '127.0.0.1',
		                            :key => nil).returns(n = mock())
		n.expects(:delete).with('larry', :type => 'A', :data => '192.168.1.1')
		n.expects(:send_update)

		with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
			get :delete, :id => "larry__A__192.168.1.1", :domain => 'example.org'
		end
			
		assert_response :redirect
		assert_redirected_to '/example.org'
		assert_equal "Record <tt>larry A 192.168.1.1</tt> has been deleted.", flash[:notice]
	end

	def test_delete_mx_record
		mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
		NSUpdate.expects(:new).with(:zone => 'example.org',
		                            :server => '127.0.0.1',
		                            :key => nil).returns(n = mock())
		n.expects(:delete).with('', :type => 'MX', :data => '10 moe.example.org.')
		n.expects(:send_update)

		with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
			get :delete, :id => "__MX__10+moe.example.org.", :domain => 'example.org'
		end
		
		assert_response :redirect
		assert_redirected_to '/example.org'
			
		assert_equal "Record <tt> MX 10 moe.example.org.</tt> has been deleted.", flash[:notice]
	end

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
			get :delete, :id => "larry__A__192.168.1.1", :domain => 'example.org'
		end
			
		assert_response :redirect
		assert_redirected_to '/example.org'
			
		assert_equal "Record <tt>larry A 192.168.1.1</tt> has been deleted.", flash[:notice]
	end
	
	def test_add_display
		assert_routing '/example.org/add',
		               :controller => 'dnsmanager',
		               :action => 'add',
		               :domain => 'example.org'

		mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
		with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
			get :add, :domain => 'example.org'
		end
			
		assert_response :success
			
		assert_equal 'Hostname:', tag("//label[@for='hostname']")
		assert_elements("//input[@type='text',@name='hostname']")
		assert_equal 'TTL:', tag("//label[@for='ttl']")
		assert_elements("//input[@type='text',@name='ttl']")
		assert_equal 'Type:', tag("//label[@for='rrtype']")
		assert_elements("//input[@type='text',@name='rrtype']")
		assert_equal 'Data:', tag("//label[@for='rrdata']")
		assert_elements("//input[@type='text',@name='rrdata']")
		assert_elements("//input[@type='submit',@name='commit',@value='Add Record']")
	end

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
			       :commit => 'Add Record',
			       :domain => 'example.org'
			     }
		end
			
		assert_response :redirect
		assert_redirected_to '/example.org'
			
		assert_equal "Record <tt>hissy 300 TXT he's an adder!</tt> has been added.", flash[:notice]
	end
	
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
			     :hostname => "hissy", :ttl => 300, :rrtype => "TXT", :rrdata => "he's an adder!", :commit => 'Add Record',
			     :domain => 'example.org'
		end
			
		assert_response :redirect
		assert_redirected_to '/example.org'
			
		assert_equal "Record <tt>hissy 300 TXT he's an adder!</tt> has been added.", flash[:notice]
	end

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
			     :hostname => "hissy", :ttl => 300, :rrtype => "CNAME", :rrdata => "foo", :commit => 'Add Record',
			     :domain => 'example.org'
		end
			
		assert_response :redirect
		assert_redirected_to '/example.org'
			
		assert_equal "Record <tt>hissy 300 CNAME foo.example.org</tt> has been added.", flash[:notice]
	end

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
			     :hostname => "hissy", :ttl => 300, :rrtype => "CNAME", :rrdata => "foo.com.", :commit => 'Add Record',
			     :domain => 'example.org'
		end
			
		assert_response :redirect
		assert_redirected_to '/example.org'
			
		assert_equal "Record <tt>hissy 300 CNAME foo.com</tt> has been added.", flash[:notice]
	end

	def test_edit_unknown_record
		mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
		with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
			get :edit, :id => 'flahflah__A__127.0.0.1', :domain => 'example.org'
		end

		assert_response :redirect
		assert_redirected_to '/example.org'
			
		assert_equal "Could not find record with ID <tt>flahflah__A__127.0.0.1</tt>", flash[:error]
	end

	def test_edit_begin
		assert_routing '/example.org/edit/fake_id',
		               :controller => 'dnsmanager',
		               :action => 'edit',
		               :domain => 'example.org',
		               :id => 'fake_id'
		               
		mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
		with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
			get :edit, :id => 'moe__A__192.168.1.3', :domain => 'example.org'
		end
			
		assert_response :success
			
		assert_elements("//form[@method='post',@action='/dnsmanager/edit/moe__A__192.168.1.3']") do
			assert_elements("input[@type='text',@name='hostname',@value='moe']")
			assert_elements("input[@type='text',@name='ttl',@value='1200']")
			assert_elements("input[@type='text',@name='rrtype',@value='A']")
			assert_elements("input[@type='text',@name='rrdata',@value='192.168.1.3']")
			assert_elements("input[@type='submit',@name='commit',@value='Update Record']")
		end
	end

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
			              :commit => 'Update Record',
		                 :domain => 'example.org'
		               }
		end
			
		assert_response :redirect
		assert_redirected_to '/example.org'
	end
	
	def test_mx_edit_begin
		mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
		with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
			get :edit, :id => '__MX__10+moe.example.org.', :domain => 'example.org'
		end
			
		assert_response :success
		
		assert_elements("//form[@method='post',@action='/dnsmanager/edit/__MX__10+moe.example.org.']") do
			assert_elements("input[@type='text',@name='hostname',@value='']")
			assert_elements("input[@type='text',@name='ttl',@value='1200']")
			assert_elements("input[@type='text',@name='rrtype',@value='MX']")
			assert_elements("input[@type='text',@name='rrdata',@value='10 moe.example.org.']")
			assert_elements("input[@type='submit',@name='commit',@value='Update Record']")
		end
	end

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
			              :commit => 'Update Record',
			              :domain => 'example.org'
			            }
		end
			
		assert_response :redirect
		assert_redirected_to '/example.org'
	end
	
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
			              :commit => 'Update Record',
			              :domain => 'example.org'
			            }
		end
			
		assert_response :redirect
		assert_redirected_to '/example.org'
	end
	
	def test_add_an_ns_record
		mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
		NSUpdate.expects(:new).with(:zone => 'example.org',
		                            :server => '127.0.0.1',
		                            :key => nil
		                           ).returns(n = mock())
		n.expects(:add).with('', :type => 'NS', :ttl => '300', :data => "ns69.example.com.")
		n.expects(:send_update)

		with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
			post :add,
			     :hostname => "", :ttl => 300, :rrtype => "NS", :rrdata => "ns69.example.com.", :commit => 'Add Record',
			     :domain => 'example.org'
		end
			
		assert_response :redirect
		assert_redirected_to '/example.org'
	end
	
	def test_edit_update_for_ns_record
		mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
		NSUpdate.expects(:new).with(:zone => 'example.org',
		                            :server => '127.0.0.1',
		                            :key => nil
		                           ).returns(n = mock())
		n.expects(:delete).with('', :type => 'NS', :data => 'ns1.example.org.')
		n.expects(:add).with('', :type => 'NS', :ttl => '450', :data => "ns3.example.org.")
		n.expects(:send_update)

		with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
			post :edit, { :id => '__NS__ns1.example.org.',
			              :hostname => '',
			              :ttl => '450',
			              :rrtype => 'NS',
			              :rrdata => 'ns3.example.org.',
			              :commit => 'Update Record',
			              :domain => 'example.org'
			            }
		end
			
		assert_response :redirect
		assert_redirected_to '/example.org'
	end

	def test_support_deprecated_zone_action
		# We used to use /dnsmanager/zone to manage zones, but we're going
		# RESTful and don't need this URL any more, but it's apparently in
		# bookmarks or URL history, so we'll support it for now.
		assert_recognizes({ :controller => 'domain', :action => 'index' },
		                  '/dnsmanager/zone')
	end

	def test_add_fails_because_nsupdate_failed
		mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
		NSUpdate.expects(:new).with(:zone => 'example.org',
		                            :server => '127.0.0.1',
		                            :key => nil
		                           ).returns(n = mock())
		n.expects(:add).with('', :type => 'MX', :ttl => '450', :data => "mx.example.org.")
		n.expects(:send_update).raises(NSUpdate::Error.new("MX records must have a priority!"))

		with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
			post :add, { :hostname => '',
			             :ttl => '450',
			             :rrtype => 'MX',
			             :rrdata => 'mx.example.org.',
			             :commit => 'Add Record',
			             :domain => 'example.org'
			            }
		end
			
		assert_response :success
		
		assert_equal "Update failed: MX records must have a priority!", flash[:error]
	end

	def test_edit_fails_because_nsupdate_failed
		mock_axfr(:domain => 'example.org', :master => '127.0.0.1')
		NSUpdate.expects(:new).with(:zone => 'example.org',
		                            :server => '127.0.0.1',
		                            :key => nil
		                           ).returns(n = mock())
		n.expects(:delete).with('', :type => 'NS', :data => 'ns1.example.org.')
		n.expects(:add).with('', :type => 'MX', :ttl => '450', :data => "mx.example.org.")
		n.expects(:send_update).raises(NSUpdate::Error.new("MX records must have a priority!"))

		with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
			post :edit, { :id => '__NS__ns1.example.org.',
			              :hostname => '',
			              :ttl => '450',
			              :rrtype => 'MX',
			              :rrdata => 'mx.example.org.',
			              :commit => 'Update Record',
			              :domain => 'example.org'
			            }
		end
			
		assert_response :success
		
		assert_equal "Update failed: MX records must have a priority!", flash[:error]
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
