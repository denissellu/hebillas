# The Cookies HQ Rails app template
#
# See README.md for details!

######################################
#                                    #
# Auxiliar methods & constants       #
#                                    #
######################################
require 'securerandom'

LATEST_STABLE_RUBY = '2.3.0'.freeze
CURRENT_RUBY       = RUBY_VERSION

QUESTION_PREFIX  = 'Do you want to '.freeze
DEFAULT_YES      = '? [Y/n]'.freeze
DEFAULT_NO       = '? [y/N]'.freeze
POSITIVE_ANSWERS = %w(y Y yes Yes).freeze
NEGATIVE_ANWSERS = %w(n N no No).freeze

def source_paths
  Array(super) + [File.join(File.expand_path(File.dirname(__FILE__)), 'files')]
end

def ask_and_expect_yes(question)
  answer = ask(QUESTION_PREFIX + question + DEFAULT_YES)
  NEGATIVE_ANWSERS.include?(answer) ? false : true
end

def ask_and_expect_no(question)
  answer = ask(QUESTION_PREFIX + question + DEFAULT_NO)
  POSITIVE_ANSWERS.include?(answer) ? true : false
end

def outdated_ruby_version?
  LATEST_STABLE_RUBY.delete('.').to_i > CURRENT_RUBY.delete('.').to_i
end

def add_tmuxinator_file
  current_dir = Dir.pwd + '/'
  create_file ".#{app_name}.tmx.yml" do
    <<-TMUX
# ~/.tmuxinator/#{app_name}.yml

name: #{app_name}
root: #{current_dir}

# Optional tmux socket
# socket_name: foo

# Runs before everything. Use it to start daemons etc.
# pre: sudo /etc/rc.d/mysqld start

# Runs in each window and pane before window/pane specific commands. Useful for setting up interpreter versions.
# pre_window: rbenv shell 2.0.0-p247

# Pass command line options to tmux. Useful for specifying a different tmux.conf.
# tmux_options: -f ~/.tmux.mac.conf

# Change the command to call tmux.  This can be used by derivatives/wrappers like byobu.
# tmux_command: byobu

windows:
  - editor: vim
  - server: heroku local
  - console: bundle exec rails c
  - guard: bundle exec guard
  - terminal:
    TMUX
  end
end

def gitignore_tmuxinator
  insert_into_file ".gitignore", after: "/.env\n" do
    <<-GITIGNORE

# Ignore Tmuxinator file
.#{app_name}.tmx.yml
    GITIGNORE
  end
end

def bootstrap_js_imports
  <<-BSJSIMPORTS

// Check which bootstrap modules to add here
// https://github.com/twbs/bootstrap-sass/tree/master/assets/javascripts/bootstrap

//= require bootstrap/affix
//= require bootstrap/alert
//= require bootstrap/button
//= require bootstrap/carousel
//= require bootstrap/collapse
//= require bootstrap/dropdown
//= require bootstrap/modal
//= require bootstrap/tooltip
//= require bootstrap/popover
//= require bootstrap/scrollspy
//= require bootstrap/tab
//= require bootstrap/transition

  BSJSIMPORTS
end

def bootstrap_message
  <<-BOOTSTRAPMESSAGE

We've imported all of Bootstrap. If you won't be using all of its features and to improve load time and performance, check:

* app/assets/stylesheets/_bootstrap-custom.scss
* app/assets/javascripts/application.js

There you'll be able to comment out or remove unneded CSS/JSmodules

  BOOTSTRAPMESSAGE
end

######################################
#                                    #
# Prompt the user for options        #
#                                    #
######################################
puts "\n================================== HEBILLAS ===================================\n"
say("Stopping spring to avoid problems during installation", "\e[33m")
run "bundle exec spring stop"

use_devise = ask_and_expect_yes("install Devise")

if use_devise
  generate_devise_user  = ask_and_expect_yes('create a Devise User Class')
  generate_devise_views = ask_and_expect_yes("generate Devise views")
  use_active_admin      = ask_and_expect_yes("install Active Admin")
end

use_roadie             = ask_and_expect_yes("install Roadie")
use_paperclip          = ask_and_expect_yes("install Paperclip")
use_vcr                = ask_and_expect_yes("install VCR")
use_guard_rspec        = ask_and_expect_yes("install Guard-Rspec")
use_font_awesome       = ask_and_expect_yes("install Font Awesome")
switch_to_haml         = ask_and_expect_yes("use HAML instead of ERB")
switch_to_bootstrap    = ask_and_expect_yes("remove Bourbon/Neat and use Bootstrap")
switch_to_coffeescript = ask_and_expect_yes("remove EC6 and install CoffeeScript")
create_tmuxinator_file = ask_and_expect_no("create a tmuxinator file")

