
def source_paths
  [__dir__]
end

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

# Create a command line interface runner for thor so you can run it as `bin/cli subcommand`
copy_file "templates/cli/cli.rb", "bin/cli"
copy_file "templates/cli/example_subcommand.rb", "app/cli/example_subcommand.rb"

# Create a runner for your tests by running `bin/ci` (ci standing for continuous integration)
copy_file "templates/ci.rb", "bin/ci"

# Configure sidekiq and sidekiq web UI
copy_file 'templates/sidekiq.rb', "config/initializers/sidekiq.rb"

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
copy_file "templates/view_component_preview.html.erb", "app/views/layouts/view_component_preview.html.erb"

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

  if yes?("Should we commit your empty app to git?")
    git add: '.'
    git commit: "-a -m 'Initial commit'"
  end

  puts ""
  puts "WARNING: add authorization checks to `config/routes.rb` for the sidekiq web UI at /jobs or remove it from the production environment."
end