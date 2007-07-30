require 'yaml'
require 'digest/sha1'

class DnsmanagerController < ApplicationController
	before_filter :unscramble_id, :only => %w{add edit delete}
	
	requires_authentication :using => :authenticate_user, :realm => "DNS Manager"
	
	def unscramble_id
		if params[:id]
			params[:id] = params[:id].gsub('+', ' ')
		end
	end
	
	def index
		redirect_to :action => 'zone'
	end

	def zone
		if params['commit'] == 'Change Domain'
			session[:domain] = params['domain']
		end

		unless session[:domain].to_s.empty?
			dom = Domain.new(session[:domain])

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

	def add
		@domain = Domain.new(session[:domain])
		@rr = DomainRecord.new(@domain)

		if params['commit'] == 'Add Record'
			params['rrdata'] = @domain.add(params['hostname'], params['rrtype'], params['rrdata'], params['ttl'])
			flash[:notice] = "Record <tt>#{params['hostname']} #{params['ttl']} #{params['rrtype']} #{params['rrdata']}</tt> has been added."
			redirect_to :action => 'zone'
		end
	end

	def edit
		@domain = Domain.new(session[:domain])
		@rr = @domain.find(params[:id])

		if @rr.nil?
			flash[:error] = "Could not find record with ID <tt>#{params[:id]}</tt>"
			redirect_to :action => 'zone'
			return
		end
		
		if params['commit'] == 'Update Record'
			newrr = @rr.clone
			newrr.hostname = params['hostname']
			newrr.ttl = params['ttl']
			newrr.rrtype = params['rrtype']
			newrr.rrdata = params['rrdata']
			@domain.replace(@rr, newrr)
			
			redirect_to :action => 'zone'
		end
	end

	def delete
		dr = Domain.new(session[:domain]).find(params[:id])
		unless dr.nil?
			dr.delete
			flash[:notice] = "Record <tt>#{dr.hostname} #{dr.rrtype} #{dr.rrdata}</tt> has been deleted."
		end

		redirect_to :action => 'zone'
	end
end