######################################
#                                    #
# Gemfile manipulation               #
#                                    #
######################################

if switch_to_coffeescript
 gsub_file('Gemfile', /^gem "sprockets"$/, '')
 gsub_file('Gemfile', /^gem "sprockets-es6"$/, '')
 gem "coffee-rails"
end

if use_devise
  if use_active_admin
    gem 'devise', '~> 3.5', '>= 3.5.10'
  else
    gem 'devise'
  end
end

gem 'haml-rails' if switch_to_haml

# Remove bourbon/neat/refills
if switch_to_bootstrap
  gsub_file('Gemfile', /^gem "bourbon", "5.0.0.beta.3"$/, '')
  gsub_file('Gemfile', /^gem "neat", "~> 1.7.0"$/, '')
  gsub_file('Gemfile', /^gem "refills"/, '')
  gem 'bootstrap-sass'
end

gem 'activeadmin', '~> 1.0.0.pre2' if use_active_admin
gem 'paperclip' if use_paperclip
gem 'roadie' if use_roadie
gem 'font-awesome-rails' if use_font_awesome

gem_group :development do
  gem 'mailcatcher', require: false
  gem 'html2haml', require: false if switch_to_haml
  gem 'guard-livereload', require: false
  gem 'brakeman', require: false
end

gem_group :development, :test do
  gem 'guard-rspec', require: false if use_guard_rspec
  gem 'faker'
end

gem_group :test do
  gem 'capybara'
  gem 'capybara-email'
  gem 'email_spec'
  gem 'vcr' if use_vcr
end

######################################
#                                    #
# Gem installation                   #
#                                    #
######################################
run 'bundle install'

######################################
#                                    #
# Modification and addition of files #
#                                    #
######################################
run "rm -rf test/"

#############
# Gitignore #
#############
insert_into_file ".gitignore", after: "/tmp/*\n" do
<<-GITIGNORE
/.env
GITIGNORE
end

##############
# Tmuxinator #
##############
if create_tmuxinator_file
  add_tmuxinator_file
  run "mkdir -p ~/.tmuxinator/"
  run "ln .#{app_name}.tmx.yml ~/.tmuxinator/#{app_name}.yml"
  gitignore_tmuxinator
end

inside "app" do
  inside "assets" do
    inside "fonts" do
      create_file ".keep", ""
    end

    inside "stylesheets" do
      if switch_to_bootstrap
        remove_file "refills/_flashes.scss"
        remove_file "refills"
        remove_file "application.css"
        remove_file "application.scss"
        copy_file   "application.scss"
        copy_file   "_variables.scss"
        copy_file   "_bootstrap-variables-overrides.scss"
        copy_file   "_bootstrap-custom.scss"
        create_file "_base.scss",   ""
        create_file "_layout.scss", ""
        create_file "_module.scss", ""
        create_file "_state.scss",  ""
        create_file "_theme.scss",  ""
        copy_file   "email.scss"
        insert_into_file 'application.scss', "\n@import \'font-awesome\';\n", after: "@import \'theme\';\n" if use_font_awesome
      else
        insert_into_file 'application.css', "*= require font-awesome\n", after: "*= require_self\n" if use_font_awesome
      end
    end

    if switch_to_bootstrap
      inside "javascripts" do
        insert_into_file 'application.js', bootstrap_js_imports, after: "//= require jquery_ujs\n"
      end
    end
  end

  inside 'services' do
    create_file '.keep', ''
  end

  inside "views" do
    inside 'application' do
      run "for file in *.erb; do html2haml -e $file ${file%erb}haml > /dev/null 2>&1 && rm $file; done" if switch_to_haml
    end

    inside "layouts" do
      if switch_to_haml
        run "html2haml -e application.html.erb application.html.haml > /dev/null 2>&1 && rm application.html.erb"
        copy_file "email.html.haml" if use_roadie
      else
        copy_file "email.html.erb" if use_roadie
      end
    end
  end
end

