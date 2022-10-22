# Rails App Template

My preferred starting point for new Rails 7 apps.

# Usage

## New apps

First, install the latest version of Ruby. At the moment that is 3.1.2. I recommend using RVM, rbenv, or similar and not using your system Ruby.

```
gem install rails
rails new your_new_app_name --database=postgresql --skip-jbuilder --skip-test -skip-bootsnap --css=tailwind -m path/to/this/template.rb
```

**Note:** Be sure to scan all of the output for any stack traces with errors. 
The generator can keep going after an issue that will cause your app to be unusable!
You can always remove new apps and start again. For existing apps be sure you have committed everything to version 
control and/or made a backup.

**Note:** If you get the error `uninitialized constant Gem::Source (NameError)` that means you have an out of date version of bundler.
Upgrade bundler to the latest with `bundle update --bundler`:
```
cd your_new_app_name/
bundle update --bundler
cd ..
rm -rf your_new_app_name/
```
Then run the `rails new` command again

Notes:
1. You can use another database than postgres with template if you'd like. I prefer it for many reasons but one in particular is it's performance with json data types using jsonb columns
2. You can certainly keep `jbuilder` above if you'd like as well, but I find rendering performance gets to be poor fairly quickly. This generator includes `multi_json` and `oj` for much more performant rendering of JSON from objects and hashes
3. I'm skipping test generation because this template includes and configures rspec instead

## Applying to existing apps

Depending on your app configuration this template may have some conflicts so your mileage may vary, but in general you can use the template with an existing application as well:

You might need to set up your app with postgres and `tailwindcss-rails` yourself first

```
cd path/to/your/existing/app/
bin/rails app:template LOCATION=path/to/this/template.rb
```

# Options

These are asked interactively as you apply the template:

1. Ruby version and optional gemset
    - Creates `.ruby-version` and optionally `.ruby-gemset` fails. (The latter for use with RVM or similar)

# Features and reasoning

## 