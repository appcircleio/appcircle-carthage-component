require 'open3'
require 'pathname'

cartfile_path = ENV["AC_CARTFILE_PATH"] || "./"
repository_path = ENV["AC_REPOSITORY_DIR"]
is_carthage_available = File.exist?("usr/local/bin/carthage")

cartfile_dir_path = repository_path ? (Pathname.new repository_path).join(File.dirname(cartfile_path)) : File.dirname(cartfile_path)
carthage_cartfile_path = File.join(cartfile_dir_path,"Cartfile")
carthage_cartfileresolved_path = File.join(cartfile_dir_path,"Cartfile.resolved")

unless File.exist?(carthage_cartfile_path)
    puts "Cartfile do not exist on #{carthage_cartfile_path}."
    exit 0
end

def runCommand(command)
    puts "@@[command] #{command}"
    unless system(command)
      exit $?.exitstatus
    end
end

if !is_carthage_available
    runCommand("brew install carthage")
end

Dir.chdir(cartfile_dir_path) do
    command = "carthage"
    command += ENV["AC_CARTHAGE_COMMAND"] || "bootstrap"
    command += ENV["AC_CARTHAGE_FLAGS"] || ""
    runCommand(command)
end

exit 0
