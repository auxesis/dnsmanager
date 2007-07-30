# Register a command with the subcommand pattern manager.
#
# The name of each command must be provided as a string, while the
# options specify all sorts of useful information about the command, such as:
#
#  - +:arg_count+: An integer or range specifying how many arguments this
#    command will accept.  If missing, any number of arguments will be
#    permitted.  You may assume in your command code that the number of
#    arguments you are passed satisfies this parameter.
#  - +:summary+: A one-line description of what the command does.
#  - +:usage+: A one-line description of how the command should be called.
#  - +:help+: A big string giving help on the command.
#
# You must also provide a block of code to be executed when the command is
# called.  This block will be given it's arguments through an array as it's
# sole parameter.
#
def register_command(cmd, opts, &block)
	$commands ||= {}
	raise ArgumentError.new("No block given with registraton of #{cmd}") unless block_given?
	opts[:block] = block 
	$commands[cmd] = opts
end

# Run the command line given in +argv+.  The subcommand to run is taken from
# the first argument, and the argument list is the rest of the list.
def run_command(argv)
	cmd = argv.shift
	unless $commands.keys.include? cmd
		raise ArgumentError.new("Unknown command #{cmd}")
	end
	
	opts = $commands[cmd]
	unless opts[:arg_count].nil?
		ArgumentError.new("Too many/few arguments to #{cmd}") unless argv.length == opts[:arg_count]
	end
	
	opts[:block].call(argv)
end
