# Gpt4all

[![Gem Version](https://badge.fury.io/rb/gpt4all.svg)](https://badge.fury.io/rb/gpt4all)
[![CI](https://github.com/jaigouk/gpt4all/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/jaigouk/gpt4all/actions/workflows/main.yml)

Gpt4all is a Ruby gem that provides an easy-to-use interface for interacting with the [GPT4ALL](https://github.com/nomic-ai/gpt4all-ts) conversational AI model.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'gpt4all'
```

And then execute:

```bash
$ bundle install
```
Or install it yourself as:

```bash
$ gem install gpt4all
```

## Usage

To use the Gpt4all gem, you can follow these steps:

```ruby
require 'gpt4all'

gpt4all = Gpt4all::ConversationalAI.new
gpt4all.prepare_resources(force_download: true)
gpt4all.start_bot

response = gpt4all.prompt('What is your name?')
puts response

gpt4all.stop_bot
```

## Development

After checking out the repo, run bin/setup to install dependencies. Then, run rake spec to run the tests. You can also run bin/console for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run bundle exec rake install. To release a new version, update the version number in version.rb, and then run bundle exec rake release, which will create a git tag for the version, push git commits and tags, and push the .gem file to rubygems.org.
