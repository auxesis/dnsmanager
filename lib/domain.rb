class Domain
	attr_reader :domain, :master

	def initialize(domain)
		domainlist = YAML::load_file($domainfile)
		
		@domain = domain
		raise ArgumentError.new("Unknown domain #{@domain}") if domainlist[@domain].nil?
		@master = domainlist[@domain]['master']
		@keyopts = unless domainlist[@domain]['key'].nil?
			keyfile = File.expand_path(File.join(RAILS_ROOT,
			                                     'config',
			                                     'dns_keys',
			                                     domainlist[@domain]['key'] + '.private'
			                                    ))
			"-k #{keyfile}"
		end
		
		@rrlist = []
		
		`dig @#{master} #{@keyopts} IN AXFR #{domain}`.each_line do |l|
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
			# CNAMEs get handled differently because of the whole
			# relative/absolute thing.
			if rrdata[-1] == '.'[0]
				rrdata = rrdata[0..-2]
			else
				rrdata = "#{rrdata}.#{@domain}"
			end
		end
		
		IO.popen("nsupdate #{@keyopts}", 'w') do |fd|
			fd.puts "zone #{@domain}"
			fd.puts "server #{@master}"
			fd.puts "update add #{host}.#{@domain} #{ttl} #{rrtype} #{rrdata}"
			fd.puts "send"
		end
		
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

		fqdn = "#{host}.#{@domain}".gsub(/^\./, '')
			
		IO.popen("nsupdate #{@keyopts}", 'w') do |fd|
			fd.puts "zone #{@domain}"
			fd.puts "server #{@master}"
			fd.puts "update delete #{fqdn} #{rrtype} #{rrdata}"
			fd.puts "send"
		end
	end

	def replace(oldrr, newrr)
		oldfqdn = "#{oldrr.hostname}.#{@domain}".gsub(/^\./, '')
		newfqdn = "#{newrr.hostname}.#{@domain}".gsub(/^\./, '')

		IO.popen("nsupdate #{@keyopts}", 'w') do |fd|
			fd.puts "zone #{@domain}"
			fd.puts "server #{@master}"
			fd.puts "update delete #{oldfqdn} #{oldrr.rrtype} #{oldrr.rrdata}"
			fd.puts "update add #{newfqdn} #{newrr.ttl} #{newrr.rrtype} #{newrr.rrdata}"
			fd.puts "send"
		end
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
