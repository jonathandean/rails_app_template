def source_paths
  [__dir__]
end

use_mise = yes?("Do you want to use Mise?")

ruby_version = ask("Which ruby version are you using? This will add it to the .ruby-version file#{use_mise ? ' and mise.toml' : ''}:")
run "echo \"#{ruby_version}\" > .ruby-version"
ruby_gemset = ask("Enter a gemset name for .ruby-gemset - or hit enter to skip creation of this file if you aren't using RVM, don't want it, or aren't sure:")
if ruby_gemset
  run "echo \"#{ruby_gemset}\" > .ruby-gemset"
end

if use_mise
  mise_config = <<-EOS
  [tools]
  ruby = '#{ruby_version}'
  EOS
  create_file "mise.toml", mise_config
end

node_version = ask("Will you need Node.js? If so, which version? (or hit enter to skip creation of this file if you aren't using Node, don't want it, or aren't sure):")
run "echo \"#{node_version}\" > .node-version"
if use_mise
  append_to_file "mise.toml", "node = '#{node_version}'\n"
  run "mise trust"
  run "mise install"
end

# TODO get this from the Gemfile.lock
# BUNDLED WITH
#    2.6.9
run "gem install bundler:2.6.9"
