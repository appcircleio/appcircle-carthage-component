require 'open3'
require 'pathname'

CARTHAGE_EXECUTABLE_PATH = "/usr/local/bin/carthage"
DEFAULT_CARTFILE_PATH = "./"
DEFAULT_CARTHAGE_COMMAND = "bootstrap"

def carthage_available?(executable_path = CARTHAGE_EXECUTABLE_PATH)
    File.exist?(executable_path)
end

def cartfile_directory(cartfile_path, repository_path = nil)
    repository_path ? (Pathname.new repository_path).join(File.dirname(cartfile_path)).to_s : File.dirname(cartfile_path)
end

def carthage_command(command = nil, flags = nil)
    cmd = "carthage "
    cmd += command || DEFAULT_CARTHAGE_COMMAND
    cmd += " "
    cmd += flags || ""
    cmd
end

def runCommand(command)
    puts "@@[command] #{command}"
    unless system(command)
      exit $?.exitstatus
    end
end

if __FILE__ == $PROGRAM_NAME
    cartfile_path = ENV["AC_CARTFILE_PATH"] || DEFAULT_CARTFILE_PATH
    repository_path = ENV["AC_REPOSITORY_DIR"]

    cartfile_dir_path = cartfile_directory(cartfile_path, repository_path)
    carthage_cartfile_path = File.join(cartfile_dir_path,"Cartfile")

    unless File.exist?(carthage_cartfile_path)
        puts "Cartfile do not exist on #{carthage_cartfile_path}."
        exit 0
    end

    if !carthage_available?
        runCommand("brew install carthage")
    end

    Dir.chdir(cartfile_dir_path) do
        runCommand(carthage_command(ENV["AC_CARTHAGE_COMMAND"], ENV["AC_CARTHAGE_FLAGS"]))
    end

    exit 0
end
