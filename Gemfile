# frozen_string_literal: true

source "https://rubygems.org"

ruby "3.3.11"

# discord api for ruby
gem "discordrb"

# load environment variables from .env file
gem "dotenv"

# optional redis database plugin
group :redis, optional: true do
  gem "redis"
end

# optional postgres database plugin
group :postgres, optional: true do
  gem "pg"
end

group :development, :test do
  gem "rspec"
  gem "rubocop", require: false
  gem "rubocop-rspec", require: false
end

# optional opentelemetry
group :telemetry, optional: true do
  gem "opentelemetry-exporter-otlp"
  gem "opentelemetry-instrumentation-net_http"
  gem "opentelemetry-instrumentation-redis"
  gem "opentelemetry-sdk"
end
