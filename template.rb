
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

# Do not commit local env var files to version control as they may have sensitive credentials or dev-only config
append_to_file ".gitignore", <<-EOS

# Local-only environment variables
.env
.env.*
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