file 'server.js' => 'server.coffee' do
  sh "coffee -c -o . server.coffee"
end
task :build => 'server.js'

task :bundle do
  system("bundle install --gemfile test.gemfile")
end

desc "Run the tests against localhost"
task :test do
  system("BUNDLE_GEMFILE=test.gemfile bundle exec ruby test/proxy_test.rb")
end

task :default => [:build, :bundle, :test]

Dir["tasks/*.rake"].each do |f|
  load f
end
