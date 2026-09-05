# frozen_string_literal: true

# ─── Coverage (must start before loading main.rb) ─────────────────────────────
unless defined?(Coverage) && Coverage.running?
  require 'coverage'
  Coverage.start
end

# ─── Dependencies ─────────────────────────────────────────────────────────────
require 'rspec'
require 'rspec/core/formatters/base_formatter'
require 'open3'
require 'fileutils'
require 'tmpdir'
require 'stringio'

MAIN_RB      = File.expand_path('../main.rb', __dir__)
PROJECT_ROOT = File.dirname(MAIN_RB)

require MAIN_RB

# ─── Custom Formatter ─────────────────────────────────────────────────────────
class ReadableFormatter < RSpec::Core::Formatters::BaseFormatter
  RSpec::Core::Formatters.register(
    self,
    :example_group_started,
    :example_group_finished,
    :example_passed,
    :example_failed,
    :example_pending,
    :dump_summary
  )

  PASS  = "\e[32;1m[ PASS ]\e[0m"
  FAIL  = "\e[31;1m[ FAIL ]\e[0m"
  ERROR = "\e[31;1m[ERROR ]\e[0m"
  SKIP  = "\e[33;1m[ SKIP ]\e[0m"

  DIVIDER     = "\e[90m#{'─' * 72}\e[0m"
  DIVIDER_FAT = "\e[90m#{'═' * 72}\e[0m"

  def initialize(output)
    super
    @depth    = 0
    @failures = []
    @counts   = { passed: 0, failed: 0, pending: 0 }
  end

  # Top-level describe groups cycle through distinct colors
  GROUP_COLORS = [
    "\e[34;1m",  # bold blue
    "\e[35;1m",  # bold magenta
    "\e[36;1m",  # bold cyan
    "\e[33;1m"   # bold yellow
  ].freeze

  def example_group_started(notification)
    group = notification.group
    if group.parent_groups.size <= 1
      output.puts if @depth.zero?
      color = GROUP_COLORS[@depth % GROUP_COLORS.size]
      output.puts "  #{color}#{group.description}\e[0m"
    else
      output.puts "    #{'  ' * (@depth - 1)}\e[90m▸ \e[0m\e[37m#{group.description}\e[0m"
    end
    @depth += 1
  end

  def example_group_finished(_notification)
    @depth -= 1 if @depth > 0
  end

  def example_passed(notification)
    @counts[:passed] += 1
    print_example(PASS, notification.example)
  end

  def example_failed(notification)
    @counts[:failed] += 1
    ex    = notification.example
    exc   = ex.execution_result.exception
    badge = exc.is_a?(RSpec::Expectations::ExpectationNotMetError) ? FAIL : ERROR
    print_example(badge, ex)
    @failures << notification
  end

  def example_pending(notification)
    @counts[:pending] += 1
    ex = notification.example
    output.puts "    #{'  ' * [0, @depth - 1].max}#{SKIP}  #{ex.description}"
  end

  def dump_summary(notification)
    output.puts
    output.puts DIVIDER_FAT

    unless @failures.empty?
      output.puts "\n  \e[1;31mFailures:\e[0m\n"
      @failures.each_with_index do |n, i|
        ex  = n.example
        exc = ex.execution_result.exception
        output.puts "  \e[1m#{i + 1}) #{ex.full_description}\e[0m"
        exc.message.lines.first(6).each do |line|
          output.puts "     \e[31m#{line.rstrip}\e[0m"
        end
        output.puts "     \e[90m# #{ex.location}\e[0m"
        output.puts
      end
      output.puts DIVIDER
    end

    t   = notification.examples.size
    p   = @counts[:passed]
    f   = @counts[:failed]
    s   = @counts[:pending]
    sec = format('%.3fs', notification.duration)

    parts = ["\e[32m#{p} passed\e[0m"]
    parts << "\e[31m#{f} failed\e[0m"  if f > 0
    parts << "\e[33m#{s} pending\e[0m" if s > 0

    overall = f.zero? ? "\e[32;1m✔  All #{t} tests passed\e[0m" : "\e[31;1m✖  #{f} of #{t} tests failed\e[0m"
    output.puts "\n  #{overall}"
    output.puts "  #{parts.join('  |  ')}  \e[90m(#{sec})\e[0m"
    output.puts DIVIDER_FAT
  end

  private

  def print_example(badge, example)
    indent = '  ' * [0, @depth - 1].max
    time   = format('%.3fs', example.execution_result.run_time)
    output.puts "    #{indent}#{badge}  #{example.description}  \e[90m(#{time})\e[0m"
  end
end

# ─── Helpers ──────────────────────────────────────────────────────────────────

