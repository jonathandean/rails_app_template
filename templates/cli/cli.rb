#!/usr/bin/env ruby

ENV["RAILS_ENV"] ||= "development"

APP_PATH = File.expand_path("../config/application", __dir__)
require_relative "../config/boot"
require_relative "../config/environment"

require "thor"

module App
  class Cli < Thor
    desc "environment", "Print details about the current environment"
    def environment
      puts "Hostname: #{Socket.gethostname}"
      puts "RAILS_ENV=#{ENV["RAILS_ENV"]}"
      puts "RUBYOPT=#{ENV["RUBYOPT"]}"
      puts "PWD=#{ENV["PWD"]}"
    end

    desc "example SUBCOMMAND", "Example commands"
    subcommand "example", ExampleSubcommand

    def self.exit_on_failure?
      true
    end
  end
end

App::Cli.start(ARGV)