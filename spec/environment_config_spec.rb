RSpec.describe "environment_config.rb" do
  let(:template_path) { File.expand_path("../environment_config.rb", __dir__) }

  let(:base_answers) do
    {
      use_defaults: false,
      mise: false,
      ruby_version: "3.4.5",
      ruby_gemset: nil,
      use_node: false,
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

      it "does NOT create .ruby-gemset" do
        cmd = h.commands.find { |c| c.include?(".ruby-gemset") }
        expect(cmd).to be_nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Node.js option
  # ---------------------------------------------------------------------------
  describe "Node.js option" do
    context "when enabled" do
      subject(:h) { run_template(use_node: true, node_version: "22") }

      it "writes the node version to .node-version" do
        cmd = h.commands.find { |c| c.include?(".node-version") }
        expect(cmd).not_to be_nil
        expect(cmd).to include("22")
      end
    end

    context "when disabled" do
      subject(:h) { run_template(use_node: false) }

      it "does NOT create .node-version" do
        cmd = h.commands.find { |c| c.include?(".node-version") }
        expect(cmd).to be_nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Mise option
  # ---------------------------------------------------------------------------
  describe "mise option" do
    context "when enabled" do
      subject(:h) { run_template(mise: true, ruby_version: "3.4.5", use_node: true, node_version: "22") }

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

    context "when enabled without Node" do
      subject(:h) { run_template(mise: true, ruby_version: "3.4.5", use_node: false) }

      it "creates mise.toml with ruby version" do
        created = h.actions_of(:create_file).find { |a| a.args.first == "mise.toml" }
        expect(created).not_to be_nil
        expect(created.args[1]).to include("ruby = '3.4.5'")
      end

      it "does NOT append node to mise.toml" do
        appended = h.appended_files.find { |a| a.args.first == "mise.toml" }
        expect(appended).to be_nil
      end

      it "still runs mise trust and install" do
        expect(h.has_command?("mise trust")).to be true
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

  # ---------------------------------------------------------------------------
  # Use-all-defaults mode
  # ---------------------------------------------------------------------------
  describe "use_defaults mode" do
    subject(:h) do
      harness = TemplateHarness.new(use_defaults: true)
      harness.apply(template_path)
      harness
    end

    it "uses default Ruby version 3.4" do
      cmd = h.commands.find { |c| c.include?(".ruby-version") }
      expect(cmd).to include("3.4")
    end

    it "creates mise.toml (default: mise enabled)" do
      expect(h.created_files).to include("mise.toml")
    end

    it "writes Node 24 to .node-version (default: node enabled)" do
      cmd = h.commands.find { |c| c.include?(".node-version") }
      expect(cmd).not_to be_nil
      expect(cmd).to include("24")
    end

    it "does NOT create .ruby-gemset (default: skip)" do
      cmd = h.commands.find { |c| c.include?(".ruby-gemset") }
      expect(cmd).to be_nil
    end

    it "runs mise trust and install" do
      expect(h.has_command?("mise trust")).to be true
      expect(h.has_command?("mise install")).to be true
    end
  end
end