inside "config" do
  insert_into_file 'application.rb', after: "config.active_job.queue_adapter = :delayed_job\n" do
    <<-APP

    config.assets.precompile += %w( .svg .eot .woff .ttf email.css )
    config.assets.paths << Rails.root.join('app', 'assets', 'fonts')
    APP
  end

  inside "environments" do
    insert_into_file 'development.rb', after: "config.action_mailer.default_url_options = { host: \"localhost:3000\" }\n" do
      <<-DEV

  # Setup for Mailcatcher, if present
  if `which mailcatcher`.length > 0
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = { address: "localhost", port: 1025 }
  end

  # Specify locations for mails previews
  config.action_mailer.preview_path = "spec/mailers/previews"

  # Use email template for emails except on devise mails sent for admin users
  config.to_prepare do
    ActionMailer::Base.layout proc { |mailer|
      if mailer.is_a?(Devise::Mailer) && mailer.scope_name == :admin_user
        nil
      else
        "email"
      end
    }
  end

      DEV
    end
  end
end

#####################
# SECRET KEY CONFIG #
#####################

secret_key = SecureRandom.hex(64)
insert_into_file '.env',
                 "SECRET_KEY_BASE=#{secret_key}",
                 after: "WEB_CONCURRENCY=1\n"

######################################
#                                    #
# Running installed gems generators  #
#                                    #
######################################
if use_devise
  generate "devise:install"
  generate "devise user"  if generate_devise_user

  if generate_devise_views
    generate "devise:views"
    run "for file in app/views/devise/**/*.erb; do html2haml -e $file ${file%erb}haml > /dev/null 2>&1 && rm $file; done" if switch_to_haml
  end
end

generate "simple_form:install --bootstrap" if switch_to_bootstrap
generate "active_admin:install" if use_active_admin
run "bundle exec guard init livereload"
run "bundle exec guard init rspec" if use_guard_rspec

################
# Rspec Config #
################

inside "spec" do
  inside "acceptance" do
    copy_file "routes_acceptance_spec.rb"
  end

  inside "support" do
    copy_file "devise.rb" if use_devise
    copy_file "controller_macros.rb" if use_devise
    copy_file "vcr.rb" if use_vcr
    copy_file "email_spec.rb"
    copy_file "paperclip.rb" if use_paperclip
    copy_file "factory_girl.rb"
  end
end

inside "spec" do
  insert_into_file "rails_helper.rb", after: "require \"rspec/rails\"\n" do
    text =  "require 'capybara/rails'\n"
    text << "require 'capybara/rspec'\n"
    text << "require 'capybara/email/rspec'\n"
    text << "require 'database_cleaner'\n"
    text << "require 'email_spec'\n"
    text << "require 'shoulda/matchers'\n"
    text << "require 'paperclip/matchers'\n" if use_paperclip
    text << "require 'vcr'\n" if use_vcr
    text << "require 'devise'\n" if use_vcr
    text
  end

  insert_into_file "rails_helper.rb", after: "ActiveRecord::Migration.maintain_test_schema!\n" do
    <<-RSPEC
        Capybara.javascript_driver = :webkit
        Faker::Config.locale = :"en-gb"
    RSPEC
  end

  inside "mailers" do
    inside "previews" do
      create_file ".keep", ""
    end
  end

  inside "services" do
    create_file ".keep", ""
  end
end

######################################
#                                    #
# Overriding default bundle install  #
#                                    #
######################################
def run_bundle ; end

######################################
#                                    #
# Initial commit of the app          #
#                                    #
######################################

# We remove this until we can get the after_bundler hook working on rails 4.2
# See: https://github.com/rails/rails/issues/16292
# git :init
# git add: "."
# git commit: "-a -m 'Initial commit'"

######################################
#                                    #
# Info for the user                  #
#                                    #
######################################

say("\nPlease note that you're using ruby #{CURRENT_RUBY}. Latest ruby version is #{LATEST_STABLE_RUBY}. Should you want to change it, please amend the Gemfile accordingly.\n", "\e[33m") if outdated_ruby_version?

migrate_database = ask_and_expect_no("migrate the database now")
run "bundle exec rake db:migrate" if migrate_database

if use_active_admin
  say("\nWe have installed Active Admin. To have a default AdminUser created, we need to seed the database.")
  seed_db = ask_and_expect_no('seed the database now')

  if seed_db && migrate_database
    run "bundle exec rake db:seed"
    say("\nWe have created a default AdminUsers with credentials:\n\tEmail: admin@example.com\n\tPassword: password\n\n", "\e[33m")
  end
end

if migrate_database
  run "bundle exec rake spec"
  say("\nWhat you see above is the first failing test of the project. It fails because you have no routes defined, so the root_path is not visitable. This means everything is set and you can start working (perhaps in making this test pass).\n\n", "\e[33m")
end

if switch_to_bootstrap
  say(bootstrap_message, "\e[33m")
end

say("Restarting Spring\n", "\e[33m")
run "bundle exec spring binstub --all"
