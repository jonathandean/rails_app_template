
ruby_version = ask("Which ruby version are you using? This will add it to the .ruby-version file:")
run "echo \"#{ruby_version}\" > .ruby-version"
ruby_gemset = ask("Enter a gemset name for .ruby-gemset or just hit enter to skip creation of this file:")
if ruby_gemset
  run "echo \"#{ruby_gemset}\" > .ruby-gemset"
end

gem_group :development do
  # Auto-annotate files with schema and other info
  gem "annotate"
end

gem_group :development, :test do
  # Ease of setting environment variables locally
  gem "dotenv-rails"
  # rspec for unit tests
  gem "rspec-rails"
  # Factories over fixtures for tests
  gem "factory_bot_rails"
  # Patch-level verification for bundler
  gem 'bundler-audit'
end

# View components for portions of views with more complex logic
gem "view_component"
# Reduce Request logging to a single line in production
gem "lograge"

# JSON performance
gem 'multi_json'
gem 'oj'

# Backgroud jobs
gem 'sidekiq'

# Clean config and type safe/validatable structs
gem 'dry-configurable'
gem 'dry-struct'
gem 'dry-validation'

# Compare hashes and arrays
gem 'hashdiff'

# CLI
gem 'pastel' # styling strings for printing in the terminal
gem 'thor' # used by `bin/cli` and it's commands
gem 'tty-option' # presenting options in an interactive CLI
gem 'tty-progressbar'

# Static security analysis
gem 'brakeman'

# Do not commit local env var files to version control as they may have sensitive credentials or dev-only config
append_to_file ".gitignore", <<-EOS

# Local-only environment variables
.env
.env.*
EOS

create_file "app/cli/example_subcommand.rb", <<-'EOS'
class ExampleSubcommand < Thor
  desc "example", "Show an example command"
  long_desc <<~LONGDESC
    Show an example command
        
    Pass --verbose to print detailed information as the command runs.
  LONGDESC
  option :verbose, type: :boolean, default: false
  def example
    verbose = options[:verbose]
    puts "Hello, world!#{verbose ? ' Verbose version.': ''}"
  end
end
EOS

create_file "bin/cli", <<-'EOS'
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
EOS

create_file "bin/ci", <<-'EOS'
#!/usr/bin/env ruby

# Usage: bin/ci [options]
#
# --no-[STEP]  Exclude the specified step
# --only STEP  Run only the specified step
#
# Examples:
#
#   bin/ci --no-brakeman
#   bin/ci --only rspec

require "open3"
require "optparse"

# Define steps.
# NOTE: The order here determines the order they are performed.
STEPS = {
  "bundle-audit" => "bundle audit check --update",
  "brakeman" => "bundle exec brakeman",
  "rspec" => "bundle exec rspec"
}

def perform_step(name, cmd)
  Open3.popen3(cmd) do |stdin, stdout, stderr, thread|
    { STDOUT => stdout, STDERR => stderr }.each do |output, input|
      Thread.new do
        last_char = nil
        while char = input.getc do
          if last_char.nil? || last_char == "\n"
            output.print "[#{name}] "
          end
          output.print char
          last_char = char
        end
      end
    end

    thread.join

    status = thread.value
    unless status.success?
      exit status.exitstatus
    end
  end
end

options = { steps: STEPS.keys }

OptionParser.new do |parser|
  parser.on("--only=ONLY") do |only|
    options[:steps] = only.split(",")
  end

  STEPS.keys.each do |step|
    parser.on("--no-#{step}") do
      options[:steps].delete(step)
    end
  end
end.parse!

options[:steps].each do |step|
  perform_step step, STEPS[step]
end
EOS

prepend_to_file "config/routes.rb", <<-EOS
require 'sidekiq/web'
EOS

route <<-EOS
  namespace :admin do
    mount Sidekiq::Web => '/jobs', constraints: lambda {|request|
      # TODO authorize this
      true
    }
  end
EOS

create_file "app/components/.keep", ''
create_file "app/services/.keep", ''

environment <<-'EOS'
    config.autoload_paths += %W(
      #{config.root}/app/components
      #{config.root}/app/services
      #{config.root}/lib
    )
EOS

# Enable lograge in the production environment
environment 'config.lograge.enabled = true', env: 'production'
# Use sidekiq for background jobs
environment 'config.active_job.queue_adapter = :sidekiq'

initializer 'sidekiq.rb', <<-CODE
Sidekiq.default_worker_options = { 'backtrace' => true }

Sidekiq.configure_server do |config|
  config.redis = {
    ssl_params: {
      # https://stackoverflow.com/questions/65834575/how-to-enable-tls-for-redis-6-on-sidekiq
      verify_mode: OpenSSL::SSL::VERIFY_NONE,
      url: ENV.fetch('REDIS_URL', 'redis://127.0.0.1:6379/0')
    }
  }
end

Sidekiq.configure_client do |config|
  config.redis = {
    ssl_params: {
      # https://stackoverflow.com/questions/65834575/how-to-enable-tls-for-redis-6-on-sidekiq
      verify_mode: OpenSSL::SSL::VERIFY_NONE,
      url: ENV.fetch('REDIS_URL', 'redis://127.0.0.1:6379/0')
    }
  }
end
CODE

after_bundle do
  # Setup rspec
  generate "rspec:install"
  # Setup annotate
  generate "annotate:install"
  # Enable route and model annotation
  gsub_file "lib/tasks/auto_annotate_models.rake", /'models'(\s*)=>(\s*)'false'/, "'models'                      => 'true'"
  gsub_file "lib/tasks/auto_annotate_models.rake", /'routes'(\s*)=>(\s*)'false'/, "'routes'                      => 'true'"

  git :init
  git add: '.'
  git commit: "-a -m 'Initial commit'"
end