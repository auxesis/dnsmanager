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
		
		@current_request << "update add #{rrname}.#{@zone} #{opts[:ttl]} #{opts[:type]} #{opts[:data]}"
	end

	def delete rrname, opts = {}
		bits = ["#{rrname}.#{@zone}", opts[:ttl], opts[:type], opts[:data]].select {|v| v}
		@current_request << "update delete #{bits.join(' ')}"
	end
		
	
	def send_update
		@current_request = ["server #{@server}", "zone #{@zone}"] + @current_request
		@current_request << 'send'
		RAILS_DEFAULT_LOGGER.debug("Sending nsupdate request:")
		@current_request.each { |l| RAILS_DEFAULT_LOGGER.debug('    ' + l) }

		Open3.popen3('nsupdate') do |stdin, stdout, stderr|
			# Send the request...
			@current_request.each { |l| stdin.puts(l) }
			# Then close stdin so that nsupdate knows we're done
			stdin.close
			# And now we wait to see if we got an error
			response = stderr.gets.to_s.strip
			if response != ''
				RAILS_DEFAULT_LOGGER.info("nsupdate failed: #{response}")
				raise NSUpdate::Error.new(response)
			end
		end
		
		@current_request.clear
	end
	
	private
	# Log all calls to nsupdate
	def `(cmd)  #`
		RAILS_DEFAULT_LOGGER.debug("Running #{cmd}")
		Kernel.`(cmd)  #`
	end
end
