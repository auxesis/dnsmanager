require File.dirname(__FILE__) + '/../test_helper'
require 'domain_controller'
require 'lib/nsupdate'

# Re-raise errors caught by the controller.
class DomainController; def rescue_action(e) raise e end; end

class DomainControllerTest < Test::Unit::TestCase
	def setup
		@controller = DomainController.new
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

	def test_000_access_denied
		unlogin
		get :index
		
		assert_response 401
		assert_equal 'Basic realm="DNS Manager"', @response.headers['WWW-Authenticate']
	end

	def test_010_front_page
		assert_routing '/', :controller => 'domain', :action => 'index'
		
		with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
			get :index
		end

		assert_response :success

		assert_elements("//form[@action='/']") do
			assert_equal 2, elements("//select[@name='domain']/option").length

			btn = element("//input[@type='submit']")
			assert_equal 'commit', btn['name']
			assert_equal 'Change Domain', btn['value']
			assert_nil element("//a[@href='/dnsmanager/add']")
		end
	end

	def test_020_sorted_domain_list
		with_domainfile('example.org' => {'master' => '127.0.0.1'},
		                'something.com' => {'master' => '127.0.0.1'},
		                'xyzzy.net' => {'master' => '127.0.0.1'},
		                'abba.biz' => {'master' => '127.0.0.1'},
		                'hezmatt.org' => {'master' => '127.0.0.1'}) do
			get :index
		end
		
		assert_equal [['---', ''],
		              ['abba.biz'],
		              ['example.org'],
		              ['hezmatt.org'],
		              ['something.com'],
		              ['xyzzy.net']],
		             assigns(:domainlist)
		assert_elements("//select[@name='domain']/option[@value='abba.biz']")
		assert_elements("//select[@name='domain']/option[@value='']")
		assert_equal '---', tag("//select[@name='domain']/option[@value='']")
	end

	def test_030_select_a_domain
		with_domainfile('something.com' => {'master' => '127.0.0.1'}) do
			post :index, {:domain => 'something.com', :commit => 'Change Domain'}
		end
		
		assert_response :redirect
		assert_redirected_to '/something.com'
	end

	def test_031_select_a_domain_we_dont_have
		# FIXME: Write this test
	end

	def test_040_show_domain
		mock_axfr(:master => '127.0.0.1', :domain => 'example.org')
		with_domainfile('example.org' => {'master' => '127.0.0.1'}) do
			get :index, :domain => 'example.org'
		end
		
		assert_equal DomainRecord, assigns['soa'].class
		assert_equal 2, assigns['ns'].length
		assert_equal 3, assigns['aliases'].length
		assert_equal 3, assigns['hosts'].length
		
		assert_response :success
		assert tags("//tr/td").include?('larry')

		assert_equal '(delete)', tag("//td/a[@href='/example.org/delete/baldie__CNAME__curly.example.org.']")

		assert_equal 'Add Record', tag("//a[@href='/example.org/add']")
		assert_equal '(edit)', tag("//a[@href='/example.org/edit/baldie__CNAME__curly.example.org.']")
		assert_equal '(edit)', tag("//a[@href='/example.org/edit/__MX__10+moe.example.org.']")
		assert_equal 'example.org', tag("//form[@action='/']//select[@name='domain']/option[@selected='selected']")
		assert_equal 'example.org', element("//form[@action='/']//select[@name='domain']/option[@selected='selected']")['value']
	end
	
	def test_050_show_domain_using_a_key
		mock_axfr(:domain => 'example.org', :master => '127.0.0.1',
		          :key => 'Kexample.org.+157.+random')
		with_domainfile('example.org' => {'master' => '127.0.0.1', 'key' => 'Kexample.org.+157.+random'}) do
			get :index, :domain => 'example.org'
		end
			
		# If we got *something*, we'll consider it a win
		assert_equal DomainRecord, assigns['soa'].class
	end
end
