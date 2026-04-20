# frozen_string_literal: true

source "https://rubygems.org"

ruby "3.3.11"

# discord api for ruby
gem "discordrb"

# load environment variables from .env file
gem 'dotenv'

# redis is used as backend
gem "redis"

# testing
gem "rspec", group: :test

# optional opentelemetry
group :telemetry, optional: true do
  gem 'opentelemetry-sdk'
  gem 'opentelemetry-exporter-otlp'
  gem 'opentelemetry-instrumentation-net_http'
  gem 'opentelemetry-instrumentation-redis'
end
