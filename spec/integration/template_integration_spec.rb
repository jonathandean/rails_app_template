# Integration tests that actually run `rails new` with the template and verify
# the resulting application generates and boots. These are slow (bundle install
# + generators per combo) and require network access, so they are opt-in.
#
# Run with:
#   RUN_INTEGRATION=1 bundle exec rspec spec/integration/
#
# A single combo:
#   RUN_INTEGRATION=1 bundle exec rspec spec/integration/ -e "Hotwire minimal"
#
# PostgreSQL combos additionally require `pg_config` (libpq) to build the pg
# gem; they are skipped automatically when it is unavailable.

require "open3"
require "tmpdir"
require "fileutils"
require "timeout"
require "bundler"

RSpec.describe "template.rb integration", skip: (ENV["RUN_INTEGRATION"] != "1" ? "Set RUN_INTEGRATION=1 to run" : false) do
  let(:template_path) { File.expand_path("../../template.rb", __dir__) }
  let(:timeout_seconds) { Integer(ENV.fetch("INTEGRATION_TIMEOUT", 900)) }

  def pg_available?
    system("which pg_config > /dev/null 2>&1")
  end

  # Runs `rails new <name> ... -m template.rb` with the given piped answers,
  # then yields (app_path, stdout, stderr, status). Cleans up afterwards.
  def generate_app(name, rails_flags:, answers:)
    dir = Dir.mktmpdir("rails_template_test_")
    input = answers.join("\n") + "\n"
    cmd = "rails new #{name} #{rails_flags} --force -m #{template_path}"

    # Run outside this suite's bundler context so the generated app uses its own
    # Gemfile (otherwise BUNDLE_GEMFILE points at this repo's rspec-only Gemfile).
    stdout = stderr = status = nil
    Bundler.with_unbundled_env do
      Timeout.timeout(timeout_seconds) do
        stdout, stderr, status = Open3.capture3(cmd, stdin_data: input, chdir: dir)
      end
    end

    yield File.join(dir, name), stdout, stderr, status
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  # `bin/rails runner` succeeds → the app boots without load errors.
  def app_boots?(app_path)
    stdout = status = nil
    Bundler.with_unbundled_env do
      stdout, _stderr, status = Open3.capture3("bin/rails runner \"puts 'BOOT_OK'\"", chdir: app_path)
    end
    status.success? && stdout.include?("BOOT_OK")
  end

  # zeitwerk:check passes → all autoloaded constants resolve.
  def zeitwerk_ok?(app_path)
    status = nil
    Bundler.with_unbundled_env do
      _stdout, _stderr, status = Open3.capture3("bin/rails zeitwerk:check", chdir: app_path)
    end
    status.success?
  end

  shared_examples "a generated app" do |gemfile_includes:, gemfile_excludes:, files_present:|
    it "generates, boots, and passes zeitwerk:check" do
      generate_app(app_name, rails_flags: rails_flags, answers: answers) do |app, stdout, stderr, status|
        aggregate_failures do
          expect(status.exitstatus).to eq(0),
            "rails new exited #{status.exitstatus}\n--- STDOUT ---\n#{stdout[-2000..]}\n--- STDERR ---\n#{stderr[-2000..]}"

          gemfile = File.read(File.join(app, "Gemfile"))
          gemfile_includes.each { |g| expect(gemfile).to include(g) }
          gemfile_excludes.each { |g| expect(gemfile).not_to include(g) }

          files_present.each { |f| expect(File.exist?(File.join(app, f))).to be(true), "expected #{f} to exist" }

          # Default Gemfile already ships bundler-audit; ensure no duplicate line.
          expect(gemfile.scan(/^\s*gem ["']bundler-audit["']/).size).to be <= 1

          expect(app_boots?(app)).to be(true), "app failed to boot via bin/rails runner"
          expect(zeitwerk_ok?(app)).to be(true), "zeitwerk:check failed"
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Hotwire minimal: importmaps, RSpec, sqlite (no Auth0/Sidekiq/PG)
  # ---------------------------------------------------------------------------
  describe "Hotwire minimal (importmaps, RSpec, sqlite)" do
    # use_defaults? n | react? n | importmaps? y | lograge? n | sidekiq? n |
    # hashdiff? n | auth0? n | rspec? y | postgres? n | ruby_native? n |
    # overmind? n | commit? n
    let(:app_name) { "hotwire_minimal" }
    let(:answers) { %w[n n y n n n n y n n n n] }
    let(:rails_flags) { "--css=tailwind --skip-system-test" }

    include_examples "a generated app",
      gemfile_includes: %w[view_component lookbook rspec-rails dotenv-rails],
      gemfile_excludes: %w[inertia_rails vite_rails sidekiq omniauth-auth0],
      files_present: ["app/components/.keep", "spec/components/previews/.keep", "bin/cli", "bin/ci"]
  end

  # ---------------------------------------------------------------------------
  # React minimal: Inertia + Vite, minitest, sqlite
  # ---------------------------------------------------------------------------
  describe "React minimal (Inertia/Vite, sqlite)" do
    # use_defaults? n | react? y | lograge? n | sidekiq? n | hashdiff? n |
    # auth0? n | rspec? n | postgres? n | ruby_native? n | overmind? n |
    # commit? n   (no importmaps prompt for React)
    let(:app_name) { "react_minimal" }
    let(:answers) { %w[n y n n n n n n n n n] }
    let(:rails_flags) { "--css=tailwind --skip-system-test --skip-hotwire --skip-jbuilder" }

    include_examples "a generated app",
      gemfile_includes: %w[inertia_rails vite_rails dotenv-rails],
      gemfile_excludes: %w[view_component lookbook sidekiq omniauth-auth0],
      files_present: ["bin/cli", "bin/ci", "vite.config.ts"]
  end

  # ---------------------------------------------------------------------------
  # Hotwire full: PG + Sidekiq + Auth0 + Guest + RSpec + lograge + hashdiff
  # ---------------------------------------------------------------------------
  describe "Hotwire full (PG + Sidekiq + Auth0 + Guest + RSpec)" do
    before { skip "requires pg_config (libpq) to build the pg gem" unless pg_available? }

    # use_defaults? n | react? n | importmaps? y | lograge? y | sidekiq? y |
    # hashdiff? y | auth0? y | rspec? y | postgres? y | ruby_native? n |
    # overmind? n | <cid> | <secret> | <domain> | guest? y | commit? n
    let(:app_name) { "hotwire_full" }
    let(:answers) { %w[n n y y y y y y y n n test-cid test-csec test.auth0.com y n] }
    let(:rails_flags) { "--database=postgresql --css=tailwind --skip-system-test" }

    include_examples "a generated app",
      gemfile_includes: %w[view_component sidekiq omniauth-auth0 lograge hashdiff rspec-rails],
      gemfile_excludes: %w[inertia_rails vite_rails],
      files_present: ["config/initializers/sidekiq.rb", "app/models/user.rb", "bin/ci"]
  end

  # ---------------------------------------------------------------------------
  # React + Postgres + RSpec (no Auth0/Sidekiq)
  # ---------------------------------------------------------------------------
  describe "React + Postgres + RSpec" do
    before { skip "requires pg_config (libpq) to build the pg gem" unless pg_available? }

    # use_defaults? n | react? y | lograge? n | sidekiq? n | hashdiff? n |
    # auth0? n | rspec? y | postgres? y | ruby_native? n | overmind? n |
    # commit? n
    let(:app_name) { "react_pg_rspec" }
    let(:answers) { %w[n y n n n n y y n n n] }
    let(:rails_flags) { "--database=postgresql --css=tailwind --skip-system-test --skip-hotwire --skip-jbuilder" }

    include_examples "a generated app",
      gemfile_includes: %w[inertia_rails vite_rails rspec-rails],
      gemfile_excludes: %w[view_component sidekiq omniauth-auth0],
      files_present: ["bin/cli", "bin/ci", "vite.config.ts"]
  end
end
