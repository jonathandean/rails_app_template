
def source_paths
  [__dir__]
end

ruby_version = ask("Which ruby version are you using? This will add it to the .ruby-version file:")
run "echo \"#{ruby_version}\" > .ruby-version"
ruby_gemset = ask("Enter a gemset name for .ruby-gemset or just hit enter to skip creation of this file:")
if ruby_gemset
  run "echo \"#{ruby_gemset}\" > .ruby-gemset"
end

create_file ".env"

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

add_auth0 = yes?("Do you want to include authentication via Auth0?")
if add_auth0
  gem 'omniauth-auth0'
  gem 'omniauth-rails_csrf_protection' # prevents forged authentication requests
end

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

is_using_postgres = yes?("Are you using PostgreSQL as your database?")

if is_using_postgres
  # Use a version of `config/database.yml` with ENV var support built in for anyone who wants to override defaults locally
  template "templates/database.yml.erb", "config/database.yml"
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
copy_file 'templates/routes.rake', "lib/tasks/routes.rake"

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

# Example ViewComponents
copy_file "templates/link_component.rb", "app/components/link_component.rb"
copy_file "templates/link_component.html.erb", "app/components/link_component.html.erb"
copy_file "templates/link_component_preview.rb", "spec/components/previews/link_component_preview.rb"
copy_file "templates/button_component.rb", "app/components/button_component.rb"
copy_file "templates/button_component.html.erb", "app/components/button_component.html.erb"
copy_file "templates/button_component_preview.rb", "spec/components/previews/button_component_preview.rb"

# A place for plain old Ruby objects
copy_file "templates/application_service.rb", 'app/services/application_service.rb'

# A layout for lookbook that loads tailwind for you, use it by adding `layout "view_component_preview"` to the preview controllers
copy_file "templates/view_component_preview.html.erb", "app/views/layouts/view_component_preview.html.erb"

environment <<-'EOS'
    config.autoload_paths += %W(
      #{config.root}/app/components
      #{config.root}/spec/components/previews
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
environment 'config.view_component.preview_paths << "#{Rails.root}/spec/components/previews"', env: 'development'

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
    get '/auth/auth0/callback' => 'auth0#callback'
    get '/auth/failure' => 'auth0#failure'
    get '/auth/logout' => 'auth0#logout'
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
    migration_code = <<-EOS

      t.string :auth0_id, null: false
    EOS
    insert_into_file migration_filename, ", id: :uuid", after: "create_table :users"
    insert_into_file migration_filename, migration_code, before: "t.timestamps"

    # Example pages/controllers
    generate "controller User show"
    require_login_code = <<-EOS

  include RequireLogin
    EOS
    insert_into_file "app/controllers/user_controller.rb", require_login_code, after: "ApplicationController"
    template_login_button_code = <<-EOS

  <% if logged_in? %>
    <p class="pt-6">
      <%= button_to 'Logout', 'auth/logout', method: :get, data: { turbo: false }, class: "inline-block px-6 py-2.5 bg-gray-200 text-gray-700 font-medium text-base leading-tight uppercase rounded shadow-md hover:shadow-lg focus:shadow-lg focus:outline-none focus:ring-0 active:shadow-lg transition duration-150 ease-in-out" %>
    </p>
  <% else %>
    <p class="pt-6">
      <%= button_to 'Login', '/auth/auth0', method: :post, data: { turbo: false }, class: "inline-block px-6 py-2.5 bg-gray-200 text-gray-700 font-medium text-base leading-tight uppercase rounded shadow-md hover:shadow-lg focus:shadow-lg focus:outline-none focus:ring-0 active:shadow-lg transition duration-150 ease-in-out" %>
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
  puts"     such as: `/Applications/Postgres.app/Contents/Versions/14/bin/createuser #{app_name} -s -d -P -r -h localhost -p 5432`)"
  puts "bin/rake db:create"
  puts "bin/rake db:migrate"
  puts "overmind start -f Procfile.dev"
  puts "  (`brew install overmind` if you don't have it yet)"
  puts "  (or if you prefer the foreman gem: `bundle add foreman && bundle exec foreman start -f Procfile.dev`"
end