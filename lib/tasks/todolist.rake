require 'find'

desc "Find the location of all todo/FIXME items"
task :todolist do
	Find.find('app', 'lib', 'test') do |f|
		unless f =~ /svn-base/ or
		       !File.file?(f) or
		       f =~ /test\/coverage/ or
		       File.expand_path(__FILE__).include?(f)
			found_in_file = false
			File.readlines(f).each_with_index do |l, i|
				if l =~ /#.*(@@todo|FIXME)\s*(.*)$/
					unless found_in_file
						puts f
						found_in_file = true
					end
					fixme = $2
					if fixme.length > 55
						fixme = fixme[0..51] + ' ...'
					end
						
					puts "  line #{i+1}: #{fixme}"
				end
			end
		end
	end
end

		
