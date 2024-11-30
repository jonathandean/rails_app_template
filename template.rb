
def source_paths
  [__dir__]
end

ruby_version = ask("Which ruby version are you using? This will add it to the .ruby-version file:")
run "echo \"#{ruby_version}\" > .ruby-version"
ruby_gemset = ask("Enter a gemset name for .ruby-gemset - or hit enter to skip creation of this file if you aren't using RVM, don't want it, or aren't sure:")
if ruby_gemset
  run "echo \"#{ruby_gemset}\" > .ruby-gemset"
end

create_file ".env"

# View components for portions of views with more complex logic
gem "view_component"

lograge = yes?("Do you want to add and configure lograge to reduce Request logging to a single line in production?")
if lograge
  # Reduce Request logging to a single line in production
  gem "lograge"
end

sidekiq = yes?("Do you want to use Sidekiq and Redis for background jobs?")
if sidekiq
  # Backgroud jobs
  gem 'sidekiq'
end

# Clean config and type safe/validatable structs
gem 'dry-configurable'
gem 'dry-struct'
gem 'dry-validation'

if yes?("Do you want hashdiff to compare the differences between hashes and arrays?")
  # Compare hashes and arrays
  gem 'hashdiff'
end

# CLI
gem 'pastel' # styling strings for printing in the terminal
gem 'thor' # used by `bin/cli` and it's commands
gem 'tty-option' # presenting options in an interactive CLI
gem 'tty-progressbar'

add_auth0 = yes?("Do you want to include authentication via Auth0?")
if add_auth0
  gem 'omniauth-auth0'
  gem 'omniauth-rails_csrf_protection' # prevents forged authentication requests
end

gem_group :development do
  # Auto-annotate files with schema and other info
  gem "annotaterb"
  # Easily preview ViewComponents
  gem "lookbook"
end

rspec = yes?("Do you want to use RSpec instead of minitest?")

gem_group :development, :test do
  # Ease of setting environment variables locally
  gem "dotenv-rails"
  if rspec
    # rspec for unit tests
    gem "rspec-rails"
  end
  # Factories over fixtures for tests
  gem "factory_bot_rails"
  # Patch-level verification for bundler
  gem 'bundler-audit'
end

is_using_postgres = yes?("Are you using PostgreSQL as your database?")

if is_using_postgres
  # Use a version of `config/database.yml` with ENV var support built in for anyone who wants to override defaults locally
  template "templates/database.yml.erb", "config/database.yml"
end

# Do not commit local env var files to version control as they may have sensitive credentials or dev-only config
append_to_file ".gitignore", <<-EOS

# Local-only environment variables
# See https://github.com/bkeepers/dotenv#should-i-commit-my-env-file
.env.development.local
.env.test.local
.env.production.local
.env.local
EOS

# Create a command line interface runner for thor so you can run it as `bin/cli subcommand`
copy_file "templates/cli/cli.rb", "bin/cli"
copy_file "templates/cli/example_subcommand.rb", "app/cli/example_subcommand.rb"

# Create a runner for your tests by running `bin/ci` (ci standing for continuous integration)
copy_file "templates/ci.rb", "bin/ci"

if sidekiq
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
  EOS
end

route <<-EOS
  if Rails.env.development?
    mount Lookbook::Engine, at: "/lookbook"
  end
EOS

# ViewComponents
create_file "app/components/.keep", ''
# ViewComponent previews for lookbook
create_file "spec/components/previews/.keep", ''

# A place for plain old Ruby objects
copy_file "templates/application_service.rb", 'app/services/application_service.rb'

# A layout for lookbook that loads tailwind for you, use it by adding `layout "view_component_preview"` to the preview controllers
if yes?("Are you using importmaps? (Select no if using esbuild or other, yes if you made no selection or specified importmaps)")
  copy_file "templates/view_component_preview_importmaps.html.erb", "app/views/layouts/view_component_preview.html.erb"
else
  copy_file "templates/view_component_preview_esbuild.html.erb", "app/views/layouts/view_component_preview.html.erb"
end

