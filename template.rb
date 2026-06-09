
# Append this template's directory to the generator's source paths instead of
# replacing them, so Rails' own templates (e.g. kamal-secrets.tt) remain findable.
def source_paths
  Array(super) + [__dir__]
end

# ---------------------------------------------------------------------------
# Prompt helpers
# ---------------------------------------------------------------------------
# When +use_defaults+ is true every question is silently answered with the
# default value so the generator can run completely hands-free.

def yes_default?(question, default:, use_defaults: false)
  return default if use_defaults
  hint = default ? "Y/n" : "y/N"
  response = ask("#{question} [#{hint}]")
  return default if response.strip.empty?
  response.strip.downcase.start_with?("y")
end

def ask_default(question, default: "", use_defaults: false)
  return default if use_defaults
  response = ask("#{question} [#{default}]")
  response.strip.empty? ? default : response.strip
end

# ---------------------------------------------------------------------------
# Configuration mode
# ---------------------------------------------------------------------------

use_defaults = yes?("Use all defaults without prompting? (y/N)")

# ---------------------------------------------------------------------------
# Questions
# ---------------------------------------------------------------------------

create_file ".env"

use_react = yes_default?("Do you want to use React via Inertia.js? If no, the Rails standard of Hotwire will be used, with the addition of ViewComponents.", default: false, use_defaults: use_defaults)
use_importmaps = false

if use_react
  gem "inertia_rails"
  gem "vite_rails"
  create_file "Procfile.dev", "vite: bin/vite dev\nweb: bin/rails server\n"
else
  # View components for portions of views with more complex logic
  gem "view_component"
  gem_group :development do
    # Easily preview ViewComponents
    gem "lookbook"
    gem "hotwire-spark"
  end

  route <<-EOS
    if Rails.env.development?
      mount Lookbook::Engine, at: "/lookbook"
    end
  EOS

  # ViewComponents
  create_file "app/components/.keep", ''
  # A layout for lookbook that loads tailwind for you, use it by adding `layout "view_component_preview"` to the preview controllers
  use_importmaps = yes_default?("Are you using importmaps? (Select no if using esbuild or other, yes if you made no selection or specified importmaps)", default: true, use_defaults: use_defaults)
  if use_importmaps
    copy_file "templates/view_component_preview_importmaps.html.erb", "app/views/layouts/view_component_preview.html.erb"
  else
    copy_file "templates/view_component_preview_esbuild.html.erb", "app/views/layouts/view_component_preview.html.erb"
  end

  create_file "Procfile.dev", "css: bin/rails tailwindcss:watch\nweb: bin/rails server\n"
end

use_shadcn = false
unless use_react
  use_shadcn = yes_default?("Do you want to include shadcn-ui components? (https://github.com/jonathandean/shadcn-rails)", default: true, use_defaults: use_defaults)
  if use_shadcn
    gem "shadcn-ui", git: "https://github.com/jonathandean/shadcn-rails.git"
  end
end

lograge = yes_default?("Do you want to add and configure lograge to reduce Request logging to a single line in production?", default: true, use_defaults: use_defaults)
if lograge
  # Reduce Request logging to a single line in production
  gem "lograge"
end

sidekiq = yes_default?("Do you want to use Sidekiq and Redis for background jobs?", default: false, use_defaults: use_defaults)
if sidekiq
  # Background jobs
  gem 'sidekiq'
  use_mission_control = yes_default?("Do you want to use Mission Control Jobs for the job management UI? (If no, Sidekiq Web will be used instead)", default: true, use_defaults: use_defaults)
else
  # Solid Queue is the default; automatically include Mission Control Jobs
  use_mission_control = true
end
gem 'mission_control-jobs' if use_mission_control

# Clean config and type safe/validatable structs
gem 'dry-configurable'
gem 'dry-struct'
gem 'dry-validation'

if yes_default?("Do you want hashdiff to compare the differences between hashes and arrays?", default: false, use_defaults: use_defaults)
  # Compare hashes and arrays
  gem 'hashdiff'
end

# CLI
gem 'pastel' # styling strings for printing in the terminal
gem 'thor' # used by `bin/cli` and it's commands
gem 'tty-option' # presenting options in an interactive CLI
gem 'tty-progressbar'

add_auth0 = yes_default?("Do you want to include authentication via Auth0?", default: false, use_defaults: use_defaults)
if add_auth0
  gem 'omniauth-auth0'
  gem 'omniauth-rails_csrf_protection' # prevents forged authentication requests
