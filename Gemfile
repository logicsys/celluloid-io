source "https://rubygems.org"

gemspec

gem 'celluloid',    github: 'logicsys/celluloid',    branch: 'develop'


group :development do
  gem "pry"
end

group :test do
  gem "rspec",       "~> 3",   require: false
  gem "rspec-retry", "~> 0.5", require: false
  gem "simplecov",             require: false
  gem "benchmark-ips",         require: false
end

group :development, :test do
  gem "rake"
end