environment <<-'EOS'
    config.autoload_paths += %W(
      #{config.root}/app/components
      #{config.root}/spec/components/previews
      #{config.root}/app/services
      #{config.root}/lib
    )
EOS

if lograge
  # Enable lograge in the production environment
  environment 'config.lograge.enabled = true', env: 'production'
end

# Use sidekiq for background jobs
environment 'config.active_job.queue_adapter = :sidekiq'
if is_using_postgres
  # Use the sql schema for advanced postgres support
  environment 'config.active_record.schema_format = :sql'
  # Use UUIDs for primary keys in postgres
  environment <<-'EOS'
      config.generators do |g|
        g.orm :active_record, primary_key_type: :uuid
      end
  EOS
end
# Configure lookbook preview path
environment 'config.view_component.preview_paths << "#{Rails.root}/spec/components/previews"', env: 'development'


# Easily use Dry::Types in Dry::Structs
initializer 'types.rb', <<-CODE
module Types
  include Dry.Types()
end
CODE

after_bundle do
  if rspec
    # Setup rspec
    generate "rspec:install"
    insert_into_file "spec/rails_helper.rb", "\n    config.include FactoryBot::Syntax::Methods", after: "RSpec.configure do |config|"
  end

  # Setup annotate
  run "bin/rails g annotate_rb:install"
  run "bin/rails g annotate_rb:update_config"

  gsub_file "config/tailwind.config.js", /'\.\/app\/javascript\/\*\*\/\*\.js',/, <<-EOS
    './app/javascript/**/*.{js,ts}',
    './app/components/**/*.{rb,erb,haml,html,slim}',
    './spec/components/previews/**/*.{rb,html.erb}',
  EOS

  # Example pages
  generate "controller Home index"
  route "root to: 'home#index'"

  nav_markup = <<-EOS

  <nav class="mt-8">
    <h2 class="font-semibold text-xl">Navigation</h2>
    <ul>
      <li><%= render LinkComponent.new(url: '/lookbook').with_content("Lookbook (ViewComponent Previews)") %></li>
      <li><%= render LinkComponent.new(url: '/admin/jobs').with_content("Sidekiq") %></li>
    </ul>
  </nav>
EOS
  insert_into_file "app/views/home/index.html.erb", nav_markup, before: "</div>"

  flash_markup = <<-EOS

    <% flash.each do |key, message| %>
      <div class="container mx-auto mt-8 px-5">
        <p><%= key %>: <%= message %></p>
      </div>
    <% end %>
EOS
  insert_into_file "app/views/layouts/application.html.erb", flash_markup, after: "<body>"

  if is_using_postgres
    generate "migration enable_postgres_uuid_support"
    migration_filename = Dir['db/migrate/*_enable_postgres_uuid_support.rb'].first
    insert_into_file migration_filename, "\n    enable_extension 'pgcrypto'", after: "def change"
    insert_into_file "app/models/application_record.rb", "\n  self.implicit_order_column = :created_at", after: "primary_abstract_class"
  end

  if add_auth0
    auth0_client_id = ask("What is your Auth0 Client ID? (or you can manually add to .env later)")
    auth0_client_secret = ask("What is your Auth0 Client Secret? (or you can manually add to .env later)")
    auth0_domain = ask("What is your Auth0 Domain? (or you can manually add to .env later)")

    append_to_file ".env", <<-EOS
