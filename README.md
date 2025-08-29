# Rails App Template

My preferred starting point for new Rails 8 apps, with some optional configuration for things I sometimes use.

## Standard for this template

These are things I generally always use:

- [tailwindcss](https://tailwindcss.com/) via [tailwindcss-rails](https://github.com/rails/tailwindcss-rails)
- [dotenv](https://github.com/bkeepers/dotenv) for local environment variable configuration
- [Brakeman](https://brakemanscanner.org/) for static code analysis to help detect potential security issues
- [bundler-audit](https://github.com/rubysec/bundler-audit) to ensure you keep your dependencies up to date
- Setup for your service layer of plain Ruby objects in `app/services/` (example below)
- `Dry::Struct` with types for immutable and validated Structs (example below)
- [Annotate](https://github.com/ctran/annotate_models) to add comments to models about the table schema and to routes for quick reference
- `bin/cli` runner for ease of adding a Thor-based CLI instead of rake (example below)
- `bin/ci` runner for running tests with some options (great locally and for a CI server, example below)

## UI Layer Choices

### 1. React + Inertia.js
- [Inertia Rails](https://inertia-rails.dev/) React without needing to build a separate API
- [React](https://react.dev/) Use React to build reusable view components
- [shadcn UI](https://ui.shadcn.com/) UI Component Library
- [storybook.js](https://storybook.js.org/) for creating, testing, and previewing components in your server-rendered views

### 2. ViewComponent + Hotwire
- [Turbo](https://turbo.hotwired.dev/) HTML over the wire / websockets / single-page-app feel with server-rendered views
- [Stimulus](https://stimulus.hotwired.dev/) for extra sprinkles of JavaScript
- [ViewComponent](https://viewcomponent.org/) for organizing your views into reusable components
- [Lookbook](https://lookbook.build/) for creating, testing, and previewing components in your server-rendered views
- [DaisyUI](https://daisyui.com/) UI Component Library (TODO)

## Optional

These are probably app-dependent choices:

- [Auth0](https://auth0.com/docs/quickstart/webapp/rails/01-login) authentication (requires a Third party subscription)
  - Note: first-party authentication is now available as a built-in Rails generator by running `bin/rails generate authentication` after your app is created
- [PostgreSQL](https://www.postgresql.org/) database configuration with UUID as the default primary key type
  - Note: be sure to use `--database=postgresql` with the `rails new` command if you plan to take advantage of this
- [lograge](https://github.com/roidrage/lograge) for single-line production environment request logging
- [Hashdiff](https://github.com/liufengyun/hashdiff) library to compute the smallest difference between two hashes
- [Sidekiq](https://sidekiq.org/) for background jobs
  - Note: Rails 8 has an official database-backed version via [solid-queue](https://github.com/rails/solid_queue) that is configured by default. It is recommended to use a different database instance than your primary data store in production.
- [rspec](https://rspec.info/) for tests with [factory_bot](https://github.com/thoughtbot/factory_bot_rails) for factories instead of fixtures
  - Note: factory_bot is added to the gemfile either way, but is only configured if rspec is selected for now

[Remember to review the recommended new app flags for the `rails new` command](#built-in-to-rails-new)

Quick Summary:

I encourage you to read below for options and explanations of each choice.

# Usage

## New apps

### 1. Install Ruby
I recommend using [mise](https://mise.jdx.dev/) that will manage both your Ruby and Node versions for you.

then, run:
```bash
  mise install ruby@3.4.5
```

### 2. (Optional) Install PostgreSQL

You can do this however you'd like. Using [homebrew](https://brew.sh/) is very popular, but I prefer [Postgres.app](https://postgresapp.com/)
on my Mac as described below.

Regardless of your installation choice, it's best to get it ready before using this template
so that it can automatically set up your databases for you.

If you do elect to use [Postgres.app](https://postgresapp.com/) to make it easier to manage multiple versions
and have a simple GUI interface to start/stop the server(s). The catch is you need to tell bundler where to find the libraries
it needs to install native extensions for the `pg` gem:

1. Install the app from [Postgres.app](https://postgresapp.com/)
2. Create a new server if there isn't already one listed for Postgres 17 (if using another version just update the version number in all steps)
3. Click the button to initialize the database
4. Click the button to start the server
5. Add the following two lines to your `~/.zshrc` or `~/.bash_profile`
   ```
   export PATH="$PATH:/Applications/Postgres.app/Contents/Versions/17/bin"
   export CONFIGURE_ARGS="with-pg-include=/Applications/Postgres.app/Contents/Versions/17/include"
   ```
6. Close and reopen your terminal or otherwise reload the shell profile
7. Now you can run the generator with this template and `bundle install` later

> Be sure to add the flag `--database=postgresql` to the `rails new` command if using this option.

### 3. (Optional) Install Redis
If you want to use [Sidekiq](https://sidekiq.org/) instead of Solid, we'll need redis for ActiveJob and possibly [Turbo Streams](https://turbo.hotwired.dev/handbook/streams) if you use that as well

Using [homebrew](https://brew.sh/)
```bash
  brew install redis
```
```bash
  brew services start redis
```

> Be sure to add the flag `--skip-solid` to the `rails new` command if using this option.

### 4. Install Rails and run the generator

> Note: Remove `mise exec ruby@3.4.5 -- ` from the below if you aren't using mise.

```bash
  mise exec ruby@3.4.5 -- gem install rails
```

Create the app but don't run `bundle install` yet. We'll do that in the next step so that the generator can ask some more interactive questions about dependencies first.
```bash
  mise exec ruby@3.4.5 -- rails new your_app_name_here --skip-bundle [other flags here]
```

#### Example for an Inertia.js + React app:

```bash
  mise exec ruby@3.4.5 -- rails new your_inertia_app_name --database=postgresql --css=tailwind --skip-hotwire --skip-jbuilder --skip-system-test --skip-test --skip-bootsnap --skip-bundle
```

> `--skip-hotwire` is the important flag here for an Inertia.js app. The others can be tailored to your needs. Use `mise exec ruby@3.4.5 -- rails new --help` to see all options.


#### Example for a Hotwire app:

```bash
  mise exec ruby@3.4.5 -- rails new your_inertia_app_name --database=postgresql --css=tailwind --skip-jbuilder --skip-system-test --skip-test --skip-bootsnap --skip-bundle
```

> Similar to the above but with `--skip-hotwire` removed.

### 5. Set up the environment
```bash
  cd your_app_name_here
  mise exec ruby@3.4.5 -- bin/rails app:template LOCATION=path/to/this/local/repo/rails_app_template/environment_config.rb
```

You'll be asked:
1. Do you use mise?
2. Your Ruby version
3. If you want a Ruby gemset file (if you use rvm, for example)
4. Your Node version (if using Inertia.js)

### 6. Apply the full template and run the generators

```bash
  bin/rails app:template LOCATION=path/to/this/local/repo/rails_app_template/template.rb
```

You'll be asked a number of questions, including the optional generators listed at the top of the README (auth, sidekiq, etc).

## Applying to existing apps

Depending on your app configuration this template may have some conflicts so your mileage may vary, but in general you can use the template with an existing application as well by only running step 6 above with `bin/rails app:template LOCATION=path/to/this/local/repo/rails_app_template/template.rb`.

# Choices and reasoning

## Auth0 Authentication (optional)

You'll be asked if you want to add this optional Auth0 support when the generator runs. It is a slightly extended version of 
[this Auth0 guide](https://auth0.com/docs/quickstart/webapp/rails/01-login) to include some controller concerns, 
database migrations, etc.

### Why Auth0?

I won't pretend that Auth0 integrations are perfect but the compelling reasons for me are:
1. Supports many authentication methods with one fairly small integration
2. User management without needing to build it in your app
3. Minimal security footprint to worry about in your app. Auth0 does a lot of this work for you for many auth methods.
1. Minimal personally identifying information in your application
   2. Improves potential [GDPR and CCPA](https://www.okta.com/blog/2021/04/ccpa-vs-gdpr/) compliance
   3. Reduces the risk of security incidents being a major issue for your business and your customers
4. Hosted, configurable user-facing pages
5. Robust API as you scale beyond the out of the box hosted pages
6. Free plan covers most small apps

### Why not Auth0?

1. Paid as you grow (though generally affordable)
2. Vendor-lock for some of your user data making it potentially hard to switch to another provider or bring in house 
Follow my recommendations below for how to extract important user data from Auth0 profiles to reduce this risk. Doing so 
will mean the only real user data you would lose would be passwords, which you can have users re-enter with a forgot password
email flow, though most authentication methods won't have this issue.
3. It can be harder to troubleshoot login issues that users have given that much of the flow is outside of your directly
observable systems.
4. Rails now has a built-in authentication generator via `bin/rails generate authentication`

### Requiring login to your app

To require login for a controller just add `include RequireLogin`:
```ruby
class MyController < ApplicationController
   include RequireLogin
end
```

To secure part of a controller just skip the `before_action` on the actions you don't want to secure:
```ruby
class MyController < ApplicationController
   include RequireLogin
   skip_before_action :require_login!, only: [:not_secured]
   
   def secured
      # code here
   end
   
   def not_secured
      # code here
   end
end
```

**NOTE:** you can also add `include RequireLogin` to your `ApplicationController` to require login site-wide by default
and use `skip_before_action :require_login!` anywhere you don't want to require it. If you do this you _must_ add
`skip_before_action :require_login!` to `app/controllers/auth0_controller.rb` as well.

To get the current logged in user use `current_user` in your controllers or views:
```ruby
class MyController < ApplicationController
   include RequireLogin
   def secured
      current_user
   end
end
```
```erb
<p>The current user's ID is: <%= current_user.id %></p>
```

### Adding a login button

```erb
<%= button_to 'Login', '/auth/auth0', method: :post %>
```

### Adding a logout button

```erb
<%= button_to 'Logout', 'auth/logout', method: :get %>
```

### Auth0 user profile information

To get the current logged in user's Auth0 profile information use `current_user_info` in your controllers or views:
```ruby
class MyController < ApplicationController
   include RequireLogin
   def secured
      pp current_user_info
   end
end
```
```erb
<pre><%= current_user_info.inspect %></pre>
```

This object is an instance of `OpenStruct`.

**WARNING:** The structure and information in this object will be determined by the authentication methods you configure
in Auth0. Make sure all of your use of it are nil-safe and provide alternatives for missing data.

### Database-persisted User model

The user object in your database by default is very minimal:

```ruby
# app/models/user.rb

# == Schema Information
#
# Table name: users
#
#  id         :uuid             not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  auth0_id   :string           not null
#
class User < ApplicationRecord
end
```

Note that we do **NOT** store any real identifying information about the user in the database by default for the following reasons:
1. You should take user privacy and security very seriously and only store absolutely essential information. I don't
know your app and so I don't know how to opt in to the correct data for you.
2. This is a 3rd party auth system I don't which information will or won't be provided based on the authentication 
methods you configure in Auth0.
3. You should consider setting up [Active Record Encryption](https://guides.rubyonrails.org/active_record_encryption.html)
first and limiting the user's plaintext data in the database.
4. We do store the user's information in the session and accessible via `current_user_info` if you need to use it just in the context of your views and interactions
with the user on the website.

If you do decide to store this information in your database I highly recommend taking the following approach that I always
use with 3rd-party data:
1. Store exactly what you are given in the database without manipulation. I find `jsonb` (or `json` if that's not available)
types to be the best here. Auth0 is the source of truth here and you just have to get what you get from it.
2. You can subsequently extract and store derived versions in a separate field, ideally async from the user or in a flow
where they can adjust/verify the information. Otherwise you have a risk that changing data in the 3rd party prevents
signups or logins to your app. Take their data as a default and allow the user to provide a correction when possible.

Here's a simplified example to get you started:

```
bin/rails generation migration add_auth0_profile_to_users
```

```ruby
# db/migrate/[timestamp]_add_auth0_profile_to_users.rb
class AddAuth0ProfileToUsers < ActiveRecord::Migration[7.0]
   def change
      add_column :users, :auth0_profile, :jsonb
   end
end
```

```
bin/rails generation migration add_email_to_users
```

```ruby
# db/migrate/[timestamp]_add_email_to_users.rb
class AddEmailToUsers < ActiveRecord::Migration[7.0]
   def change
      add_column :users, :email, :string, null: true
   end
end
```
Now edit `Auth0Controller`:

```ruby
# app/controllers/auth0_controller.rb
class Auth0Controller < ApplicationController
   def callback
      # Existing code:
      auth_info = request.env['omniauth.auth']
      auth0_id = auth_info['extra']['raw_info']['sub']
      user = User.find_or_create_by!(auth0_id: auth0_id)
      session[:user_id] = user.id
      session[:user_info] = auth_info['extra']['raw_info']
      
      # Add the following:
      user.update!(auth0_profile: session[:user_info])
      # Note that you can also remove the use of `session[:user_info]` here and edit `current_user_info` in ApplicationController
      # to retrieve via `current_user.auth0_profile`, or just remove use of `current_user_info` altogether.
   end
   
   # ... other existing code below ....
end
```

Then after login check for the existence of `current_user.email` and if blank, present the user a form to enter or confirm
their email address with a default value in the text field of the form as `current_user_info.email`. This ensures a one click
confirmation of the email in Auth0 as well as a way to enter it when not given by that particular Auth0 authentication method.
You could also queue a background job that attempts to set it via `user.update!(email: user.auth0_profile['email'])` if email
is fully optional in your app.

## Environment variables

Use of [dotenv](https://github.com/bkeepers/dotenv) lets you more easily configure local environment variables in
`.env` or `.env.development`/`.env.test` files. These are excluded from git by the template.

Note: if you add or change these you must restart your dev server.

## Sidekiq for background jobs (optional)

Background jobs can be configured for [Sidekiq](https://sidekiq.org/) on Redis. The 
[ActiveJob](https://edgeguides.rubyonrails.org/active_job_basics.html) interface is used.

Sidekiq is very stable and uses the highly performant Redis database. It's an excellent and common choice
for background jobs in production. Rails 8 introduces Solid Queue as an alternative if you wish to use a database instead.
Generally I would still recommend Sidekiq unless an additional Redis server is cost-prohibitive or difficult in some way.

**WARNING**: add authorization checks to `config/routes.rb` for the sidekiq web UI at /jobs or remove it from the 
production environment. This isn't configured securely by the template to start because we have no knowledge of your auth
setup, if any.

## Structuring server-side code

### Services/plain old Ruby objects

This template creates an `app/services/` directory for you and sets it up to autoload files here.
While use of this is not enforced in any way it's highly recommended to create service layer for your app out of
plain Ruby objects rather than in any of the standard Rails MVC files. 

It also includes a simple base service class for our other app services to inherit:

```ruby
# app/services/application_service.rb
class ApplicationService

   private
   
   # Set up a tagged logger for each subclass of ApplicationService.
   #
   # Log messages are prefixed with the class name.
   def logger
      @logger ||= Rails.logger.tagged(self.class.name)
   end

end
```

When you create your services inherit from this and add any common code here.

```ruby
# app/services/my_service.rb
class MyService < ApplicationService

   def do_some_work
      logger.info "Some work was done!"
   end

end
```

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

### Avoiding traditional SPA (Single Page Applications)

I don't want to build the view layer twice, once in React and again in as a JSON API. For this reason, I favor [Inertia.js](https://inertia-rails.dev/)
if React is to be used, or [hotwired.dev](https://hotwired.dev/) if not. They are similar in that they keep the React footprint largely to building
client-side view templates. You get the feel of an SPA without the complexity of client-side routing, state management,
etc.

### TailwindCSS

[tailwindcss](https://tailwindcss.com/) is a popular and robust CSS library that allows for rapid and modern styling
directly in your browser. Your app ships with only the CSS you use and nothing more.

### Storybook.js when using Intertia.js with React

> TODO

### ViewComponents + Lookbook when using Hotwire/Turbo

[hotwired.dev](https://hotwired.dev/) might have you fearing a bunch of unstructured and difficult to test ERB templates and that is a fair concern.

[ViewComponent](https://viewcomponent.org/) provided in this template help you to create easy to test and reuse components.
Similar in principle to the component-based structure of React but rendered from the server using Ruby and ERB.

Examples are plentiful on the [ViewComponent](https://viewcomponent.org/) so I'll skip detailed ones here, but this template
ensures:
1. The Ruby files are auto-loaded from `app/components/`
2. Tailwind is configured to bundle all of the classes you use in your ViewComponents

```ruby
# app/components/button_component.rb
class ButtonComponent < ViewComponent::Base
   attr_reader :variant_classes, :type, :disabled
   def initialize(variant: :default, type: "button", disabled: false)
      @type = type
      @disabled = disabled
      if disabled
         @variant_classes = "border-gray-300 bg-white text-gray-400 cursor-not-allowed"
      else
         case variant
         when :primary
            @variant_classes = "border-blue-600 bg-blue-500 hover:bg-blue-600 hover:border-blue-700 text-white"
         else
            @variant_classes = "border-gray-300 bg-white text-gray-700 hover:bg-gray-50"
         end
      end
   end
end
```
```erb
<!-- app/components/button_component.html.erb -->
<button type="<%= type %>" class="<%= variant_classes %> border py-2 px-4 rounded-md"<% if disabled %> disabled="disabled"<% end %>>
  <%= content %>
</button>
```
```erb
<!-- app/views/example/index.html.erb -->
<%= render ButtonComponent.new do %>
  Button Text
<% end %>
```

Test coverage is great for components but they are visual in nature and unit tests aren't a good way to explore what 
these components look like or help develop them. This template includes the [Lookbook](https://lookbook.build/) gem
and also sets it up for auto-loading and bundling any included Tailwind CSS files. 

With [Lookbook](https://lookbook.build/) you can create pretty simple previews of said components for rapid development
and a central UI library to see components already available in your app.

This template also includes a layout to use in our previews to include tailwind and a light gray background for them to stand out against.

```ruby
# spec/components/previews/button_component_preview.rb
class ButtonComponentPreview < ViewComponent::Preview
   layout "view_component_preview"

   # @!group
   def default
      render ButtonComponent.new do
         "Default Button"
      end
   end

   def primary
      render ButtonComponent.new(variant: :primary) do
         "Primary Button"
      end
   end

   def submit
      render ButtonComponent.new(variant: :primary, type: "submit") do
         "Submit Button"
      end
   end

   def disabled
      render ButtonComponent.new(variant: :primary, type: "submit", disabled: true) do
         "Disabled Button"
      end
   end
   # @!endgroup
end
```

Now if you visit http://localhost:3000/lookbook you will a preview of your component in two styles:

![Lookbook Screenshot](screenshots/lookbook_example.png)

**BONUS!** This template includes a slightly more advanced example where button styles are shared between a `Button` and
`ButtonTo`component (the latter being similar in use to the Rails `button_to` helper.) If you include Auth0 support then
the example templates have them in use as well.

## Testing and config for rspec (optional)

I prefer and am more familiar with [rspec](https://rspec.info/) so that is what is used and configured here. It is slower
than minitest and requires learning a DSL but has a number of things built in that I find helpful in large
applications, such as shared examples and human-readable output. Some more features are enumerated here along
with some basic comparisons between the two: https://stackoverflow.com/questions/12470601/minitest-and-rspec

It also includes [factory_bot](https://github.com/thoughtbot/factory_bot_rails) to use simple factory definitions over fixtures.

If you prefer to use [standard Rails tests via minitest](https://guides.rubyonrails.org/testing.html) do not include the `--skip-test`
flag during app generation and update `bin/ci` accordingly to run those instead of `rspec`. It shouldn't hurt anything to have
`rspec` configured but scanning `template.rb` could give you some clues on how to remove it to reduce the app bundle size.

### CI runner

To make it easier to run tests locally and on a CI server you can simply go to the command line and run:

```
bin/ci
```

This will run rspec tests, brakeman, and audit your gems for security updates. Use can use the following to adjust what runs:

```
bin/ci --only brakeman
bin/ci --only bundle-audit
bin/ci --only rspec
bin/ci --no-brakeman
bin/ci --no-bundle-audit
bin/ci --no-rspec
```

To define a new step in the CI flow edit the `STEPS` in `bin/ci`

#### Security features

Using the ci runner will ensure:
- Tests fail if you have a security issue with a gem version in your app, via [bundler-audit](https://github.com/rubysec/bundler-audit)
- Tests fail if you have a potentially security flaw in your app based on static analysis, via [Brakeman](https://brakemanscanner.org/)

## Command line

You may sometimes need to write some task to be executed by the command line. Rather than using `rake`, I much prefer 
to use [thor](http://whatisthor.com/) for powerful options parsing quick documentation.

Included is a `bin/cli` runner to make it super easy to create your app's command line interface. Just add subcommands in
`templates/cli/name_of_your_subcommand.rb` following the example below, which for convenience is also added by the template 
for you to edit/replace/always have on hand as an example:

```ruby
# app/cli/example_subcommand.rb
class ExampleSubcommand < Thor
   desc "example", "Show an example command"
   long_desc <<~LONGDESC
    Show an example command
        
    Pass --verbose to print detailed information as the command runs.
   LONGDESC
   option :verbose, type: :boolean, default: false
   def example
      verbose = options[:verbose]
      puts "Hello, world!#{verbose ? ' Verbose version.': ''}"
   end
end
```

```ruby
# bin/cli

# Add the following above the `def self.exit_on_failure?` definition:

desc "example SUBCOMMAND", "Example commands"
subcommand "example", ExampleSubcommand
```

Now you can run the nicely documented example command with various options from your app's root directory:

Help on available command options:
```
> bin/cli example --help
Commands:
  cli example hello           # Show an example command
  cli example help [COMMAND]  # Describe subcommands or one specific subcommand
```
Run with default options:
```
> bin/cli example hello
Hello, world!
```
Run with specified options:
```
> bin/cli example hello --verbose
Hello, world! Verbose version
```
Run with specified options (negative version):
```
> bin/cli example hello --no-verbose
Hello, world!
```

# Extra configurations

## PostgreSQL optional configuration

If you confirmed you are using PostgreSQL, your  `config/database.yml` was updated to be pre-configured for ENV var use 
(unless you also said no when asked to overwrite the Rails-provided one.)

The variables and defaults are below:
```
RAILS_MAX_THREADS=5
DATABASE_PORT=5432
DATABASE_NAME_DEVELOPMENT=[your_app_name_here]_development
DATABASE_NAME_TEST=[your_app_name_here]_test
DATABASE_NAME_PRODUCTION=[your_app_name_here]_production
DATABASE_USERNAME=[your_app_name_here]
DATABASE_PASSWORD=[your_app_name_here]
```

To adjust these values you can add them to a file named `.env` and reboot your dev server.

Note: if you use something like Heroku this configuration may be ignored in production in favor of a `DATABASE_URL` env var.

A migration was also added to enable UUID primary key support for Postgres. I prefer UUID primary keys for many reasons:
- You don't give away any of your business secrets (for example, incremental integer Order IDs make it really easy for 
competitors to guess how many orders you have processed so far.)
- If you move to multiple apps and databases you are still unlikely to have primary key collision
- It's very hard to move from integer IDs to UUID later

To use them just use the standard ActiveRecord params, for example passing it to `create_table`:

``` ruby
class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users, id: :uuid do |t|
      t.string :auth0_id, null: false
      t.timestamps
    end
  end
end
```

And then later in another model as a forgeign key:

```ruby
class CreateBookmarks < ActiveRecord::Migration[7.0]
  def change
    create_table :bookmarks, id: :uuid do |t|
      t.belongs_to :user, foreign_key: true, type: :uuid
      t.string :url
    end
  end 
end
```

You won't need to add any special params to your models when using `belongs_to` there.

## Production database logs (optional)

[lograge](https://github.com/roidrage/lograge) can be used to ensure production request logs are searchable in a single line 
format. This greatly helps searching and visibility of logs in an app with a lot of activity.
It's almost a necessity on production environments with concurrent requests to ensure that log lines 
from different requests aren't mixed together and nearly impossible to read.

It takes something like:

```
Started GET "/" for 127.0.0.1 at 2012-03-10 14:28:14 +0100
Processing by HomeController#index as HTML
  Rendered text template within layouts/application (0.0ms)
  Rendered layouts/_assets.html.erb (2.0ms)
  Rendered layouts/_top.html.erb (2.6ms)
  Rendered layouts/_about.html.erb (0.3ms)
  Rendered layouts/_google_analytics.html.erb (0.4ms)
Completed 200 OK in 79ms (Views: 78.8ms | ActiveRecord: 0.0ms)
```

And makes it
```
method=GET path=/jobs/833552.json format=json controller=JobsController  action=show status=200 duration=58.33 view=40.43 db=15.26
```

This template configures lograge for production but you can optionally add the same configuration to your development environment as well

# Other suggestions

A few things that don't require any configuration in your app (so aren't in this template) but that I've found useful.

## overmind

You'll need two processes to boot the app for development that are defined in `Procfile.dev`. You can use the popular 
[Foreman](https://github.com/ddollar/foreman) gem for this but my preference is to use the more powerful
[overmind](https://github.com/DarthSim/overmind). 

On a Mac:
```
brew install overmind
cd your_new_app_name/
overmind start -f Procfile.dev
```

# Troubleshooting

## Always scan the generator output for issues!

Be sure to scan all of the output for any stack traces with errors.
The generator can keep going after an issue that will cause your app to be unusable!
You can always remove new apps and start again. For existing apps be sure you have committed everything to version
control and/or made a backup.

# TODO
- [ ] Storybook.js
- [ ] Capybara specs
- [ ] optional bugsnag
- [ ] pagy
- [ ] pagy ViewComponents