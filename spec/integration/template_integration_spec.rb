# Integration tests that actually run `rails new` with the template and verify
# the resulting application. These are slow (bundle install + generators per
# combo) and require network access, so they are opt-in.
#
# Run with:
#   RUN_INTEGRATION=1 bundle exec rspec spec/integration/
#
# Individual combos:
#   RUN_INTEGRATION=1 bundle exec rspec spec/integration/ -e "hotwire minimal"

require "open3"
require "tmpdir"
require "fileutils"

RSpec.describe "template.rb integration", skip: (ENV["RUN_INTEGRATION"] != "1" ? "Set RUN_INTEGRATION=1 to run" : false) do
  let(:template_path) { File.expand_path("../../template.rb", __dir__) }
  let(:timeout_seconds) { Integer(ENV.fetch("INTEGRATION_TIMEOUT", 600)) }

  # Creates a temp dir, runs `rails new` with piped answers, yields the app
  # path, then cleans up.
  def generate_app(name, rails_flags:, answers:)
    dir = Dir.mktmpdir("rails_template_test_")
    input = answers.join("\n") + "\n"

    cmd = "rails new #{name} #{rails_flags} --force -m #{template_path}"
    stdout, stderr, status = nil
    Timeout.timeout(timeout_seconds) do
      stdout, stderr, status = Open3.capture3(cmd, stdin_data: input, chdir: dir)
    end

    app_path = File.join(dir, name)
    yield app_path, stdout, stderr, status
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  # Checks whether `bin/rails runner "puts 'ok'"` succeeds — a lightweight
  # "does it boot?" sanity check.
  def app_boots?(app_path)
    cmd = "bin/rails runner \"puts 'BOOT_OK'\""
    stdout, _stderr, status = Open3.capture3(cmd, chdir: app_path)
    status.success? && stdout.include?("BOOT_OK")
  end

  # Checks whether zeitwerk can resolve all autoloaded constants.
  def zeitwerk_check?(app_path)
    _stdout, _stderr, status = Open3.capture3("bin/rails zeitwerk:check", chdir: app_path)
    status.success?
  end

  # ---------------------------------------------------------------------------
  # Combo: React minimal (no postgres, no auth0, no sidekiq)
  # ---------------------------------------------------------------------------
  describe "React minimal (no PG, no Auth0, no Sidekiq)" do
    # Answers in prompt order:
    #   1. React? y
    #   2. lograge? n
    #   3. sidekiq? n
    #   4. hashdiff? n
    #   5. auth0? n
    #   6. rspec? n
    #   7. postgres? n
    #   8. commit? n
    let(:answers) { %w[y n n n n n n n] }
    let(:rails_flags) { "--css=tailwind --skip-system-test --skip-hotwire --skip-jbuilder" }

    it "generates without fatal error" do
      pending "Known issue: template may fail on Rails 8.1 due to kamal-secrets.tt source_paths conflict"
      generate_app("react_minimal", rails_flags: rails_flags, answers: answers) do |app, _out, _err, status|
        expect(status.exitstatus).to eq(0), "rails new exited #{status.exitstatus}"
        expect(File.directory?(app)).to be true
        expect(File.exist?(File.join(app, "Gemfile"))).to be true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Combo: Hotwire minimal (importmaps, no auth0, no sidekiq, no postgres)
  # ---------------------------------------------------------------------------
  describe "Hotwire minimal (importmaps, no Auth0, no Sidekiq, no PG)" do
    # Answers:
    #   1. React? n
    #   2. importmaps? y
    #   3. lograge? n
    #   4. sidekiq? n
    #   5. hashdiff? n
    #   6. auth0? n
    #   7. rspec? y
    #   8. postgres? n
    #   9. commit? n
    let(:answers) { %w[n y n n n n y n n] }
    let(:rails_flags) { "--css=tailwind --skip-system-test" }

    it "generates without fatal error" do
      pending "Known issue: config.view_component.preview_paths << raises NoMethodError on nil (template.rb:32)"
      generate_app("hotwire_minimal", rails_flags: rails_flags, answers: answers) do |app, _out, _err, status|
        expect(status.exitstatus).to eq(0), "rails new exited #{status.exitstatus}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Combo: Hotwire + Postgres + Sidekiq + Auth0 + Guest + RSpec
  # ---------------------------------------------------------------------------
  describe "Hotwire full (PG + Sidekiq + Auth0 + Guest + RSpec)" do
    # Answers:
    #   1. React? n
    #   2. importmaps? y
    #   3. lograge? y
    #   4. sidekiq? y
    #   5. hashdiff? y
    #   6. auth0? y
    #   7. rspec? y
    #   8. postgres? y
    #   9. Auth0 Client ID
    #  10. Auth0 Client Secret
    #  11. Auth0 Domain
    #  12. guest? y
    #  13. commit? n
    let(:answers) { %w[n y y y y y y y test-cid test-csec test.auth0.com y n] }
    let(:rails_flags) { "--database=postgresql --css=tailwind --skip-system-test" }

    it "generates without fatal error" do
      pending "Known issue: config.view_component.preview_paths << raises NoMethodError; also requires pg_config for pg gem"
      generate_app("hotwire_full", rails_flags: rails_flags, answers: answers) do |app, _out, _err, status|
        expect(status.exitstatus).to eq(0), "rails new exited #{status.exitstatus}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Combo: React + Postgres + RSpec (no Auth0, no Sidekiq)
  # ---------------------------------------------------------------------------
  describe "React + Postgres + RSpec" do
    let(:answers) { %w[y n n n n y y n] }
    let(:rails_flags) { "--database=postgresql --css=tailwind --skip-system-test --skip-hotwire --skip-jbuilder" }

    it "generates without fatal error" do
      pending "Requires pg_config for pg gem native extension; also kamal-secrets.tt source_paths conflict"
      generate_app("react_pg_rspec", rails_flags: rails_flags, answers: answers) do |app, _out, _err, status|
        expect(status.exitstatus).to eq(0), "rails new exited #{status.exitstatus}"
      end
    end
  end
end