AUTH0_CLIENT_ID="#{auth0_client_id}"
AUTH0_CLIENT_SECRET="#{auth0_client_secret}"
AUTH0_DOMAIN="#{auth0_domain}"
    EOS

    copy_file 'templates/auth0.rb', "config/initializers/auth0.rb"
    route <<-EOS
    get '/auth/auth0/callback', to: 'auth0#callback'
    get '/auth/failure', to: 'auth0#failure'
    get '/auth/logout', to: 'auth0#logout'
    EOS
    copy_file "templates/auth0_controller.rb", "app/controllers/auth0_controller.rb"
    copy_file "templates/require_login.rb", "app/controllers/concerns/require_login.rb"
    application_controller_code = <<-EOS

  helper_method :current_user, :current_user_info, :logged_in?

  protected

  def logged_in?
    current_user.present?
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def current_user_info
    @current_user_info ||= OpenStruct.new session[:user_info]
  end
    EOS
    insert_into_file "app/controllers/application_controller.rb", application_controller_code, after: "ActionController::Base"


    generate "model User"
    migration_filename = Dir['db/migrate/*_create_users.rb'].first
    allow_guest_users = yes?("Do you want to support guest user accounts?")
    migration_code = <<-EOS

      t.string :auth0_id, null: #{allow_guest_users ? 'true': 'false'}
    EOS
    insert_into_file migration_filename, ", id: :uuid", after: "create_table :users"
    insert_into_file migration_filename, migration_code, before: "t.timestamps"
    if allow_guest_users
      guest_method = <<-EOS

  def guest?
    auth0_id.blank?
  end
EOS
      insert_into_file "app/models/user.rb", guest_method, after: "ApplicationRecord"

      guest_login_method = <<-EOS


  def guest_login
    user = User.create!
    session[:user_id] = user.id

    flash.notice = "You are now logged in as a guest! If you log out or change devices all data will be lost"
    redirect_to root_path
  end

EOS
      insert_into_file "app/controllers/auth0_controller.rb", guest_login_method, before: "def failure"
      route "post '/auth/guest_login' => 'auth0#guest_login', as: 'guest_login'"
    end

    # Example pages/controllers
    generate "controller User show"
    require_login_code = <<-EOS

  include RequireLogin
    EOS
    insert_into_file "app/controllers/user_controller.rb", require_login_code, after: "ApplicationController"
    template_login_button_code = <<-EOS

  <% if logged_in? %>
    <p class="pt-6">
      <%= render ButtonToComponent.new 'Logout', '/auth/logout', method: :get, variant: :default, turbo: false %>
    </p>
  <% else %>
    <p class="pt-6">
      <%= render ButtonToComponent.new 'Login', '/auth/auth0', method: :post, variant: :primary, turbo: false %>
    </p>
  <% end %>

    EOS
    insert_into_file "app/views/home/index.html.erb", template_login_button_code, after: "<p>Find me in app/views/home/index.html.erb</p>"
    user_link_code = <<-EOS

  <li><%= render LinkComponent.new(url: '/user/show').with_content("User Info") %></li>
    EOS
    insert_into_file "app/views/home/index.html.erb", user_link_code, after: "<ul>"
    user_info_code = <<-EOS

  <div class="mt-8">
    <h2 class="font-semibold text-xl">User Info</h2>
    <dl>
      <% current_user_info.each_pair.each do |key, value| %>
        <dt class="font-semibold"><%= key %></dt>
        <dd><%= value %></dd>
      <% end %>
    </dl>
  </div>
  <nav class="mt-8">
    <%= render LinkComponent.new(url: '/').with_content("Back") %>
  </nav>
    EOS
    insert_into_file "app/views/user/show.html.erb", user_info_code, after: "<p>Find me in app/views/user/show.html.erb</p>"
  end

  git :init

  if yes?("Should we commit your empty app to git?")
    git add: '.'
    git commit: "-a -m 'Initial commit'"
  end

  puts ""
  puts "WARNING: add authorization checks to `config/routes.rb` for the sidekiq web UI at /jobs or remove it from the production environment."
  puts ""
  puts "Next steps:"
  puts "cd #{app_name}"
  puts "createuser #{app_name} -s -d -P -r -h localhost -p 5432"
  puts "  (if your database host or port is different you will need to adjust the above)"
  puts "  (if you are using Postgres.app you may need a fully qualified path if you've not added the bin dir to your path, "
  puts"     such as: `/Applications/Postgres.app/Contents/Versions/15/bin/createuser #{app_name} -s -d -P -r -h localhost -p 5432`)"
  puts "bin/rake db:create"
  puts "bin/rake db:migrate"
  puts "overmind start -f Procfile.dev"
  puts "  (`brew install overmind` if you don't have it yet)"
  puts "  (or if you prefer the foreman gem: `bundle add foreman && bundle exec foreman start -f Procfile.dev`"
end