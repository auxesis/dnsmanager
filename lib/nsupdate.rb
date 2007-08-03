require 'open3'

class NSUpdate
	class Error < StandardError
	end

	attr_writer :server, :zone
	
	def initialize(options = {})
		options = { :server => '127.0.0.1' }.merge(options)
		@server = options[:server]
		@key = options[:key]
		@zone = options[:zone]

		@current_request = []
		
		unless @key.nil?
			@key = File.expand_path(File.join(RAILS_ROOT, 'config', 'dns_keys', @key + '.private'))
		end
	end

	def add rrname, opts
		raise ArgumentError.new("You must give a TTL") unless opts[:ttl]
		raise ArgumentError.new("You must give an RR type") unless opts[:type]
		raise ArgumentError.new("You must provide some RR data") unless opts[:data]
		
		# A leading dot in the record we're adding gets stripped, because that
		# means we have an empty rrname and hence the record we're working on
		# is the zone itself
		full_name = "#{rrname}.#{@zone}".gsub(/^\./, '')
		@current_request << "update add #{full_name} #{opts[:ttl]} #{opts[:type]} #{opts[:data]}"
	end

	def delete rrname, opts = {}
		bits = ["#{rrname}.#{@zone}".gsub(/^\./, ''), opts[:ttl], opts[:type], opts[:data]].select {|v| v}
		@current_request << "update delete #{bits.join(' ')}"
	end
		
	
	def send_update
		@current_request = ["server #{@server}", "zone #{@zone}"] + @current_request
		@current_request << 'send'

		if @key
			cmd = "nsupdate -k #{@key}"
		else
			cmd = 'nsupdate'
		end
		
		RAILS_DEFAULT_LOGGER.debug("Running #{cmd}")
		RAILS_DEFAULT_LOGGER.debug("Giving nsupdate the following:")
		@current_request.each { |l| RAILS_DEFAULT_LOGGER.debug('    ' + l) }
		RAILS_DEFAULT_LOGGER.debug('-' * 20)
		
		Open3.popen3(cmd) do |stdin, stdout, stderr|
			# Send the request...
			@current_request.each { |l| stdin.puts(l) }
			# Then close stdin so that nsupdate knows we're done
			stdin.close
			# And now we wait to see if we got an error
			response = stderr.gets.to_s.strip
			if response != ''
				RAILS_DEFAULT_LOGGER.error("nsupdate failed: #{response}")
				raise NSUpdate::Error.new(response)
			end
		end
		
		@current_request.clear
	end
end
