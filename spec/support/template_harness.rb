# A lightweight harness that evaluates a Rails application template (template.rb,
# environment_config.rb, storybook.rb) with scripted prompt answers and records
# every generator action (gem, route, copy_file, etc.) without touching the
# filesystem or running subprocesses. This lets us exhaustively test the
# combinatorial decision logic across all option sets.
#
# Usage:
#   harness = TemplateHarness.new(react: false, lograge: true, ...)
#   harness.apply("template.rb")
#   expect(harness).to have_gem("lograge")

class TemplateHarness
  # Structured action record
  Action = Struct.new(:type, :args, :options, :group, keyword_init: true)

  TEMPLATE_PROMPTS = {
    "use React"                 => :react,
    "importmaps"                => :importmaps,
    "lograge"                   => :lograge,
    "Sidekiq and Redis"         => :sidekiq,
    "hashdiff"                  => :hashdiff,
    "authentication via Auth0"  => :auth0,
    "RSpec instead of minitest" => :rspec,
    "PostgreSQL as your database" => :postgres,
    "guest user accounts"       => :guest,
    "commit your empty app"     => :git_commit,
    "Auth0 Client ID"           => :auth0_client_id,
    "Auth0 Client Secret"       => :auth0_client_secret,
    "Auth0 Domain"              => :auth0_domain,
    "Ruby Native"               => :ruby_native,
    # environment_config.rb
    "use Mise"                  => :mise,
    "ruby version"              => :ruby_version,
    "gemset name"               => :ruby_gemset,
    "Node.js"                   => :node_version,
  }.freeze

  attr_reader :actions

  # +answers+ is a Hash of symbol => value (Boolean for yes?/no?, String for ask).
  # Any prompt whose mapped symbol is absent from +answers+ raises.
  def initialize(answers = {})
    @answers = answers
    @actions = []
    @gem_group_stack = []
    @after_bundle_blocks = []
  end

  # ---------------------------------------------------------------------------
  # Template evaluation
  # ---------------------------------------------------------------------------

  # Evaluates the template in an isolated empty working directory so that any
  # filesystem checks the template performs (e.g. reading a generated app's
  # Gemfile) are deterministic and don't pick up files from the project root.
  #
  # +seed_files+ optionally seeds files into that working dir before evaluation,
  # e.g. apply("template.rb", seed_files: { "Gemfile" => "gem 'bundler-audit'" }).
  def apply(template_path, seed_files: {})
    content = File.read(template_path)
    require "tmpdir"
    Dir.mktmpdir("template_harness_") do |dir|
      Dir.chdir(dir) do
        seed_files.each { |name, body| File.write(name, body) }
        instance_eval(content, template_path)
        run_after_bundle_blocks
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Prompt stubs
  # ---------------------------------------------------------------------------

  def yes?(question, *_args)
    !!answer_for(question)
  end

  def no?(question, *_args)
    !answer_for(question)
  end

  def ask(question, *_args)
    answer_for(question)
  end

  # ---------------------------------------------------------------------------
  # Generator action recorders
  # ---------------------------------------------------------------------------

  def create_file(path, content = nil, *_opts)
    record(:create_file, [path, content])
  end

  def copy_file(src, dest = src, *_opts)
    record(:copy_file, [src, dest])
  end

  def template(src, dest = src, *_opts)
    record(:template, [src, dest])
  end

  def append_to_file(path, content = nil, *_opts, &block)
    content = block.call if block && content.nil?
    record(:append_to_file, [path, content])
  end

  def prepend_to_file(path, content = nil, *_opts, &block)
    content = block.call if block && content.nil?
    record(:prepend_to_file, [path, content])
  end

  def insert_into_file(path, *args, **opts, &block)
    # Thor signature: insert_into_file(path, content, options) or with block
    content = args.first
    content = block.call if block && content.nil?
    record(:insert_into_file, [path, content], opts)
  end

  def gsub_file(path, pattern, *args, &block)
    replacement = args.first
    replacement = block if block && replacement.nil?
    record(:gsub_file, [path, pattern, replacement])
  end

  def gem(name, *args)
    opts = args.last.is_a?(Hash) ? args.last : {}
    record(:gem, [name], opts, current_gem_groups)
  end

  def gem_group(*groups, &block)
    @gem_group_stack.push(groups.flatten)
    block.call if block
    @gem_group_stack.pop
  end

  def route(routing_code)
    record(:route, [routing_code])
  end

  def environment(data = nil, options = {}, &block)
    data = block.call if block && data.nil?
    record(:environment, [data], options)
  end

  def initializer(filename, content = nil, &block)
    content = block.call if block && content.nil?
    record(:initializer, [filename, content])
  end

  def generate(*args)
    record(:generate, args)
  end

  def run(command, *_opts)
    record(:run, [command])
  end

  def git(*args)
    record(:git, args)
  end

  def after_bundle(&block)
    @after_bundle_blocks << block
  end

  # Silenced — template uses puts for user messages
  def puts(*_args); end

  # Used in template.rb after_bundle for puts "cd #{app_name}"
  def app_name
    "dummy_app"
  end

  # template.rb defines source_paths; accept it as a no-op
  def source_paths
    []
  end

  # ---------------------------------------------------------------------------
  # Query helpers
  # ---------------------------------------------------------------------------

  def gems
    actions_of(:gem).map { |a| a.args.first }
  end

  def has_gem?(name)
    actions_of(:gem).any? { |a| a.args.first == name }
  end

  def gem_in_group?(name, *groups)
    actions_of(:gem).any? do |a|
      a.args.first == name && groups.all? { |g| Array(a.group).include?(g) }
    end
  end

  def routes
    actions_of(:route).map { |a| a.args.first }
  end

  def has_route?(substring)
    routes.any? { |r| r.include?(substring) }
  end

  def environments
    actions_of(:environment)
  end

  def has_environment?(substring, env: nil)
    environments.any? do |a|
      code = a.args.first.to_s
      matches_code = code.include?(substring)
      matches_env = env.nil? || a.options[:env] == env
      matches_code && matches_env
    end
  end

  def copied_files
    actions_of(:copy_file).map { |a| { src: a.args[0], dest: a.args[1] } }
  end

  def has_copied_file?(dest)
    copied_files.any? { |f| f[:dest] == dest || f[:src] == dest }
  end

  def templated_files
    actions_of(:template).map { |a| { src: a.args[0], dest: a.args[1] } }
  end

  def created_files
    actions_of(:create_file).map { |a| a.args.first }
  end

  def has_created_file?(path)
    created_files.include?(path)
  end

  def initializers
    actions_of(:initializer).map { |a| a.args.first }
  end

  def generators
    actions_of(:generate).map { |a| a.args.join(" ") }
  end

  def has_generator?(substring)
    generators.any? { |g| g.include?(substring) }
  end

  def commands
    actions_of(:run).map { |a| a.args.first }
  end

  def has_command?(substring)
    commands.any? { |c| c.include?(substring) }
  end

  def appended_files
    actions_of(:append_to_file)
  end

  def inserted_files
    actions_of(:insert_into_file)
  end

  def gsubbed_files
    actions_of(:gsub_file)
  end

  def git_commands
    actions_of(:git)
  end

  def actions_of(type)
    @actions.select { |a| a.type == type }
  end

  private

  def answer_for(question)
    key = TEMPLATE_PROMPTS.keys.find { |k| question.include?(k) }
    raise "No prompt mapping for: #{question.inspect}" if key.nil?
    sym = TEMPLATE_PROMPTS[key]
    unless @answers.key?(sym)
      raise "No scripted answer for #{sym.inspect} (prompt: #{question.inspect}). " \
            "Provide it in the answers hash."
    end
    @answers[sym]
  end

  def current_gem_groups
    @gem_group_stack.last&.dup || []
  end

  def record(type, args, options = {}, group = nil)
    @actions << Action.new(type: type, args: args, options: options, group: group)
  end

  def run_after_bundle_blocks
    @after_bundle_blocks.each { |blk| instance_eval(&blk) }
  end
end
