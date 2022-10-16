
ruby_version = ask("Which ruby version are you using? This will add it to the .ruby-version file:")
run "echo \"#{ruby_version}\" > .ruby-version"
ruby_gemset = ask("Enter a gemset name for .ruby-gemset or just hit enter to skip creation of this file:")
if ruby_gemset
  run "echo \"#{ruby_gemset}\" > .ruby-gemset"
end

gem_group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
end

gem "view_component"

after_bundle do
  generate "rspec:install"

  git :init
  git add: '.'
  git commit: "-a -m 'Initial commit'"
end