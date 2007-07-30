ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'application'
require 'test/unit'
require 'action_controller/test_process'
require 'breakpoint'
require 'tempfile'

class Test::Unit::TestCase
	def faux_dig(opts = {})
		unless opts[:wants_key].nil?
			key_path = File.join(RAILS_ROOT, 'config', 'dns_keys')
			ENV['FAUX_DIG_KEY'] = File.expand_path(File.join(key_path, opts[:wants_key]))
		end

		@realpath = ENV['PATH']
		ENV['PATH'] = File.expand_path(File.dirname(__FILE__) + '/fixtures')
		yield if block_given?
		ENV['PATH'] = @realpath
		
		ENV['FAUX_DIG_KEY'] = nil
	end

	def faux_nsupdate(opts = {})
		unless opts[:wants_key].nil?
			key_path = File.join(RAILS_ROOT, 'config', 'dns_keys')
			ENV['FAUX_NSUPDATE_KEY'] = File.expand_path(File.join(key_path, opts[:wants_key]))
		end
		
		@realpath = ENV['PATH']
		ENV['PATH'] = File.expand_path(File.dirname(__FILE__) + '/fixtures')
		tmpfile = Tempfile.new('dnsmanager_faux_nsupdate')
		ENV['FAUX_NSUPDATE_OUTPUT'] = tmpfile.path
		yield if block_given?
		output = File.read(tmpfile.path)
		tmpfile.close
		tmpfile.unlink
		
		ENV['FAUX_NSUPDATE_KEY'] = nil
		
		return output
	end

	def with_pwfile(contents)
		orig_pwfile = $pwfile
		tmpfile = Tempfile.new('with_pwfile')
		$pwfile = tmpfile.path
		tmpfile.close
		File.open(tmpfile.path, 'w') { |fd| YAML.dump(contents, fd) }
		yield tmpfile.path
		tmpfile.unlink
		$pwfile = orig_pwfile
	end

	def with_domainfile(contents)
		orig_domainfile = $domainfile
		tmpfile = Tempfile.new('with_domainlist')
		$domainfile = tmpfile.path
		tmpfile.close
		File.open(tmpfile.path, 'w') { |fd| YAML.dump(contents, fd) }
		yield
		tmpfile.unlink
		$domainfile = orig_domainfile
	end

	def http_login(u, p)
		@request.env['HTTP_AUTHORIZATION'] = "Basic #{Base64.encode64("#{u}:#{p}")}"
	end
	
	def unlogin
		@request.env['HTTP_AUTHORIZATION'] = ''
	end
end