# Writes stub `carthage` / `brew` executables so the subprocess tests never touch
# the real toolchain. The stubs record their arguments (and cwd) into files.
def build_fake_bin(dir, carthage_exit_status: 0)
  FileUtils.mkdir_p(dir)

  carthage = File.join(dir, 'carthage')
  File.write(carthage, <<~SH)
    #!/bin/sh
    printf '%s\\n' "$*" >> "$AC_TEST_CARTHAGE_ARGS_FILE"
    pwd >> "$AC_TEST_CARTHAGE_CWD_FILE"
    exit #{carthage_exit_status}
  SH
  FileUtils.chmod(0o755, carthage)

  brew = File.join(dir, 'brew')
  File.write(brew, <<~SH)
    #!/bin/sh
    printf '%s\\n' "$*" >> "$AC_TEST_BREW_ARGS_FILE"
    exit 0
  SH
  FileUtils.chmod(0o755, brew)

  dir
end

# Runs main.rb in a subprocess. Keys left at nil are unset in the child process,
# so a "missing variable" case never inherits a value from the test runner.
def run_main(env = {}, chdir: nil, path_prefix: nil)
  spawn_env = {
    'AC_CARTFILE_PATH'    => nil,
    'AC_REPOSITORY_DIR'   => nil,
    'AC_CARTHAGE_COMMAND' => nil,
    'AC_CARTHAGE_FLAGS'   => nil
  }.merge(env)
  spawn_env['PATH'] = "#{path_prefix}:#{ENV.fetch('PATH', '')}" if path_prefix

  options = {}
  options[:chdir] = chdir if chdir
  Open3.capture3(spawn_env, "ruby #{MAIN_RB}", **options)
end

# ─── Tests ────────────────────────────────────────────────────────────────────

RSpec.describe 'Required libraries' do
  %w[open3 pathname].each do |lib|
    it "loads '#{lib}'" do
      expect { require lib }.not_to raise_error
    end
  end
end

# ─────────────────────────────────────────────────────────────────────────────

RSpec.describe '#carthage_available?' do
  let(:tmpdir) { Dir.mktmpdir('carthage_bin') }
  after { FileUtils.rm_rf(tmpdir) }

  it 'returns true when the executable exists' do
    path = File.join(tmpdir, 'carthage')
    FileUtils.touch(path)
    expect(carthage_available?(path)).to be(true)
  end

  it 'returns false when the executable is missing' do
    expect(carthage_available?(File.join(tmpdir, 'nope'))).to be(false)
  end

  it 'defaults to the Homebrew install location' do
    expect(CARTHAGE_EXECUTABLE_PATH).to eq('/usr/local/bin/carthage')
    expect(File).to receive(:exist?).with(CARTHAGE_EXECUTABLE_PATH).and_return(true)
    expect(carthage_available?).to be(true)
  end
end

# ─────────────────────────────────────────────────────────────────────────────

RSpec.describe '#cartfile_directory' do
  context 'without AC_REPOSITORY_DIR' do
    it 'resolves the default "./" to the current directory' do
      expect(cartfile_directory('./')).to eq('.')
    end

    it 'strips the file name from a nested path' do
      expect(cartfile_directory('sub/Cartfile')).to eq('sub')
    end

    it 'resolves an empty repository path to the same relative lookup' do
      expect(cartfile_directory('sub/Cartfile', '')).to eq('sub')
    end

    it 'resolves a nil repository path to a relative lookup' do
      expect(cartfile_directory('sub/Cartfile', nil)).to eq('sub')
    end
  end

  context 'with AC_REPOSITORY_DIR' do
    it 'returns the repository directory for the default "./"' do
      expect(cartfile_directory('./', '/repo')).to eq('/repo')
    end

    it 'joins a nested Cartfile path onto the repository directory' do
      expect(cartfile_directory('sub/Cartfile', '/repo')).to eq('/repo/sub')
    end

    it 'keeps an absolute Cartfile path absolute' do
      expect(cartfile_directory('/elsewhere/Cartfile', '/repo')).to eq('/elsewhere')
    end
  end

  context 'with an unusable Cartfile path' do
    it 'raises TypeError when the path is nil' do
      expect { cartfile_directory(nil) }.to raise_error(TypeError)
    end

    it 'resolves an empty path to the current directory' do
      expect(cartfile_directory('')).to eq('.')
      expect(cartfile_directory('', '/repo')).to eq('/repo')
    end
  end
end

# ─────────────────────────────────────────────────────────────────────────────

