require 'rbconfig'
require 'rubygems'
require 'rubygems/specification'
require 'fileutils'

# args/settings
out = ENV["out"]
ruby = ARGV[0]
gem_path = ARGV[1]
bundler_path = ARGV[2]
gems = ARGV[3].split
groups = ARGV[4].split

# generate binstubs
FileUtils.mkdir_p("#{out}/bin")
gems.each do |path|
  next unless File.directory?("#{path}/nix-support/gem-meta")

  name = File.read("#{path}/nix-support/gem-meta/name")
  executables = File.read("#{path}/nix-support/gem-meta/executables")
    .force_encoding('UTF-8').split
  executables.each do |exe|
    File.open("#{out}/bin/#{exe}", "w") do |f|
      f.write(<<-EOF)
#!#{ruby}
#
# This file was generated by RubyNix.
#
# The application '#{exe}' is installed as part of a gem, and
# this file is here to facilitate running it.
#

# Monkey-patch out the check that Bundler performs to determine
# whether the bundler env is writable. It's not writable, even for
# root! And for this use of Bundler, it shouldn't be necessary since
# we're not trying to perform any package management operations, only
# produce a Gem path. Thus, we replace it with a method that will
# always return false, to squelch a warning from Bundler saying that
# sudo may be required.
module Bundler
  class <<self
    def requires_sudo?
      return false
    end
  end
end

Gem.paths = { 'GEM_HOME' => #{gem_path.dump} }

def bundler_setup!
  ENV.delete 'BUNDLE_PATH'
  ENV['BUNDLE_FROZEN'] = '1'
  ENV['BUNDLE_IGNORE_CONFIG'] = '1'

  $LOAD_PATH.unshift #{File.join(bundler_path, "/lib").dump}

  require 'bundler'
  Bundler.setup(#{groups.map(&:dump).join(', ')})
end

if File.exists? "\#{Dir.pwd}/Gemfile"
   bundler_setup!
end

load Gem.bin_path(#{name.dump}, #{exe.dump})
EOF
      FileUtils.chmod("+x", "#{out}/bin/#{exe}")
    end
  end
end
