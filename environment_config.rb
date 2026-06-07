def source_paths
  [__dir__]
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

use_mise = yes_default?("Do you want to use Mise?", default: true, use_defaults: use_defaults)

ruby_version = ask_default("Which Ruby version?", default: "3.4", use_defaults: use_defaults)
run "echo \"#{ruby_version}\" > .ruby-version"

ruby_gemset = ask_default("Enter a gemset name for .ruby-gemset (leave blank to skip)", default: "", use_defaults: use_defaults)
unless ruby_gemset.to_s.strip.empty?
  run "echo \"#{ruby_gemset}\" > .ruby-gemset"
end

if use_mise
  mise_config = <<-EOS
  [tools]
  ruby = '#{ruby_version}'
  EOS
  create_file "mise.toml", mise_config
end

use_node = yes_default?("Do you need Node.js?", default: true, use_defaults: use_defaults)
if use_node
  node_version = ask_default("Which Node.js version?", default: "24", use_defaults: use_defaults)
  run "echo \"#{node_version}\" > .node-version"
  if use_mise
    append_to_file "mise.toml", "node = '#{node_version}'\n"
  end
end

if use_mise
  run "mise trust"
  run "mise install"
end

# TODO get this from the Gemfile.lock
# BUNDLED WITH
#    2.6.9
run "gem install bundler:2.6.9"
