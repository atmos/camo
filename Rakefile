file 'server.js' => 'server.coffee' do
  sh "coffee -c -o . server.coffee"
end
task :build => 'server.js'

namespace :test do
  desc "Run the tests against localhost"
  task :check do |t|
    system("ruby test/proxy_test.rb")
  end
end
task :default => [:build, "test:check"]

Dir["tasks/*.rake"].each do |f|
  load f
end
