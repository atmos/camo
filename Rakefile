namespace :test do
  desc "Run the tests against localhost"
  task :check do |t|
    system("ruby test/proxy_test.rb")
  end
end
task :default => "test:check"

Dir["tasks/*.rake"].each do |f|
  load f
end
