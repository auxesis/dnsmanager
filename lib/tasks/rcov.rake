begin
	require 'rcov/rcovtask'
rescue LoadError
	puts "You do not have a newish version of rcov installed."
	puts "Coverage tests won't work for you."
end

namespace :test do 
	namespace :coverage do
		desc "Delete aggregate coverage data."
		task(:clean) { rm_f "test/coverage/aggregate" }
	end

	desc 'Aggregate code coverage for unit, functional and integration tests'
	task :coverage => "test:coverage:clean"
	begin
		%w[unit functional integration].each do |target|
			namespace :coverage do
				unless FileList["test/#{target}/**/*_test.rb"].empty?
					Rcov::RcovTask.new(target + 's') do |t|
						t.libs << "test"
						t.test_files = FileList["test/#{target}/**/*_test.rb"]
						t.output_dir = "test/coverage/#{target}"
						t.verbose = true
						t.rcov_opts << '--rails --aggregate test/coverage/aggregate'
						t.rcov_opts << '--exclude \'\A/usr/local/lib\''
					end
				end
			end
			task :coverage => "test:coverage:#{target}s" unless FileList["test/#{target}/**/*_test.rb"].empty?
		end
	rescue NameError
		# Don't care
	end
end
