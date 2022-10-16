
ruby_version = ask("Which ruby version are you using? This will add it to the .ruby-version file:")
run "echo \"#{ruby_version}\" > .ruby-version"
ruby_gemset = ask("Enter a gemset name for .ruby-gemset or just hit enter to skip creation of this file:")
if ruby_gemset
  run "echo \"#{ruby_gemset}\" > .ruby-gemset"
end

gem_group :development, :test do
  gem "dotenv-rails"
  gem "rspec-rails"
  gem "factory_bot_rails"
end

append_to_file ".gitignore", <<-EOS

# Local-only environment variables
.env
.env.*
EOS

gem "view_component"
gem "lograge"

environment 'config.lograge.enabled = true', env: 'production'

after_bundle do
  generate "rspec:install"

  git :init
  git add: '.'
  git commit: "-a -m 'Initial commit'"
end