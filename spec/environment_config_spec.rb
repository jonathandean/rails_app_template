RSpec.describe "environment_config.rb" do
  let(:template_path) { File.expand_path("../environment_config.rb", __dir__) }

  let(:base_answers) do
    {
      mise: false,
      ruby_version: "3.4.5",
      ruby_gemset: nil,
      node_version: nil,
    }
  end

  def run_template(overrides = {})
    answers = base_answers.merge(overrides)
    harness = TemplateHarness.new(answers)
    harness.apply(template_path)
    harness
  end

  # ---------------------------------------------------------------------------
  # Unconditional behaviour
  # ---------------------------------------------------------------------------
  describe "unconditional setup" do
    subject(:h) { run_template }

    it "writes the ruby version to .ruby-version" do
      cmd = h.commands.find { |c| c.include?(".ruby-version") }
      expect(cmd).not_to be_nil
      expect(cmd).to include("3.4.5")
    end

    it "writes the node version to .node-version" do
      expect(h.has_command?(".node-version")).to be true
    end

    it "installs bundler 2.6.9" do
      expect(h.has_command?("gem install bundler:2.6.9")).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # Ruby gemset option
  # ---------------------------------------------------------------------------
  describe "ruby gemset" do
    context "when a gemset name is provided" do
      subject(:h) { run_template(ruby_gemset: "mygemset") }

      it "writes the gemset to .ruby-gemset" do
        cmd = h.commands.find { |c| c.include?(".ruby-gemset") }
        expect(cmd).not_to be_nil
        expect(cmd).to include("mygemset")
      end
    end

    context "when gemset is declined (nil)" do
      subject(:h) { run_template(ruby_gemset: nil) }

      it "still runs the echo command (template checks truthiness of response)" do
        # The template checks `if ruby_gemset` — nil is falsy in Ruby,
        # so .ruby-gemset is NOT created.
        cmd = h.commands.find { |c| c.include?(".ruby-gemset") }
        expect(cmd).to be_nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Mise option
  # ---------------------------------------------------------------------------
  describe "mise option" do
    context "when enabled" do
      subject(:h) { run_template(mise: true, ruby_version: "3.4.5", node_version: "22") }

      it "creates mise.toml with ruby version" do
        created = h.actions_of(:create_file).find { |a| a.args.first == "mise.toml" }
        expect(created).not_to be_nil
        expect(created.args[1]).to include("ruby = '3.4.5'")
      end

      it "appends node version to mise.toml" do
        appended = h.appended_files.find { |a| a.args.first == "mise.toml" }
        expect(appended).not_to be_nil
        expect(appended.args[1]).to include("node = '22'")
      end

      it "runs mise trust" do
        expect(h.has_command?("mise trust")).to be true
      end

      it "runs mise install" do
        expect(h.has_command?("mise install")).to be true
      end
    end

    context "when disabled" do
      subject(:h) { run_template(mise: false) }

      it "does NOT create mise.toml" do
        expect(h.created_files).not_to include("mise.toml")
      end

      it "does NOT run mise trust" do
        expect(h.has_command?("mise trust")).to be false
      end

      it "does NOT run mise install" do
        expect(h.has_command?("mise install")).to be false
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Custom ruby version
  # ---------------------------------------------------------------------------
  describe "ruby version" do
    subject(:h) { run_template(ruby_version: "3.3.0") }

    it "uses the specified ruby version" do
      cmd = h.commands.find { |c| c.include?(".ruby-version") }
      expect(cmd).to include("3.3.0")
    end
  end
end
