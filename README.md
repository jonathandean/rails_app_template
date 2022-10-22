# Rails App Template

My preferred starting point for new Rails 7 apps.

# Usage

## New apps

### Install Ruby
First, install the latest version of Ruby. At the moment that is 3.1.2. I recommend using RVM, rbenv, or similar and not using your system Ruby.

### Ensure you have the latest version of bundler

See instructions at [bundler.io](https://bundler.io)

If you get the error `uninitialized constant Gem::Source (NameError)` see the troubleshooting section at the end of the README

### Run the new app generator
```
gem install rails
rails new your_new_app_name --database=postgresql --skip-jbuilder --skip-test -skip-bootsnap --css=tailwind -m path/to/this/template.rb
```

## Applying to existing apps

Depending on your app configuration this template may have some conflicts so your mileage may vary, but in general you can use the template with an existing application as well:

(You might need to set up your app with postgres and `tailwindcss-rails` yourself first)

```
cd path/to/your/existing/app/
bin/rails app:template LOCATION=path/to/this/template.rb
```

# Options

## Non-template flags passed to the new app generator

### --database=postgresql 

You can use another database than postgres with template if you'd like. 
I prefer it for many reasons but one in particular is it's performance with json data types using jsonb columns

### --skip-jbuilder 

You can certainly keep `jbuilder` above if you'd like as well, but I find rendering performance gets to be poor fairly quickly. 
This template includes `multi_json` and `oj` for much more performant rendering of JSON from objects and hashes

### --skip-test 

I'm skipping test generation because this template includes and configures `rspec` instead

### -skip-bootsnap 

You can keep `bootsnap` if you'd like as well. I just don't find I get much value from it and occasionally the "magic" of 
it can cause some confusion in debugging.

### --css=tailwind

Some features of this template expect tailwindcss so if you want to use a different CSS library you'll have to scan 
through the app and remove some tailwind configuration.

## Interactive options

These are asked interactively as you apply the template:

1. Ruby version and optional gemset
    - Creates `.ruby-version` and optionally `.ruby-gemset` files. (The latter for use with RVM or similar)
2. Whether or not you want to automatically commit the empty app when the generator is done (`git init` is run regardless)

# Choices and reasoning

## Structuring server-side code

### Services/plain old Ruby objects

This template creates an `app/services/` directory for you and sets it up to autoload files here.
While use of this is not enforced in any way it's highly recommended to create service layer for your app out of
plain Ruby objects rather than in any of the standard Rails MVC files. 

Most of your app should be plain Ruby objects containing your business logic.
Rails Models should define your database models but not the logic for how they are used.
Rails Controllers should essentially just handle taking parameters to send to your service layer, handle some routing logic,
and set up the response to the user.

This is a large topic on it's own so rather than explain it all here I recommend starting with this talk from
Dave Copeland: https://www.youtube.com/watch?v=CRboMkFdZfg&ab_channel=RubyCentral

### Non-model objects/Structs

Sometimes you need an object that isn't backed by a database. You can use [ActiveModel](https://guides.rubyonrails.org/active_model_basics.html) 
for this if you need some of the features it gives, such as the validation API or other goodies.

However, this approach is not well suited for a lot of circumstances. In particular, let's say you are representing data
from a 3rd party system. The appropriate approach here is to load an immutable version of that data since it is controlled
from a source outside of your application. You also want to make sure you know what structure and format that data is in
and raise an error if anything unexpected happens so that you can triage it proactively.

I like to use the `dry-configurable`, `dry-struct`, and `dry-validation` gems for this.

Example use:

```ruby
# app/models/external_user.rb
class ExternalUser < Dry::Struct
  transform_keys(&:to_sum)
  
  attribute :name, Types::String.optional
  attribute :email, Types::String

  def to_s
    puts "#{self.email} (#{self.name || 'no name given'})"
  end
end
```

```ruby
external_user = ExternalUser.new(email: "jon@example.com", name: "Jon")
puts external_user
# output:
# jon@example.com (Jon)

external_user = ExternalUser.new(email: "jon@example.com")
puts external_user
# output:
# jon@example.com (no name given)


external_user = ExternalUser.new(name: "Jon")
# exception:
# (Dry::Types::MissingKeyError)
# :email is missing in Hash Input
# 
external_user = ExternalUser.new(name: 123.0)
# exception:
# (Dry::Struct::Error)
# 123.0 (Float) has invalid type for :name violates constraints (type?(String, 123.0)failed)
```

## UI

### Turbo + Stimulus

### TailwindCSS

### ViewComponents + Lookbook

## Testing

## Command line

# Troubleshooting

## Always scan the generator output for issues!

Be sure to scan all of the output for any stack traces with errors.
The generator can keep going after an issue that will cause your app to be unusable!
You can always remove new apps and start again. For existing apps be sure you have committed everything to version
control and/or made a backup.

## uninitialized constant Gem::Source (NameError)

The active version of bundler is not the latest and you need to upgrade. 

One quick and cheap way to do this if you're setting up a new app is:

```
cd your_new_app_name/
bundle update --bundler
cd ..
rm -rf your_new_app_name/
```
Then run the `rails new` command again

For existing apps and other setups find instructions at [bundler.io](https://bundler.io)