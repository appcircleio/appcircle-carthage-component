# frozen_string_literal: true

require 'English'
require 'open3'
require 'pathname'

CARTHAGE_EXECUTABLE_PATH = '/usr/local/bin/carthage'
DEFAULT_CARTFILE_PATH    = './'
DEFAULT_CARTHAGE_COMMAND = 'bootstrap'

# Returns nil for both unset and empty environment variables so that callers can
# fall back to their defaults with a plain `||`.
def get_env_variable(key)
  ENV[key].nil? || ENV[key] == '' ? nil : ENV[key]
end

def carthage_available?(executable_path = CARTHAGE_EXECUTABLE_PATH)
  File.exist?(executable_path)
end

# Resolves the directory that holds the Cartfile. AC_CARTFILE_PATH is relative to
# AC_REPOSITORY_DIR when that variable is set.
def cartfile_directory(cartfile_path, repository_path = nil)
  if cartfile_path.nil? || cartfile_path.to_s.empty?
    raise 'Cartfile path is empty. Leave AC_CARTFILE_PATH unset to use the default "./".'
  end

  relative_dir = File.dirname(cartfile_path)
  return relative_dir if repository_path.nil? || repository_path.to_s.empty?

  Pathname.new(repository_path).join(relative_dir).to_s
end

def carthage_command(command = nil, flags = nil)
  cmd = 'carthage '
  cmd += command.nil? || command.to_s.empty? ? DEFAULT_CARTHAGE_COMMAND : command
  cmd += ' '
  cmd += flags.to_s
  cmd
end

def runCommand(command)
  raise 'runCommand was called without a command.' if command.nil? || command.to_s.strip.empty?

  puts "@@[command] #{command}"
  return if system(command)

  exit($CHILD_STATUS&.exitstatus || 1)
end

if __FILE__ == $PROGRAM_NAME
  cartfile_path   = get_env_variable('AC_CARTFILE_PATH') || DEFAULT_CARTFILE_PATH
  repository_path = get_env_variable('AC_REPOSITORY_DIR')

  cartfile_dir_path      = cartfile_directory(cartfile_path, repository_path)
  carthage_cartfile_path = File.join(cartfile_dir_path, 'Cartfile')

  unless File.exist?(carthage_cartfile_path)
    puts "Cartfile do not exist on #{carthage_cartfile_path}."
    exit 0
  end

  runCommand('brew install carthage') unless carthage_available?

  Dir.chdir(cartfile_dir_path) do
    runCommand(
      carthage_command(
        get_env_variable('AC_CARTHAGE_COMMAND'),
        get_env_variable('AC_CARTHAGE_FLAGS')
      )
    )
  end

  exit 0
end
