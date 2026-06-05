# Validates that code examples in README.md stay in sync with the actual
# template source files. Catches documentation drift before it ships.

RSpec.describe "README.md documentation accuracy" do
  let(:root) { File.expand_path("..", __dir__) }
  let(:readme) { File.read(File.join(root, "README.md")) }

  describe "CLI example" do
    let(:example_subcommand) { File.read(File.join(root, "templates/cli/example_subcommand.rb")) }

    it "uses the same method name as templates/cli/example_subcommand.rb" do
      # Extract the method name defined in the actual template file
      actual_method = example_subcommand.match(/^\s*def (\w+)/)&.captures&.first
      expect(actual_method).not_to be_nil, "Could not find a method definition in example_subcommand.rb"

      # The README should reference this method in its code example
      expect(readme).to include("def #{actual_method}"),
        "README CLI example shows a different method name than '#{actual_method}' in templates/cli/example_subcommand.rb"
    end

    it "uses the same desc as templates/cli/example_subcommand.rb" do
      # Extract the desc command name from the actual template file
      actual_desc = example_subcommand.match(/desc ["'](\w+)["']/)&.captures&.first
      expect(actual_desc).not_to be_nil, "Could not find a desc declaration in example_subcommand.rb"

      # The README should reference this desc in its code example
      expect(readme).to include(%(desc "#{actual_desc}")),
        "README CLI example shows a different desc than '#{actual_desc}' in templates/cli/example_subcommand.rb"
    end

    it "references the correct install path for CLI subcommands" do
      # template.rb copies to app/cli/, so README should point there
      template_rb = File.read(File.join(root, "template.rb"))
      cli_dest = template_rb.match(/copy_file.*example_subcommand\.rb["'],\s*["']([^"']+)["']/)&.captures&.first
      expect(cli_dest).not_to be_nil, "Could not find CLI copy destination in template.rb"

      dest_dir = File.dirname(cli_dest)
      expect(readme).to include("`#{dest_dir}/"),
        "README should reference `#{dest_dir}/` as the CLI subcommand directory"
    end
  end

  describe "migration version numbers" do
    it "uses a migration version consistent with Rails 8.x" do
      # Extract all ActiveRecord::Migration[X.Y] references from README
      versions = readme.scan(/ActiveRecord::Migration\[(\d+\.\d+)\]/).flatten.uniq

      expect(versions).not_to be_empty, "No migration version references found in README"

      versions.each do |version|
        major = version.split(".").first.to_i
        expect(major).to be >= 8,
          "README references Migration[#{version}] but this is a Rails 8+ template"
      end
    end
  end

  describe "gem references" do
    it "references annotaterb (not the abandoned annotate gem)" do
      # template.rb uses annotaterb
      template_rb = File.read(File.join(root, "template.rb"))
      expect(template_rb).to include('"annotaterb"'),
        "template.rb should use the annotaterb gem"

      # README should not link to the old ctran/annotate_models repo
      expect(readme).not_to match(/github\.com\/ctran\/annotate_models/),
        "README still links to the abandoned ctran/annotate_models instead of drwl/annotaterb"
    end
  end

  describe "CLI help output" do
    it "shows command names matching the actual subcommand" do
      example_subcommand = File.read(File.join(root, "templates/cli/example_subcommand.rb"))
      actual_method = example_subcommand.match(/^\s*def (\w+)/)&.captures&.first

      # The README shows example CLI output like `cli example hello`
      expect(readme).to include("bin/cli example #{actual_method}"),
        "README CLI help output should show 'bin/cli example #{actual_method}'"
    end
  end
end
