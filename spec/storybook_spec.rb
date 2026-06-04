RSpec.describe "storybook.rb" do
  let(:template_path) { File.expand_path("../storybook.rb", __dir__) }

  def run_template
    harness = TemplateHarness.new({})
    harness.apply(template_path)
    harness
  end

  subject(:h) { run_template }

  it "appends storybook entry to Procfile.dev" do
    appended = h.appended_files.find { |a| a.args.first == "Procfile.dev" }
    expect(appended).not_to be_nil
    expect(appended.args[1]).to include("storybook")
    expect(appended.args[1]).to include("npm run storybook")
  end

  it "runs npm create storybook" do
    expect(h.has_command?("npm create storybook@latest")).to be true
  end
end
