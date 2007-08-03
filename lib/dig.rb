class Dig
	class Error < StandardError
	end
	
	def initialize(options = {})
		options = { :server => '127.0.0.1' }.merge(options)
		@server = options[:server]
		@key = options[:key]
		unless @key.nil?
			@key = File.expand_path(File.join(RAILS_ROOT, 'config', 'dns_keys', @key + '.private'))
		end
	end
	
	# Perform a zone transfer for the specified zone.
	def axfr(zone)
		key_opt = @key ? "-k #{@key}" : ''
		returning `dig #{key_opt} @#{@server} IN AXFR #{zone}` do |output|
			if output =~ /; Transfer failed/
				RAILS_DEFAULT_LOGGER.warn("Dig failed.  Output was:")
				output.each_line { |l| RAILS_DEFAULT_LOGGER.warn(l.strip) }
				raise Dig::Error.new("Call to dig failed.")
			elsif $?.exitstatus != 0
				RAILS_DEFAULT_LOGGER.warn("Dig failed with exit code #{$?.exitstatus}")
				raise Dig::Error.new("Call to dig failed.")
			end
		end
	end

	private
	# Log all calls to dig
	def `(cmd)  #`
		RAILS_DEFAULT_LOGGER.debug("Running #{cmd}")
		Kernel.`(cmd)  #`
	end
end
