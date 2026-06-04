RSpec.describe "template.rb" do
  let(:template_path) { File.expand_path("../template.rb", __dir__) }

  # Base answers: everything declined except the minimum needed to avoid
  # prompts that are only reached conditionally.
  let(:base_answers) do
    {
      react: false,
      importmaps: true,
      lograge: false,
      sidekiq: false,
      hashdiff: false,
      auth0: false,
      rspec: false,
      postgres: false,
      git_commit: false,
    }
  end

  def run_template(overrides = {})
    answers = base_answers.merge(overrides)
    harness = TemplateHarness.new(answers)
    harness.apply(template_path)
    harness
  end

  # ---------------------------------------------------------------------------
  # Gems that are always added regardless of options
  # ---------------------------------------------------------------------------
  describe "unconditional gems" do
    subject(:h) { run_template }

    %w[dry-configurable dry-struct dry-validation pastel thor tty-option tty-progressbar annotaterb dotenv-rails factory_bot_rails bundler-audit].each do |gem_name|
      it "adds #{gem_name}" do
        expect(h).to have_gem(gem_name)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Unconditional file operations
  # ---------------------------------------------------------------------------
  describe "unconditional files and setup" do
    subject(:h) { run_template }

    it "creates .env" do
      expect(h.has_created_file?(".env")).to be true
    end

    it "copies bin/cli" do
      expect(h.has_copied_file?("bin/cli")).to be true
    end

    it "copies app/cli/example_subcommand.rb" do
      expect(h.has_copied_file?("app/cli/example_subcommand.rb")).to be true
    end

    it "copies bin/ci" do
      expect(h.has_copied_file?("bin/ci")).to be true
    end

    it "copies application_service.rb" do
      expect(h.has_copied_file?("app/services/application_service.rb")).to be true
    end

    it "creates the types.rb initializer" do
      expect(h.initializers).to include("types.rb")
    end

    it "appends local env files to .gitignore" do
      appended = h.appended_files.find { |a| a.args.first == ".gitignore" }
      expect(appended).not_to be_nil
      expect(appended.args[1]).to include(".env.development.local")
      expect(appended.args[1]).to include(".env.local")
    end

    it "generates annotate_rb:install and annotate_rb:update_config" do
      expect(h.has_generator?("annotate_rb:install")).to be true
      expect(h.has_generator?("annotate_rb:update_config")).to be true
    end

    it "generates the Home controller with index action" do
      expect(h.has_generator?("controller Home index")).to be true
    end

    it "adds root route" do
      expect(h.has_route?("root to:")).to be true
    end

    it "initializes git" do
      expect(h.git_commands.any? { |a| a.args.include?(:init) }).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # React / Inertia.js option
  # ---------------------------------------------------------------------------
  describe "React / Inertia.js option" do
    context "when React is selected" do
      subject(:h) { run_template(react: true) }

      it "adds inertia_rails gem" do
        expect(h).to have_gem("inertia_rails")
      end

      it "adds vite_rails gem" do
        expect(h).to have_gem("vite_rails")
      end

      it "does NOT add view_component gem" do
        expect(h).not_to have_gem("view_component")
      end

      it "does NOT add lookbook gem" do
        expect(h).not_to have_gem("lookbook")
      end

      it "runs vite install" do
        expect(h.has_command?("vite install")).to be true
      end

      it "runs npm install for vite-plugin-rails" do
        expect(h.has_command?("npm i vite-plugin-rails")).to be true
      end

      it "runs inertia:install generator" do
        expect(h.has_generator?("inertia:install")).to be true
      end

      it "gsubs vite.config.ts to use ViteRails" do
        gsubs = h.gsubbed_files
        expect(gsubs.any? { |a| a.args[1].include?("vite-plugin-ruby") }).to be true
        expect(gsubs.any? { |a| a.args[2].include?("vite-plugin-rails") }).to be true
      end

      it "adds autoload_paths without components/previews" do
        autoload_envs = h.environments.select { |a| a.args.first.to_s.include?("autoload_paths") }
        expect(autoload_envs).not_to be_empty
        code = autoload_envs.first.args.first
        expect(code).to include("app/services")
        expect(code).not_to include("app/components")
        expect(code).not_to include("spec/components/previews")
      end

      it "does not ask about importmaps" do
        # importmaps prompt only shown in Hotwire path
        expect { run_template(react: true) }.not_to raise_error
      end
    end

    context "when Hotwire is selected (React declined)" do
      subject(:h) { run_template(react: false, importmaps: true) }

      it "adds view_component gem" do
        expect(h).to have_gem("view_component")
      end

      it "adds lookbook gem in development group" do
        expect(h.gem_in_group?("lookbook", :development)).to be true
      end

      it "does NOT add inertia_rails gem" do
        expect(h).not_to have_gem("inertia_rails")
      end

      it "does NOT add vite_rails gem" do
        expect(h).not_to have_gem("vite_rails")
      end

      it "adds Lookbook engine route" do
        expect(h.has_route?("Lookbook::Engine")).to be true
      end

      it "creates app/components/.keep" do
        expect(h.has_created_file?("app/components/.keep")).to be true
      end

      it "creates spec/components/previews/.keep" do
        expect(h.has_created_file?("spec/components/previews/.keep")).to be true
      end

      it "configures view_component previews.paths in development" do
        # Rails 8.1 / ViewComponent 4.x use previews.paths (preview_paths returns nil)
        expect(h.has_environment?("view_component.previews.paths", env: "development")).to be true
      end

      it "adds autoload_paths including components and previews" do
        autoload_envs = h.environments.select { |a| a.args.first.to_s.include?("autoload_paths") }
        code = autoload_envs.first.args.first
        expect(code).to include("app/components")
        expect(code).to include("spec/components/previews")
        expect(code).to include("app/services")
      end

      it "inserts flash markup into application layout" do
        flash_inserts = h.inserted_files.select { |a| a.args.first.to_s.include?("application.html.erb") }
        expect(flash_inserts).not_to be_empty
        expect(flash_inserts.first.args[1]).to include("flash.each")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Importmaps sub-option (Hotwire path only)
  # ---------------------------------------------------------------------------
  describe "importmaps sub-option (Hotwire path)" do
    context "when using importmaps" do
      subject(:h) { run_template(react: false, importmaps: true) }

      it "copies importmaps layout template" do
        expect(h.has_copied_file?("app/views/layouts/view_component_preview.html.erb")).to be true
        src = h.copied_files.find { |f| f[:dest] == "app/views/layouts/view_component_preview.html.erb" }
        expect(src[:src]).to include("importmaps")
      end
    end

    context "when using esbuild (not importmaps)" do
      subject(:h) { run_template(react: false, importmaps: false) }

      it "copies esbuild layout template" do
        expect(h.has_copied_file?("app/views/layouts/view_component_preview.html.erb")).to be true
        src = h.copied_files.find { |f| f[:dest] == "app/views/layouts/view_component_preview.html.erb" }
        expect(src[:src]).to include("esbuild")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Lograge option
  # ---------------------------------------------------------------------------
  describe "lograge option" do
    context "when enabled" do
      subject(:h) { run_template(lograge: true) }

      it "adds lograge gem" do
        expect(h).to have_gem("lograge")
      end

      it "enables lograge in production environment" do
        expect(h.has_environment?("lograge.enabled = true", env: "production")).to be true
      end
    end

    context "when disabled" do
      subject(:h) { run_template(lograge: false) }

      it "does NOT add lograge gem" do
        expect(h).not_to have_gem("lograge")
      end

      it "does NOT configure lograge" do
        expect(h.has_environment?("lograge")).to be false
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Sidekiq option
  # ---------------------------------------------------------------------------
  describe "Sidekiq option" do
    context "when enabled" do
      subject(:h) { run_template(sidekiq: true) }

      it "adds sidekiq gem" do
        expect(h).to have_gem("sidekiq")
      end

      it "copies sidekiq initializer" do
        expect(h.has_copied_file?("config/initializers/sidekiq.rb")).to be true
      end

      it "prepends sidekiq/web require to routes" do
        prepended = h.actions_of(:prepend_to_file).find { |a| a.args.first == "config/routes.rb" }
        expect(prepended).not_to be_nil
        expect(prepended.args[1]).to include("sidekiq/web")
      end

      it "adds admin sidekiq route" do
        expect(h.has_route?("Sidekiq::Web")).to be true
      end

      it "sets active_job queue_adapter to sidekiq" do
        expect(h.has_environment?("queue_adapter = :sidekiq")).to be true
      end
    end

    context "when disabled" do
      subject(:h) { run_template(sidekiq: false) }

      it "does NOT add sidekiq gem" do
        expect(h).not_to have_gem("sidekiq")
      end

      it "does NOT configure sidekiq" do
        expect(h.has_environment?("queue_adapter = :sidekiq")).to be false
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Hashdiff option
  # ---------------------------------------------------------------------------
  describe "Hashdiff option" do
    context "when enabled" do
      subject(:h) { run_template(hashdiff: true) }

      it "adds hashdiff gem" do
        expect(h).to have_gem("hashdiff")
      end
    end

    context "when disabled" do
      subject(:h) { run_template(hashdiff: false) }

      it "does NOT add hashdiff gem" do
        expect(h).not_to have_gem("hashdiff")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # RSpec option
  # ---------------------------------------------------------------------------
  describe "RSpec option" do
    context "when enabled" do
      subject(:h) { run_template(rspec: true) }

      it "adds rspec-rails gem in development/test group" do
        expect(h.gem_in_group?("rspec-rails", :development, :test)).to be true
      end

      it "generates rspec:install" do
        expect(h.has_generator?("rspec:install")).to be true
      end

      it "inserts FactoryBot configuration into rails_helper" do
        fb_insert = h.inserted_files.find { |a| a.args.first.to_s.include?("rails_helper.rb") }
        expect(fb_insert).not_to be_nil
        expect(fb_insert.args[1]).to include("FactoryBot::Syntax::Methods")
      end
    end

    context "when disabled" do
      subject(:h) { run_template(rspec: false) }

      it "does NOT add rspec-rails gem" do
        expect(h).not_to have_gem("rspec-rails")
      end

      it "does NOT generate rspec:install" do
        expect(h.has_generator?("rspec:install")).to be false
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PostgreSQL option
  # ---------------------------------------------------------------------------
  describe "PostgreSQL option" do
    context "when enabled (without Sidekiq)" do
      subject(:h) { run_template(postgres: true, sidekiq: false) }

      it "sets schema_format to :sql" do
        expect(h.has_environment?("schema_format = :sql")).to be true
      end

      it "configures UUID primary keys via generators" do
        expect(h.has_environment?("primary_key_type: :uuid")).to be true
      end

      it "generates enable_postgres_uuid_support migration" do
        expect(h.has_generator?("migration enable_postgres_uuid_support")).to be true
      end

      it "inserts implicit_order_column into ApplicationRecord" do
        ar_insert = h.inserted_files.find { |a| a.args.first.to_s.include?("application_record.rb") }
        expect(ar_insert).not_to be_nil
        expect(ar_insert.args[1]).to include("implicit_order_column")
      end

      it "does NOT use the database-pg-sidekiq template" do
        expect(h.templated_files).to be_empty
      end
    end

    context "when enabled with Sidekiq" do
      subject(:h) { run_template(postgres: true, sidekiq: true) }

      it "uses the database-pg-sidekiq.yml.erb template for database.yml" do
        tmpl = h.templated_files.find { |f| f[:dest] == "config/database.yml" }
        expect(tmpl).not_to be_nil
        expect(tmpl[:src]).to include("database-pg-sidekiq.yml.erb")
      end
    end

    context "when disabled" do
      subject(:h) { run_template(postgres: false) }

      it "does NOT set schema_format to :sql" do
        expect(h.has_environment?("schema_format")).to be false
      end

      it "does NOT configure UUID primary keys" do
        expect(h.has_environment?("primary_key_type")).to be false
      end

      it "does NOT generate postgres migration" do
        expect(h.has_generator?("migration enable_postgres_uuid_support")).to be false
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Auth0 option
  # ---------------------------------------------------------------------------
  describe "Auth0 option" do
    let(:auth0_answers) do
      {
        auth0: true,
        auth0_client_id: "test-client-id",
        auth0_client_secret: "test-secret",
        auth0_domain: "test.auth0.com",
        guest: false,
      }
    end

    context "when enabled (without guest)" do
      subject(:h) { run_template(auth0_answers) }

      it "adds omniauth-auth0 gem" do
        expect(h).to have_gem("omniauth-auth0")
      end

      it "adds omniauth-rails_csrf_protection gem" do
        expect(h).to have_gem("omniauth-rails_csrf_protection")
      end

      it "appends Auth0 env vars to .env" do
        env_append = h.appended_files.find { |a| a.args.first == ".env" }
        expect(env_append).not_to be_nil
        expect(env_append.args[1]).to include("AUTH0_CLIENT_ID")
        expect(env_append.args[1]).to include("test-client-id")
      end

      it "copies auth0 initializer" do
        expect(h.has_copied_file?("config/initializers/auth0.rb")).to be true
      end

      it "copies auth0 controller" do
        expect(h.has_copied_file?("app/controllers/auth0_controller.rb")).to be true
      end

      it "copies require_login concern" do
        expect(h.has_copied_file?("app/controllers/concerns/require_login.rb")).to be true
      end

      it "adds auth0 callback/failure/logout routes" do
        expect(h.has_route?("auth0/callback")).to be true
        expect(h.has_route?("auth/failure")).to be true
        expect(h.has_route?("auth/logout")).to be true
      end

      it "inserts helper_method and current_user into ApplicationController" do
        ac_insert = h.inserted_files.find { |a| a.args.first.to_s.include?("application_controller.rb") }
        expect(ac_insert).not_to be_nil
        expect(ac_insert.args[1]).to include("current_user")
        expect(ac_insert.args[1]).to include("logged_in?")
      end

      it "generates User model" do
        expect(h.has_generator?("model User")).to be true
      end

      it "generates User controller" do
        expect(h.has_generator?("controller User show")).to be true
      end

      it "inserts RequireLogin into user controller" do
        rl_insert = h.inserted_files.find do |a|
          a.args.first.to_s.include?("user_controller.rb") &&
            a.args[1].to_s.include?("RequireLogin")
        end
        expect(rl_insert).not_to be_nil
      end

      it "does NOT add guest_login method when guest is declined" do
        guest_insert = h.inserted_files.find do |a|
          a.args[1].to_s.include?("guest_login")
        end
        expect(guest_insert).to be_nil
      end

      it "does NOT add guest_login route when guest is declined" do
        expect(h.has_route?("guest_login")).to be false
      end
    end

    context "when enabled with guest users" do
      subject(:h) { run_template(auth0_answers.merge(guest: true)) }

      it "inserts guest? method into User model" do
        guest_insert = h.inserted_files.find do |a|
          a.args.first.to_s.include?("app/models/user.rb") &&
            a.args[1].to_s.include?("guest?")
        end
        expect(guest_insert).not_to be_nil
      end

      it "inserts guest_login method into auth0 controller" do
        gl_insert = h.inserted_files.find do |a|
          a.args.first.to_s.include?("auth0_controller.rb") &&
            a.args[1].to_s.include?("guest_login")
        end
        expect(gl_insert).not_to be_nil
      end

      it "adds guest_login route" do
        expect(h.has_route?("guest_login")).to be true
      end

      it "sets auth0_id null: true in migration (allows null for guests)" do
        migration_inserts = h.inserted_files.select { |a| a.args[1].to_s.include?("auth0_id") }
        auth0_id_insert = migration_inserts.find { |a| a.args[1].include?("null: true") }
        expect(auth0_id_insert).not_to be_nil
      end
    end

    context "when enabled with guest users declined" do
      subject(:h) { run_template(auth0_answers.merge(guest: false)) }

      it "sets auth0_id null: false in migration (requires auth0_id)" do
        migration_inserts = h.inserted_files.select { |a| a.args[1].to_s.include?("auth0_id") }
        auth0_id_insert = migration_inserts.find { |a| a.args[1].include?("null: false") }
        expect(auth0_id_insert).not_to be_nil
      end
    end

    context "when disabled" do
      subject(:h) { run_template(auth0: false) }

      it "does NOT add omniauth gems" do
        expect(h).not_to have_gem("omniauth-auth0")
        expect(h).not_to have_gem("omniauth-rails_csrf_protection")
      end

      it "does NOT add auth0 routes" do
        expect(h.has_route?("auth0")).to be false
      end

      it "does NOT generate User model" do
        expect(h.has_generator?("model User")).to be false
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Git commit option
  # ---------------------------------------------------------------------------
  describe "git commit option" do
    context "when committing" do
      subject(:h) { run_template(git_commit: true) }

      it "stages and commits files" do
        expect(h.git_commands.any? { |a| a.args.any? { |arg| arg.is_a?(Hash) && arg[:add] } }).to be true
        expect(h.git_commands.any? { |a| a.args.any? { |arg| arg.is_a?(Hash) && arg[:commit] } }).to be true
      end
    end

    context "when declining commit" do
      subject(:h) { run_template(git_commit: false) }

      it "does NOT commit" do
        expect(h.git_commands.any? { |a| a.args.any? { |arg| arg.is_a?(Hash) && arg[:commit] } }).to be false
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Gem group assignments
  # ---------------------------------------------------------------------------
  describe "gem group assignments" do
    subject(:h) { run_template(rspec: true) }

    it "places annotaterb in development group" do
      expect(h.gem_in_group?("annotaterb", :development)).to be true
    end

    it "places dotenv-rails in development & test group" do
      expect(h.gem_in_group?("dotenv-rails", :development, :test)).to be true
    end

    it "places factory_bot_rails in development & test group" do
      expect(h.gem_in_group?("factory_bot_rails", :development, :test)).to be true
    end

    it "places bundler-audit in development & test group" do
      expect(h.gem_in_group?("bundler-audit", :development, :test)).to be true
    end

    it "places rspec-rails in development & test group when rspec enabled" do
      expect(h.gem_in_group?("rspec-rails", :development, :test)).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # bundler-audit duplicate guard (Rails 8.1 ships it by default)
  # ---------------------------------------------------------------------------
  describe "bundler-audit guard" do
    it "adds bundler-audit when the Gemfile does not already include it" do
      harness = TemplateHarness.new(base_answers)
      harness.apply(template_path, seed_files: { "Gemfile" => "source 'https://rubygems.org'\n" })
      expect(harness).to have_gem("bundler-audit")
    end

    it "does NOT add bundler-audit when the Gemfile already includes it" do
      harness = TemplateHarness.new(base_answers)
      harness.apply(template_path, seed_files: { "Gemfile" => "gem 'bundler-audit', require: false\n" })
      expect(harness.has_gem?("bundler-audit")).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # Full combination: React + Postgres + Sidekiq + Auth0 + Guest + RSpec
  # ---------------------------------------------------------------------------
  describe "full React stack combination" do
    subject(:h) do
      run_template(
        react: true,
        lograge: true,
        sidekiq: true,
        hashdiff: true,
        auth0: true,
        auth0_client_id: "cid",
        auth0_client_secret: "csecret",
        auth0_domain: "dom.auth0.com",
        guest: true,
        rspec: true,
        postgres: true,
        git_commit: false,
      )
    end

    it "includes all expected gems" do
      %w[inertia_rails vite_rails lograge sidekiq hashdiff omniauth-auth0 rspec-rails].each do |g|
        expect(h).to have_gem(g), "expected gem #{g} to be present"
      end
    end

    it "does NOT include Hotwire-only gems" do
      %w[view_component lookbook].each do |g|
        expect(h).not_to have_gem(g), "expected gem #{g} to be absent"
      end
    end

    it "uses the database-pg-sidekiq template" do
      expect(h.templated_files.any? { |f| f[:dest] == "config/database.yml" }).to be true
    end

    it "configures postgres UUIDs" do
      expect(h.has_environment?("primary_key_type: :uuid")).to be true
    end

    it "configures sidekiq queue adapter" do
      expect(h.has_environment?("queue_adapter = :sidekiq")).to be true
    end

    it "configures lograge in production" do
      expect(h.has_environment?("lograge.enabled = true", env: "production")).to be true
    end

    it "sets up auth0 with guest login" do
      expect(h.has_route?("guest_login")).to be true
    end

    it "generates rspec:install" do
      expect(h.has_generator?("rspec:install")).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # Full combination: Hotwire (esbuild) minimal
  # ---------------------------------------------------------------------------
  describe "minimal Hotwire stack (everything declined)" do
    subject(:h) do
      run_template(
        react: false,
        importmaps: false,
        lograge: false,
        sidekiq: false,
        hashdiff: false,
        auth0: false,
        rspec: false,
        postgres: false,
        git_commit: false,
      )
    end

    it "adds only unconditional + hotwire gems" do
      expect(h).to have_gem("view_component")
      expect(h).to have_gem("dry-struct")
      expect(h).not_to have_gem("lograge")
      expect(h).not_to have_gem("sidekiq")
      expect(h).not_to have_gem("hashdiff")
      expect(h).not_to have_gem("omniauth-auth0")
      expect(h).not_to have_gem("rspec-rails")
      expect(h).not_to have_gem("inertia_rails")
    end

    it "copies esbuild preview layout" do
      src = h.copied_files.find { |f| f[:dest] == "app/views/layouts/view_component_preview.html.erb" }
      expect(src[:src]).to include("esbuild")
    end

    it "does not generate rspec:install or User model" do
      expect(h.has_generator?("rspec:install")).to be false
      expect(h.has_generator?("model User")).to be false
    end

    it "does not commit to git" do
      expect(h.git_commands.none? { |a| a.args.any? { |arg| arg.is_a?(Hash) && arg[:commit] } }).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # Nav markup varies by stack
  # ---------------------------------------------------------------------------
  describe "home page navigation markup" do
    context "with React stack" do
      subject(:h) { run_template(react: true, sidekiq: false) }

      it "inserts Inertia.js example link into home view" do
        nav_insert = h.inserted_files.find do |a|
          a.args.first.to_s.include?("home/index") &&
            a.args[1].to_s.include?("Inertia.js example")
        end
        expect(nav_insert).not_to be_nil
      end

      it "does NOT insert Lookbook link" do
        lookbook_insert = h.inserted_files.find do |a|
          a.args[1].to_s.include?("Lookbook")
        end
        expect(lookbook_insert).to be_nil
      end
    end

    context "with Hotwire stack" do
      subject(:h) { run_template(react: false, importmaps: true, sidekiq: false) }

      it "inserts Lookbook link into home view" do
        nav_insert = h.inserted_files.find do |a|
          a.args.first.to_s.include?("home/index") &&
            a.args[1].to_s.include?("Lookbook")
        end
        expect(nav_insert).not_to be_nil
      end
    end

    context "with Sidekiq enabled (React)" do
      subject(:h) { run_template(react: true, sidekiq: true) }

      it "includes Sidekiq link in navigation" do
        nav_insert = h.inserted_files.find do |a|
          a.args.first.to_s.include?("home/index") &&
            a.args[1].to_s.include?("Sidekiq")
        end
        expect(nav_insert).not_to be_nil
      end
    end

    context "with Sidekiq enabled (Hotwire)" do
      subject(:h) { run_template(react: false, importmaps: true, sidekiq: true) }

      it "includes Sidekiq link in navigation" do
        nav_insert = h.inserted_files.find do |a|
          a.args.first.to_s.include?("home/index") &&
            a.args[1].to_s.include?("Sidekiq")
        end
        expect(nav_insert).not_to be_nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Auth0 + Hotwire specific UI inserts
  # ---------------------------------------------------------------------------
  describe "Auth0 Hotwire UI" do
    subject(:h) do
      run_template(
        react: false,
        importmaps: true,
        auth0: true,
        auth0_client_id: "cid",
        auth0_client_secret: "csec",
        auth0_domain: "d.auth0.com",
        guest: false,
      )
    end

    it "inserts login/logout buttons into home view" do
      btn_insert = h.inserted_files.find do |a|
        a.args.first.to_s.include?("home/index") &&
          a.args[1].to_s.include?("logged_in?")
      end
      expect(btn_insert).not_to be_nil
    end

    it "inserts User Info link" do
      user_link = h.inserted_files.find do |a|
        a.args.first.to_s.include?("home/index") &&
          a.args[1].to_s.include?("User Info")
      end
      expect(user_link).not_to be_nil
    end

    it "inserts user info display into user/show view" do
      user_info = h.inserted_files.find do |a|
        a.args.first.to_s.include?("user/show") &&
          a.args[1].to_s.include?("User Info")
      end
      expect(user_info).not_to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # PostgreSQL + no Sidekiq outputs a reminder
  # ---------------------------------------------------------------------------
  describe "PostgreSQL without Sidekiq" do
    subject(:h) { run_template(postgres: true, sidekiq: false) }

    it "does NOT use the database-pg-sidekiq template" do
      expect(h.templated_files).to be_empty
    end
  end

  # Custom matcher for readable specs
  RSpec::Matchers.define :have_gem do |expected|
    match do |harness|
      harness.has_gem?(expected)
    end
    failure_message do
      "expected template to add gem '#{expected}', but it was not found.\nGems added: #{actual.gems.sort.join(', ')}"
    end
    failure_message_when_negated do
      "expected template NOT to add gem '#{expected}', but it was found"
    end
  end
end
