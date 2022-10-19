
ruby_version = ask("Which ruby version are you using? This will add it to the .ruby-version file:")
run "echo \"#{ruby_version}\" > .ruby-version"
ruby_gemset = ask("Enter a gemset name for .ruby-gemset or just hit enter to skip creation of this file:")
if ruby_gemset
  run "echo \"#{ruby_gemset}\" > .ruby-gemset"
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

gem_group :development do
  # Auto-annotate files with schema and other info
  gem "annotate"
  # Easily preview ViewComponents
  gem "lookbook"
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
  if Rails.env.development?
    mount Lookbook::Engine, at: "/lookbook"
  end
EOS

# ViewComponents
create_file "app/components/.keep", ''
# ViewComponent previews for lookbook
create_file "spec/components/previews/.keep", ''
# A place for plain old Ruby objects
create_file "app/services/.keep", ''

# A layout for lookbook that loads tailwind for you, use it by adding `layout "view_component_preview"` to the preview controllers
create_file "app/views/layouts/view_component_preview.html.erb", <<-'EOS'
<!DOCTYPE html>
<html class="h-full bg-gray-100" style="<%= params[:lookbook][:display][:bg_color].present? ? "background-color:#{params[:lookbook][:display][:bg_color]}" : '' %>">
  <head>
    <meta name="viewport" content="width=device-width,initial-scale=1">

    <%= stylesheet_link_tag "inter-font" %>
    <%= stylesheet_link_tag "tailwind" %>
  </head>
  <body>
    <div class="p-12">
      <%= yield %>
    </div>
  </body>
</html>
EOS

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
# Use the sql schema for advanced postgres support
environment 'config.active_record.schema_format = :sql'

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

# Easily use Dry::Types in Dry::Structs
initializer 'types.rb', <<-CODE
module Types
  include Dry.Types()
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

  gsub_file "config/tailwind.config.js", /'\.\/app\/javascript\/\*\*\/\*\.js',/, <<-EOS
    './app/javascript/**/*.{js,ts}',
    './app/components/**/*.{rb,erb,haml,html,slim}',
    './spec/components/previews/**/*.{rb,html.erb}',
  EOS

  git :init
  git add: '.'
  git commit: "-a -m 'Initial commit'"
end