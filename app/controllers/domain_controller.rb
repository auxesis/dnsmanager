require 'yaml'
require 'digest/sha1'

class DomainController < ApplicationController
	requires_authentication :using => :authenticate_user, :realm => "DNS Manager"
	
	def index
		if params['commit'] == 'Change Domain'
			redirect_to :action => 'index', :domain => params['domain'] and return
		end

		unless params[:domain].to_s.empty?
			@domain = params[:domain]
			dom = Domain.new(@domain)

			@soa = dom['SOA'][0]
			@ns = dom['NS']
			@aliases = (dom['CNAME'] + dom['MX']).sort_by { |e| e.idstring }
			@hosts = (dom['A'] + dom['TXT']).sort_by { |e| e.idstring }
		else
			@soa = nil
			@ns = @aliases = @hosts = []
		end
		
		@domainlist = [['---', '']] + YAML::load_file($domainfile).keys.map {|v| [v]}.sort
	end
end