RSpec.describe '#carthage_command' do
  it 'falls back to bootstrap when no command is given' do
    expect(carthage_command).to eq('carthage bootstrap ')
  end

  # Only nil triggers the default, so an empty AC_CARTHAGE_COMMAND leaves carthage
  # without a subcommand. Asserted to lock the current behaviour in place.
  it 'does not fall back to bootstrap when the command is an empty string' do
    expect(carthage_command('', '')).to eq('carthage  ')
  end

  it 'uses the given command' do
    expect(carthage_command('update')).to eq('carthage update ')
  end

  it 'appends the given flags' do
    expect(carthage_command('bootstrap', '--platform iOS --use-xcframeworks'))
      .to eq('carthage bootstrap --platform iOS --use-xcframeworks')
  end

  it 'appends nothing when flags are nil' do
    expect(carthage_command('update', nil)).to eq('carthage update ')
  end

  it 'exposes bootstrap as the documented default' do
    expect(DEFAULT_CARTHAGE_COMMAND).to eq('bootstrap')
  end
end

# ─────────────────────────────────────────────────────────────────────────────

RSpec.describe '#runCommand' do
  before { allow($stdout).to receive(:puts) }

  it 'returns without raising when the command succeeds' do
    expect { runCommand('true') }.not_to raise_error
  end

  it 'echoes the command it is about to run' do
    runCommand('true')
    expect($stdout).to have_received(:puts).with('@@[command] true')
  end

  it 'exits with the exit status of a failing command' do
    expect { runCommand('sh -c "exit 3"') }
      .to raise_error(SystemExit) { |e| expect(e.status).to eq(3) }
  end

  it 'exits when the command cannot be executed at all' do
    expect { runCommand('ac_test_command_that_does_not_exist') }.to raise_error(SystemExit)
  end

  it 'raises TypeError when the command is nil' do
    expect { runCommand(nil) }.to raise_error(TypeError)
  end

  it 'exits 127 when the command is an empty string' do
    expect { runCommand('') }
      .to raise_error(SystemExit) { |e| expect(e.status).to eq(127) }
  end
end

# ─────────────────────────────────────────────────────────────────────────────

RSpec.describe 'ENV validation: Cartfile resolution' do
  let(:workdir) { Dir.mktmpdir('carthage_env') }
  after { FileUtils.rm_rf(workdir) }

  context 'AC_CARTFILE_PATH' do
    it 'defaults to "./" when missing' do
      out, _err, status = run_main({}, chdir: workdir)
      expect(status.exitstatus).to eq(0)
      expect(out).to include('Cartfile do not exist on ./Cartfile.')
    end

    it 'defaults to "./" when set to an empty string' do
      out, _err, status = run_main({ 'AC_CARTFILE_PATH' => '' }, chdir: workdir)
      expect(status.exitstatus).to eq(0)
      expect(out).to include('Cartfile do not exist on ./Cartfile.')
    end

    it 'is resolved relative to the working directory when set' do
      out, _err, status = run_main({ 'AC_CARTFILE_PATH' => 'sub/Cartfile' }, chdir: workdir)
      expect(status.exitstatus).to eq(0)
      expect(out).to include('Cartfile do not exist on sub/Cartfile.')
    end
  end

  context 'AC_REPOSITORY_DIR' do
    it 'falls back to a relative lookup when missing' do
      out, _err, status = run_main({ 'AC_CARTFILE_PATH' => 'sub/Cartfile' }, chdir: workdir)
      expect(status.exitstatus).to eq(0)
      expect(out).to include('Cartfile do not exist on sub/Cartfile.')
    end

    it 'falls back to a relative lookup when set to an empty string' do
      out, _err, status = run_main(
        { 'AC_CARTFILE_PATH' => 'sub/Cartfile', 'AC_REPOSITORY_DIR' => '' },
        chdir: workdir
      )
      expect(status.exitstatus).to eq(0)
      expect(out).to include('Cartfile do not exist on sub/Cartfile.')
    end

    it 'prefixes the Cartfile path when set' do
      out, _err, status = run_main(
        { 'AC_CARTFILE_PATH' => 'sub/Cartfile', 'AC_REPOSITORY_DIR' => '/repo' },
        chdir: workdir
      )
      expect(status.exitstatus).to eq(0)
      expect(out).to include('Cartfile do not exist on /repo/sub/Cartfile.')
    end
  end

  it 'exits 0 without running carthage when no Cartfile is present' do
    _out, _err, status = run_main({ 'AC_REPOSITORY_DIR' => workdir }, chdir: workdir)
    expect(status.exitstatus).to eq(0)
  end
end

# ─────────────────────────────────────────────────────────────────────────────

