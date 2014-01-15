file 'server.js' => 'server.coffee' do
  sh "coffee -c -o . server.coffee"
end
task :build => 'server.js'

task :bundle do
  system("bundle install --gemfile test.gemfile")
end

namespace :test do
  desc "Start test server"
  task :server do |t|
    $SERVER_PID = Process.spawn("ruby test/proxy_test_server.rb")
  end

  desc "Run the tests against localhost"
  task :check do |t|
    system("BUNDLE_GEMFILE=test.gemfile bundle exec ruby test/proxy_test.rb")
  end

  desc "Kill test server"
  task :kill_server do |t|
    Process.kill(:QUIT, $SERVER_PID) && Process.wait
  end
end

task :default => [:build, :bundle, "test:server", "test:check", "test:kill_server"]

Dir["tasks/*.rake"].each do |f|
  load f
end
