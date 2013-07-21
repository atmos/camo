file 'server.js' => 'server.coffee' do
  sh "coffee -c -o . server.coffee"
end
task :build => 'server.js'

task :bundle do
  system("bundle install --gemfile test.gemfile")
end

namespace :test do
  desc "Run the tests against localhost"
  task :check do |t|
    system("BUNDLE_GEMFILE=test.gemfile bundle exec ruby test/proxy_test.rb")
  end
end
task :default => [:build, :bundle, "test:check"]

Dir["tasks/*.rake"].each do |f|
  load f
end