end

gem_group :development do
  # Auto-annotate files with schema and other info
  gem "annotaterb"
end

rspec = yes_default?("Do you want to use RSpec instead of minitest?", default: false, use_defaults: use_defaults)

gem_group :development, :test do
  # Ease of setting environment variables locally
  gem "dotenv-rails"
  if rspec
    # rspec for unit tests
    gem "rspec-rails"
  end
  # Factories over fixtures for tests
  gem "factory_bot_rails"
  # Patch-level verification for bundler.
  # Rails 8.1+ ships bundler-audit in the default Gemfile, so only add it when missing.
  gem 'bundler-audit' unless File.exist?("Gemfile") && File.read("Gemfile").include?("bundler-audit")
end

previews_dir = rspec ? 'spec' : 'test'

unless use_react
  # ViewComponent previews for lookbook
  create_file "#{previews_dir}/components/previews/.keep", ''
  # Configure ViewComponent preview path (Lookbook reads from this).
  # Rails 8.1 / ViewComponent 4.x use `view_component.previews.paths`
  # (the legacy `preview_paths` accessor returns nil).
  # Escape \#{Rails.root} so it's interpolated when development.rb loads,
  # not at template-eval time.
  environment "config.view_component.previews.paths << \"\#{Rails.root}/#{previews_dir}/components/previews\"", env: 'development'
end

is_using_postgres = yes_default?("Are you using PostgreSQL as your database?", default: false, use_defaults: use_defaults)

if is_using_postgres && sidekiq
  # Use a version of `config/database.yml` with ENV var support built in for anyone who wants to override defaults locally
  template "templates/database-pg-sidekiq.yml.erb", "config/database.yml"
elsif is_using_postgres
  # TODO need another version of this for solid queue and env var support
  puts "Be sure to update your database.yml file"
end

add_ruby_native = yes_default?("Do you want to add Ruby Native for iOS and Android app support? (https://rubynative.com)", default: true, use_defaults: use_defaults)
if add_ruby_native
  gem "ruby_native"
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

# Create a runner for your tests by running `bin/ci` (ci standing for continuous integration).
# Rails 8.1+ ships its own bin/ci, so force-overwrite it with this template's version.
copy_file "templates/ci.rb", "bin/ci", force: true

if sidekiq
  # Configure sidekiq
  copy_file 'templates/sidekiq.rb', "config/initializers/sidekiq.rb"
  # Use sidekiq for background jobs
  environment 'config.active_job.queue_adapter = :sidekiq'

  unless use_mission_control
    # Sidekiq Web UI
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
end

if use_mission_control
  route <<-EOS
    namespace :admin do
      mount MissionControl::Jobs::Engine, at: "/jobs"
    end
  EOS
end

# A place for plain old Ruby objects
copy_file "templates/application_service.rb", 'app/services/application_service.rb'

if use_react
  environment <<-'EOS'
    config.autoload_paths += %W(
      #{config.root}/app/services
      #{config.root}/lib
    )
  EOS
else
  # Escape \#{config.root} so it remains literal in application.rb for
  # runtime interpolation; previews_dir is substituted now (template time).
  environment <<-EOS
    config.autoload_paths += %W(
      \#{config.root}/app/components
      \#{config.root}/#{previews_dir}/components/previews
      \#{config.root}/app/services
      \#{config.root}/lib
    )
  EOS
end

if lograge
  # Enable lograge in the production environment
  environment 'config.lograge.enabled = true', env: 'production'
end

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


# Easily use Dry::Types in Dry::Structs
initializer 'types.rb', <<-CODE
module Types
  include Dry.Types()
end
CODE

use_overmind = yes_default?("Do you want to use tmux enabled Overmind instead of Foreman for process management? *NIX only", default: true, use_defaults: use_defaults)
if use_overmind
  gem_group :development do
    gem "overmind"
  end
else
  gem_group :development do
    gem "foreman"
  end
end

