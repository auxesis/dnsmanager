# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
	def authenticate_user(u, p)
		pwdata = YAML::load_file($pwfile)
		
		Digest::SHA1.hexdigest(p) == pwdata[u]
	end
end
