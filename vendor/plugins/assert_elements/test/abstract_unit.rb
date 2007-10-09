RAILS_ENV = 'test'

require 'test/unit'
begin
	require 'hpricot'
rescue LoadError => e
	begin
		require 'rubygems'
		require 'hpricot'
	rescue LoadError => e
		puts "It's hard to test a hpricot test_helper without hpricot."
		puts "Please install hpricot ('gem install hpricot') and try again."
		exit 0
	end
end

begin
	require 'action_controller'
	require 'action_controller/test_process'
rescue LoadError => e
	begin
		require 'rubygems'
		require 'action_controller'
		require 'action_controller/test_process'
	rescue LoadError => e
		puts "Cannot find actionpack, which is needed to run the test suite."
		puts "Please install it as a gem or somewhere in your load path, and try again."
		exit 0
	end
end

# Setup basic routes so our tests don't explode
ActionController::Routing::Routes.draw do |map|
	map.connect ":controller/:action/:id"
end
	
load File.dirname(__FILE__) + '/../init.rb'

# Define this ourselves to avoid faffing around with including all of
# activesupport.
class Symbol
	def to_proc
		Proc.new { |*args| args.shift.__send__(self, *args) }
	end
end
