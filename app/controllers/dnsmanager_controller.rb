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
	
	def add
		@domain = Domain.new(params[:domain])
		@rr = DomainRecord.new(@domain)

		if params['commit'] == 'Add Record'
			params['rrdata'] = @domain.add(params['hostname'], params['rrtype'], params['rrdata'], params['ttl'])
			flash[:notice] = "Record <tt>#{params['hostname']} #{params['ttl']} #{params['rrtype']} #{params['rrdata']}</tt> has been added."
			redirect_to domain_path(:domain => params[:domain])
		end
	end

	def edit
		@domain = Domain.new(params[:domain])
		@rr = @domain.find(params[:id])

		if @rr.nil?
			flash[:error] = "Could not find record with ID <tt>#{params[:id]}</tt>"
			redirect_to domain_path(:domain => params[:domain]) and return
			return
		end
		
		if params['commit'] == 'Update Record'
			newrr = @rr.clone
			newrr.ttl = params['ttl']
			newrr.rrtype = params['rrtype']
			newrr.rrdata = params['rrdata']
			@domain.replace(@rr, newrr)
			
			redirect_to domain_path(params[:domain])
		end
	end

	def delete
		dr = Domain.new(params[:domain]).find(params[:id])
		unless dr.nil?
			dr.delete
			flash[:notice] = "Record <tt>#{dr.hostname} #{dr.rrtype} #{dr.rrdata}</tt> has been deleted."
		end

		redirect_to domain_path(params[:domain])
	end
end
