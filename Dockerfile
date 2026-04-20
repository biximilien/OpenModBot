FROM ruby:3.3.11

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1
ARG BUNDLE_WITH=""
ENV BUNDLE_WITH=${BUNDLE_WITH}

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

CMD ["bundle", "exec", "ruby", "bot.rb"]