RSpec.describe 'ENV validation: carthage invocation' do
  let(:workdir)   { Dir.mktmpdir('carthage_run') }
  let(:bindir)    { File.join(workdir, 'fakebin') }
  let(:args_file) { File.join(workdir, 'carthage_args.txt') }
  let(:cwd_file)  { File.join(workdir, 'carthage_cwd.txt') }
  let(:brew_file) { File.join(workdir, 'brew_args.txt') }

  before do
    File.write(File.join(workdir, 'Cartfile'), 'github "Alamofire/Alamofire"')
    [args_file, cwd_file, brew_file].each { |f| FileUtils.touch(f) }
  end

  after { FileUtils.rm_rf(workdir) }

  # Runs main.rb against the stub toolchain and returns [status, carthage args].
  def invoke(env = {}, carthage_exit_status: 0)
    build_fake_bin(bindir, carthage_exit_status: carthage_exit_status)
    _out, _err, status = run_main(
      {
        'AC_REPOSITORY_DIR'            => workdir,
        'AC_TEST_CARTHAGE_ARGS_FILE'   => args_file,
        'AC_TEST_CARTHAGE_CWD_FILE'    => cwd_file,
        'AC_TEST_BREW_ARGS_FILE'       => brew_file
      }.merge(env),
      chdir: workdir,
      path_prefix: bindir
    )
    [status, File.read(args_file).strip]
  end

  context 'AC_CARTHAGE_COMMAND' do
    it 'defaults to bootstrap when missing' do
      status, args = invoke
      expect(status.exitstatus).to eq(0)
      expect(args).to eq('bootstrap')
    end

    # `ENV[...] || "bootstrap"` only defaults on nil, so an empty value reaches
    # carthage as-is. Asserted to lock the current behaviour in place.
    it 'invokes carthage without a subcommand when set to an empty string' do
      status, args = invoke({ 'AC_CARTHAGE_COMMAND' => '' })
      expect(status.exitstatus).to eq(0)
      expect(args).to eq('')
    end

    it 'passes the configured command through' do
      status, args = invoke({ 'AC_CARTHAGE_COMMAND' => 'update' })
      expect(status.exitstatus).to eq(0)
      expect(args).to eq('update')
    end
  end

  context 'AC_CARTHAGE_FLAGS' do
    it 'passes no extra flags when missing' do
      _status, args = invoke
      expect(args).to eq('bootstrap')
    end

    it 'passes no extra flags when set to an empty string' do
      _status, args = invoke({ 'AC_CARTHAGE_FLAGS' => '' })
      expect(args).to eq('bootstrap')
    end

    it 'appends the configured flags' do
      _status, args = invoke(
        {
          'AC_CARTHAGE_COMMAND' => 'update',
          'AC_CARTHAGE_FLAGS'   => '--platform iOS --use-xcframeworks'
        }
      )
      expect(args).to eq('update --platform iOS --use-xcframeworks')
    end
  end

  it 'runs carthage inside the Cartfile directory' do
    invoke
    expect(File.read(cwd_file).strip).to eq(File.realpath(workdir))
  end

  it 'propagates a non-zero carthage exit status' do
    status, = invoke({}, carthage_exit_status: 3)
    expect(status.exitstatus).to eq(3)
  end
end

# ─── Coverage Report ──────────────────────────────────────────────────────────
def print_coverage_report
  return unless defined?(Coverage) && Coverage.running?

  result = begin
    Coverage.result(stop: false, clear: false)
  rescue ArgumentError
    Coverage.result
  end

  main_path = result.keys.find { |p| p&.end_with?('main.rb') }
  return puts("\nCoverage: main.rb not found in results") unless main_path

  data      = result[main_path]
  lines     = data.each_with_index.reject { |c, _| c.nil? }
  total     = lines.size
  covered   = lines.count { |c, _| c.to_i > 0 }
  pct       = total.positive? ? (covered * 100.0 / total).round(1) : 100.0
  uncovered = lines.select { |c, _| c.to_i == 0 }.map { |_, i| i + 1 }

  color = pct == 100 ? "\e[32;1m" : pct >= 80 ? "\e[33m" : "\e[31m"
  bar_filled = (pct / 5).round
  bar = "\e[32m" + '█' * bar_filled + "\e[90m" + '░' * (20 - bar_filled) + "\e[0m"

  puts "\n\e[90m#{'═' * 72}\e[0m"
  puts '  Coverage Report'
  puts "\e[90m#{'─' * 72}\e[0m"
  puts "  main.rb  #{bar}  #{color}#{pct}%\e[0m  (#{covered}/#{total} lines)"
  if uncovered.any? && uncovered.size <= 20
    puts "  Uncovered lines: \e[90m#{uncovered.join(', ')}\e[0m"
  elsif uncovered.any?
    puts "  Uncovered lines: \e[90m#{uncovered.first(15).join(', ')} … (+#{uncovered.size - 15} more)\e[0m"
  end
  puts "\e[90m#{'═' * 72}\e[0m"
end

# ─── Runner ───────────────────────────────────────────────────────────────────
if __FILE__ == $PROGRAM_NAME
  RSpec.configure do |config|
    config.add_formatter ReadableFormatter
    config.color        = true
    config.order        = :defined
  end

  exit_code = RSpec::Core::Runner.run(['--order', 'defined'])
  print_coverage_report
  exit exit_code
end
