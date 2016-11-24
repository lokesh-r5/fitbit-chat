if RUBY_VERSION < '1.9.0' # this is a string comparison, but it should work for any old ruby version
  $stderr.puts "Heroku Toolbelt requires Ruby 1.9+."
  exit 1
end

Encoding.default_internal, Encoding.default_external = ['utf-8'] * 2
load('heroku/helpers.rb') # reload helpers after possible inject_loadpath
load('heroku/updater.rb') # reload updater after possible inject_loadpath

require 'heroku'
require 'heroku/jsplugin'
require 'heroku/config'
require 'heroku/analytics'
require 'heroku/rollbar'
require 'json'

class Heroku::CLI

  extend Heroku::Helpers

  def self.start(*args)
    $stdin.sync = true if $stdin.isatty
    $stdout.sync = true if $stdout.isatty
    Heroku::Updater.warn_if_updating
    command = args.shift.strip rescue "help"
    Heroku::Analytics.skip_analytics # just sets the config for the analytics
    Heroku::JSPlugin.setup
    Heroku::JSPlugin.try_takeover(command, args)
    require 'heroku/command'
    Heroku::Git.check_git_version
    Heroku::Command.load
    Heroku::Analytics.record(command)
    warn_if_ruby_plugin(command)
    Heroku::Command.run(command, args)
    Heroku::Updater.autoupdate
  rescue Errno::EPIPE => e
    error(e.message)
  rescue Interrupt => e
    `stty icanon echo` unless running_on_windows?
    if ENV["HEROKU_DEBUG"]
      styled_error(e)
    else
      error("Command cancelled.", false)
    end
  rescue => error
    styled_error(error)
    exit(1)
  end

  def self.warn_if_ruby_plugin(command)
    c = Heroku::Command.parse(command)
    if c && c[:plugin]
      $stderr.puts "WARNING: #{c[:plugin]} is a deprecated Ruby plugin"
      $stderr.puts "WARNING: Check to see if there is a version of this plugin using the new Node.js Heroku CLI"
    end
  end
end