after_bundle do
  # This needs to be first or all other run/generate commands will fail with "No such file or directory [...]config/vite.json"
  if use_react
    run "vite install"
    run "npm i vite-plugin-rails"
    generate "inertia:install --framework=react --typescript --vite --tailwind --no-interactive"
    # https://vite-ruby.netlify.app/guide/plugins.html#rails
    # https://github.com/ElMassimo/vite_ruby/tree/main/vite-plugin-rails
    gsub_file "vite.config.ts", "import RubyPlugin from 'vite-plugin-ruby'", "import ViteRails from 'vite-plugin-rails'"
    gsub_file "vite.config.ts", "RubyPlugin()", "ViteRails()"
  else
    run "bin/rails tailwindcss:install"

    if use_importmaps
      run "bin/rails importmap:install"
    end

    if use_shadcn
      generate "shadcn-ui accordion"
      generate "shadcn-ui alert"
      generate "shadcn-ui alert-dialog"
      generate "shadcn-ui badge"
      generate "shadcn-ui button"
      generate "shadcn-ui card"
      generate "shadcn-ui checkbox"
      generate "shadcn-ui collapsible"
      generate "shadcn-ui combobox"
      generate "shadcn-ui command"
      generate "shadcn-ui context-menu"
      generate "shadcn-ui dialog"
      generate "shadcn-ui dropdown-menu"
      generate "shadcn-ui dropzone"
      generate "shadcn-ui filter"
      generate "shadcn-ui forms"
      generate "shadcn-ui hover-card"
      generate "shadcn-ui input"
      generate "shadcn-ui label"
      generate "shadcn-ui menubar"
      generate "shadcn-ui navigation-menu"
      generate "shadcn-ui popover"
      generate "shadcn-ui progress"
      generate "shadcn-ui radio-group"
      generate "shadcn-ui scroll-area"
      generate "shadcn-ui select"
      generate "shadcn-ui separator"
      generate "shadcn-ui sheet"
      generate "shadcn-ui skeleton"
      generate "shadcn-ui slider"
      generate "shadcn-ui switch"
      generate "shadcn-ui table"
      generate "shadcn-ui tabs"
      generate "shadcn-ui textarea"
      generate "shadcn-ui toast"
      generate "shadcn-ui toggle"
      generate "shadcn-ui tooltip"
    end
  end

  if rspec
    # Setup rspec
    generate "rspec:install"
    insert_into_file "spec/rails_helper.rb", "\n    config.include FactoryBot::Syntax::Methods", after: "RSpec.configure do |config|"
  end

  # Setup annotate
  generate "annotate_rb:install"
  generate "annotate_rb:update_config"

  # Example pages
  generate "controller Home index"
  route "root to: 'home#index'"

  nav_markup = if use_react
 <<-EOS
    <!-- TailwindCSS is loaded in Inertia.js/React pages, but not here -->
    <nav style="margin: 2rem">
      <h2 style="font-weight: 600; font-size: 1.5rem">Navigation</h2>
      <ul style="margin-top: 1rem">
        <li><%= link_to('Inertia.js example', '/inertia-example', style: 'text-decoration: underline') %></li>
        <li><%= link_to('#{use_mission_control ? "Jobs" : "Sidekiq"}', '/admin/jobs', style: 'text-decoration: underline') %></li>
      </ul>
    </nav>
EOS
  else
 <<-EOS
    <nav class="p-8">
      <h2 class="font-semibold text-xl">Navigation</h2>
      <ul class="mt-4">
        <li><%= link_to("Lookbook (ViewComponent Previews)", "/lookbook") %></li>
        <li><%= link_to('#{use_mission_control ? "Jobs" : "Sidekiq"}', '/admin/jobs') %></li>
      </ul>
    </nav>
EOS
  end
    insert_into_file "app/views/home/index.html.erb", nav_markup, before: "</div>"

  unless use_react
    flash_markup = <<-EOS
  
      <% flash.each do |key, message| %>
        <div class="container mx-auto mt-8 px-5">
          <p><%= key %>: <%= message %></p>
        </div>
      <% end %>
