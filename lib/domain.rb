require 'lib/nsupdate'

class Domain
	attr_reader :domain, :master

	def initialize(domain)
		domainlist = YAML::load_file($domainfile)
		
		@domain = domain
		raise ArgumentError.new("Unknown domain #{@domain}") if domainlist[@domain].nil?
		@master = domainlist[@domain]['master']
		@key = domainlist[@domain]['key']
		
		@rrlist = []
		
		dig = Dig.new(:master => @master, :key => @key)
		dig.axfr(@domain).each_line do |l|
			l.chomp!.gsub!(/;.*$/, '')

			if l =~ /^\s*(\S+)\s+(?:(\d+)\s+)?(?:IN\s+)?(\S+)\s+(.*?)\s*$/
				d = DomainRecord.new(self)
				# Has to be in this order, otherwise $[234] gets overwritten by
				# the results of the match in the $1.gsub
				d.ttl = $2.to_i unless $2.nil?
				d.rrtype = $3
				d.rrdata = $4
				d.hostname = $1.gsub(Regexp.new("\\.?#{domain}\\.$"), '')

				@rrlist << d unless ((d.rrtype == 'SOA') and (self['SOA'].length > 0))
			end
		end
	end

	def find(idstr)
		if idstr.to_s =~ /^(.*)__(.+)__(.*)$/
			hostname = $1
			rrtype = $2
			rrdata = $3
		else
			raise ArgumentError.new("Invalid idstring format")
		end
		
		@rrlist.select { |dr| hostname == dr.hostname && rrtype == dr.rrtype && rrdata == dr.rrdata }.first
	end

	def add(host, rrtype, rrdata, ttl = 86400)
		if rrtype.upcase == 'CNAME'
			# Append the current domain to the CNAME data part if it isn't
			# already a fully-qualified name, otherwise just strip the trailing
			# period because nsupdate doesn't like trailing periods.
			#
			# FIXME: Should this be in NSUpdate instead?  I'm not sure.  It all
			# depends on how faithful to the nsupdate command-line tool we want
			# NSUpdate to be.
			if rrdata[-1] == ?\.
				rrdata = rrdata[0..-2]
			else
				rrdata = "#{rrdata}.#{@domain}"
			end
		end

		n = NSUpdate.new(:server => @master, :zone => @domain, :key => @key)
		n.add host, :type => rrtype, :ttl => ttl, :data => rrdata
		n.send_update
		
		# EEeeeewww... But needed so I know what to put in the output to the
		# user.  But again, eeew.
		rrdata
	end

	def delete(host, rrtype = nil, rrdata = nil)
		if host.is_a? DomainRecord
			rrtype = host.rrtype
			rrdata = host.rrdata
			host = host.hostname
		else
			raise ArgumentError.new("must give an rrtype") if rrtype.nil?
		end

		n = NSUpdate.new(:zone => @domain, :server => @master, :key => @key)
		n.delete host, :type => rrtype, :data => rrdata
		n.send_update
	end

	def replace(oldrr, newrr)
		raise ArgumentError.new("Cannot replace a host record with one with a different hostname") unless oldrr.hostname == newrr.hostname
		if newrr.rrtype == 'CNAME' and newrr.rrdata[-1] != ?\.
			newrr.rrdata = newrr.rrdata + '.' + @domain + '.'
		end
		n = NSUpdate.new(:server => @master, :zone => @domain, :key => @key)
		n.delete oldrr.hostname, :type => oldrr.rrtype, :data => oldrr.rrdata
		n.add newrr.hostname, :ttl => newrr.ttl, :type => newrr.rrtype,
		      :data => newrr.rrdata
		n.send_update
	end

	def [] rrtype
		@rrlist.select { |item| item.rrtype == rrtype }.sort { |i1, i2|
			r = i1.hostname <=> i2.hostname
			if r == 0
				r = i1.rrdata <=> i2.rrdata
			end
			
			r
		}
	end
end

class DomainRecord
	attr_accessor :hostname, :rrtype, :rrdata, :ttl

	def initialize(dom)
		@domain = dom
	end

	def idstring
		"#{@hostname}__#{@rrtype}__#{@rrdata}"
	end
	
	def delete
		@domain.delete(@hostname, @rrtype, @rrdata)
	end
end