EOS
    insert_into_file "app/views/layouts/application.html.erb", flash_markup, after: "<body>"
  end

  if is_using_postgres
    generate "migration enable_postgres_uuid_support"
    migration_filename = Dir['db/migrate/*_enable_postgres_uuid_support.rb'].first
    insert_into_file migration_filename, "\n    enable_extension 'pgcrypto'", after: "def change"
    insert_into_file "app/models/application_record.rb", "\n  self.implicit_order_column = :created_at", after: "primary_abstract_class"
  end

  if add_auth0
    auth0_client_id = ask_default("What is your Auth0 Client ID? (leave blank to add to .env later)", default: "", use_defaults: use_defaults)
    auth0_client_secret = ask_default("What is your Auth0 Client Secret? (leave blank to add to .env later)", default: "", use_defaults: use_defaults)
    auth0_domain = ask_default("What is your Auth0 Domain? (leave blank to add to .env later)", default: "", use_defaults: use_defaults)

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
    allow_guest_users = yes_default?("Do you want to support guest user accounts?", default: false, use_defaults: use_defaults)
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
      <%= button_to 'Logout', '/auth/logout', method: :get, variant: :default, turbo: false %>
    </p>
  <% else %>
    <p class="pt-6">
      <%= button_to 'Login', '/auth/auth0', method: :post, variant: :primary, turbo: false %>
    </p>
  <% end %>

    EOS
    insert_into_file "app/views/home/index.html.erb", template_login_button_code, after: "<p>Find me in app/views/home/index.html.erb</p>"
    user_link_code = <<-EOS

  <li><%= link_to "User Info", "/user/show" %></li>
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
    <%= link_to "Back", "/" %>
  </nav>
    EOS
    insert_into_file "app/views/user/show.html.erb", user_info_code, after: "<p>Find me in app/views/user/show.html.erb</p>"
  end

  if add_ruby_native
    generate "ruby_native:install"

    if use_react
      run "npm install @ruby-native/react"
      insert_into_file "app/controllers/application_controller.rb",
        "\n  include RubyNative::InertiaSupport",
        after: "ActionController::Base"
    end

    # Build tabs config customized to the demo pages
    ruby_native_yml = "appearance:\n  theme: auto\n  tint_color: \"#007AFF\"\n\n"
    ruby_native_yml += "tabs:\n"
    ruby_native_yml += "  - title: Home\n    path: /\n    icon: house\n"
    if use_react
      ruby_native_yml += "  - title: Example\n    path: /inertia-example\n    icon: sparkles\n"
    end
    if add_auth0
      ruby_native_yml += "  - title: Profile\n    path: /user/show\n    icon: person\n"
    end
    create_file "config/ruby_native.yml", ruby_native_yml, force: true

    # Layout: add viewport-fit=cover for safe area CSS variables
    gsub_file "app/views/layouts/application.html.erb",
      "width=device-width,initial-scale=1",
      "width=device-width,initial-scale=1,viewport-fit=cover"

    # Layout: add Ruby Native stylesheet
    insert_into_file "app/views/layouts/application.html.erb",
      "\n    <%= stylesheet_link_tag :ruby_native %>",
      after: "<%= csp_meta_tag %>"

    # Layout: add native tab bar
    insert_into_file "app/views/layouts/application.html.erb",
      "    <%= native_tabs_tag %>\n",
      before: "  </body>"

    unless use_react
      # Hotwire: add native-inset class to the main content wrapper for safe area spacing
      gsub_file "app/views/layouts/application.html.erb",
        '<main class="',
        '<main class="native-inset '
    end

    # Home page: add native navbar and conditionally hide web heading
    ruby_native_heading = <<~ERB
      <%= native_navbar_tag("Home") %>
      <% unless native_app? %>
      <h1>Home#index</h1>
      <% end %>
    ERB
    gsub_file "app/views/home/index.html.erb",
      "<h1>Home#index</h1>",
      ruby_native_heading.strip
  end

  git :init

  if yes_default?("Should we commit your empty app to git?", default: true, use_defaults: use_defaults)
    git add: '.'
    git commit: "-a -m 'Initial commit'"
  end

  jobs_ui_name = use_mission_control ? "Mission Control Jobs" : "Sidekiq Web"
  puts ""
  puts "WARNING: add authorization checks to `config/routes.rb` for the #{jobs_ui_name} UI at /admin/jobs or remove it from the production environment."
  puts ""
  puts "Next steps:"
  if is_using_postgres
    puts "cd #{app_name}"
    puts "createuser #{app_name} -s -d -P -r -h localhost -p 5432"
    puts "  (if your database host or port is different you will need to adjust the above)"
    puts "  (if you are using Postgres.app on Mac you may need a fully qualified path if you've not added the bin dir to your path, "
    puts"     such as: `/Applications/Postgres.app/Contents/Versions/17/bin/createuser #{app_name} -s -d -P -r -h localhost -p 5432`)"
  end

  if use_overmind
    run "bundle binstubs overmind"
    create_file "bin/dev", <<~SH, force: true
      #!/usr/bin/env sh

      bin/overmind start -f Procfile.dev
    SH
  else
    create_file "bin/dev", <<~SH, force: true
      #!/usr/bin/env sh

      bundle exec foreman start -f Procfile.dev
    SH
  end
  run "chmod +x bin/dev"

  puts "Setup and run dev environment:"
  puts "bin/setup"
end
