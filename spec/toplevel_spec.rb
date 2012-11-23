#/usr/bin/env ruby -w

# (C) Copyright Greg Whiteley 2010-2012
# 
#  This is free software: you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as
#  published by the Free Software Foundation, either version 3 of
#  the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require 'spec_helper'
require 'gw_command'

$DEBUG = false
$VERBOSE = false

include Command

describe Toplevel, "--debug" do
  before :each do
    @old_debug = $DEBUG
    $DEBUG = false
  end
  after :each do
    $DEBUG = @old_debug
  end

  it "sets global variable $DEBUG with --debug" do
    toplevel = Toplevel.new("name", "version")
    toplevel.parse("--debug")
    $DEBUG.should be_true
  end

  it "clears global variable $DEBUG with --no-debug" do
    toplevel = Toplevel.new("name", "version")
    $DEBUG = true
    toplevel.parse("--no-debug")
    $DEBUG.should be_false
  end
end

describe Toplevel, "--verbose" do

  before :each do
    @old_verbose = $VERBOSE
    $VERBOSE = false
  end
  after :each do
    $VERBOSE = @old_verbose
  end

  it "sets global variable $VERBOSE with --verbose" do
    toplevel = Toplevel.new("name", "version")
    toplevel.parse("--verbose")
    $VERBOSE.should be_true
  end

  it "sets global variable $VERBOSE with -v" do
    toplevel = Toplevel.new("name", "version")
    toplevel.parse("-v")
    $VERBOSE.should be_true
  end

  it "clears global variable $VERBOSE with --no-verbose" do
    toplevel = Toplevel.new("name", "version")
    $VERBOSE = true
    toplevel.parse("--no-verbose")
    $VERBOSE.should be_false
  end
end

describe Toplevel, "--version" do
  it "displays the name and version and exit" do
    stdout = mock("IO")
    stdout.should_receive(:puts).with("my name: version-string")
    toplevel = Toplevel.new("my name", "version-string", stdout)
    lambda { toplevel.parse("--version") }.should exit_with_code(0)
  end
end

describe Toplevel, "--help" do
  include HelpCommandHelpers

  def test_help(name, version, &block)
    stdout = StringIO.new
    toplevel = Toplevel.new(name, version, stdout, &block)
    lambda { toplevel.parse("--help") }.should exit_with_code(0)

    check_common_options(stdout.string)
    return stdout.string
  end

  it "displays the help output and exit" do
    output = test_help('name', 'version')
    check_common_options(output)
    puts output if $VERBOSE
  end

  it "omits the Commands section if no commands defined" do
    output = test_help('name', 'version')
    output.should_not =~ /^Commands:/
    puts output if $VERBOSE
  end

  it "includes the Commands section if commands defined" do
    output = test_help('name', 'version') do |tl|
      tl.command(:debug, mock(Class), "Description")
    end
    output.should =~ /^Commands:/
    puts output if $VERBOSE
  end

  it "describes given commands in the Commands section" do
    output = test_help('name', 'version') do |tl|
      tl.command("command1", mock(Class), "Description1")
      tl.command("command2", mock(Class), "Description2")
    end
    output.should =~ /\s+command1\s+Description1$/
    output.should =~ /\s+command2\s+Description2$/
    puts output if $VERBOSE
  end

  it "describes given commands and aliases in the Commands section" do
    output = test_help('name', 'version') do |tl|
      tl.command("command1", mock(Class), ["alt1"], "Description1")
      tl.command("command2", mock(Class), ["alt2, alt3"], "Description2")
    end
    output.should =~ /\s+command1, alt1\s+Description1$/
    output.should =~ /\s+command2, alt2, alt3\s+Description2$/
    puts output if $VERBOSE
  end
end

describe Toplevel, "#initialize" do
  it "provides an object for defining commands" do
    stdout = StringIO.new
    toplevel = Toplevel.new("name", "1.0", stdout) do |tl|
      tl.should_not be_nil
    end
  end

  it "allows commands to be defined" do
    stdout = StringIO.new
    toplevel = Toplevel.new("name", "1.0", stdout) do |tl|
      # one alias
      tl.command(:debug, mock(Class), ['start_debugging'], "Start the debugger")
      # no aliases
      tl.command(:stop, mock(Class), "Stop the debugger")
    end
  end
end

describe Toplevel, "command lookup" do
  include MockCommandHelpers

  it "reports unknown commands" do
    stdout = StringIO.new
    toplevel = Toplevel.new("name", "1.0", stdout) do |tl|
      tl.command(:debug, mock(Class), ['start_debugging'], "Start the debugger")
      tl.command(:stop, mock(Class), "Stop the debugger")
    end
    lambda {toplevel.parse("unknown")}.should  exit_with_code(-1)
    stdout.string.should =~ /^Unknown command 'unknown'/
  end

  # return a commands class that expects to be run with the given parameters
  def command_class_no_options_expects_to_run(*run_params)
    command_object, command_class = mock_command_class

    # no parms
    no_parms(command_object)
    # no usage_suffix
    no_usage_suffix(command_object)

    # return true to run, and allow run to, er, run
    command_object.should_receive(:respond_to?).with(:run).and_return(true)
    command_object.should_receive(:run).with(*run_params)
    return command_class
  end

  # return a commands class that expects to be run and expects to have
  # options queried with the given parameters
  def command_class_with_options_expects_to_run(*run_params)
    command_object, command_class = mock_command_class

    # no usage_suffix
    no_usage_suffix(command_object)

    # return true to define_parms, and expect call to be made
    command_object.should_receive(:respond_to?).with(:define_parms).and_return(true)
    command_object.should_receive(:define_parms)

    # return true to run, and allow run to, er, run
    command_object.should_receive(:respond_to?).with(:run).and_return(true)
    command_object.should_receive(:run).with(*run_params)
    return command_class
  end

  it "calls defined command" do
    toplevel = Toplevel.new("name", "1.0") do |tl|
      tl.command(:debug, command_class_no_options_expects_to_run, "Start the debugger")
    end
    toplevel.parse("debug")
  end

  it "calls command based on shortest match" do
    toplevel = Toplevel.new("name", "1.0") do |tl|
      tl.command(:debug, command_class_no_options_expects_to_run, "Start the debugger")
      tl.command(:stop, mock(Class), "Stop the debugger")
    end
    toplevel.parse("debu")
  end

  it "reports error for ambiguous command abbreviation" do
    stdout = StringIO.new
    toplevel = Toplevel.new("name", "1.0", stdout) do |tl|
      tl.command(:debug, mock(Class), "Start the debugger")
      tl.command(:degauss, mock(Class), "Degauss the monitor")
    end
    lambda {toplevel.parse("de")}.should exit_with_code(-1)
    stdout.string.should =~ /^Ambiguous command 'de'/
  end

  it "calls command based on aliases too" do
    toplevel = Toplevel.new("name", "1.0") do |tl|
      tl.command(:debug, command_class_no_options_expects_to_run, ["start", "go"], "Start the debugger")
    end
    toplevel.parse("start")
  end

  it "calls defined command with options callback" do
    toplevel = Toplevel.new("name", "1.0") do |tl|
      tl.command(:debug, command_class_with_options_expects_to_run, "Start the debugger")
    end
    toplevel.parse("debug")
  end

end

describe Toplevel, "subcommand error handling" do
  include MockCommandHelpers

  def command_class_throws_error_on_run(message, code, usage)
    command_object, command_class = mock_command_class

    # no usage_suffix
    no_usage_suffix(command_object)
    # no parms
    no_parms(command_object)

    # run throws error
    command_object.should_receive(:respond_to?).with(:run).and_return(true)
    command_object.should_receive(:run).and_raise(CommandError.new(message, code, usage))
    return command_class
  end

  it "allows defined commands to signal error conditions and dump usage" do
    output = StringIO.new
    toplevel = Toplevel.new("name", "1.0", output) do |tl|
      tl.command(:debug,
                 command_class_throws_error_on_run("bad state", 32, true),
                 "Start the debugger")
    end
    lambda { toplevel.parse("debug") }.should exit_with_code(32)
    output.string.should =~ /bad state/
    # expect usage
    output.string.should =~ /^Usage: name \[global-options\]/
  end

  it "allows defined commands to signal error conditions with no usage" do
    output = StringIO.new
    toplevel = Toplevel.new("name", "1.0", output) do |tl|
      tl.command(:debug,
                 command_class_throws_error_on_run("bad action", 11, false),
                 "Start the debugger")
    end
    lambda { toplevel.parse("debug") }.should exit_with_code(11)

    output.string.should =~ /bad action/
    # expect no usage
    output.string.should_not =~ /^Usage: name \[global-options\]/
  end

  it "allows defined commands to signal error conditions with no usage" do
    output = StringIO.new
    toplevel = Toplevel.new("name", "1.0", output) do |tl|
      tl.command(:debug,
                 command_class_throws_error_on_run("bad action", 21, false),
                 "Start the debugger")
    end
    lambda { toplevel.parse("debug") }.should  exit_with_code(21)

    output.string.should =~ /bad action/
    # expect no usage
    output.string.should_not =~ /^Usage: name \[global-options\]/
  end

end

describe Toplevel, "command --help" do
  include HelpCommandHelpers

  def test_help(name, version, command, &block)
    stdout = StringIO.new
    toplevel = Toplevel.new(name, version, stdout, &block)
    lambda { toplevel.parse([command, "--help"]) }.should exit_with_code(0)

    check_common_options(stdout.string)
    return stdout.string
  end

  it "omits the 'command options' section if the command defines no options" do
    output = test_help('name', 'version', "debug") do |tl|
      tl.block_command("debug", "start debugging") do |cmd|
        # no parms
      end
    end
    check_common_options(output)
    output.should_not =~ /Debug command options:/
    puts output if $VERBOSE
  end

  it "includes the Commands section if commands are defined" do
    output = test_help('name', 'version', "debug") do |tl|
      tl.block_command("debug", "start debugging") do |cmd|
        cmd.parms do |opts|
          opts.on("-a", "--an-opt", "An option")
        end
      end
    end
    output.should =~ /Debug command options:/
    puts output if $VERBOSE
  end

  it "shows any usage_suffix at the end of the usage line" do
    output = test_help('name', 'version', "debug") do |tl|
      tl.block_command("debug", "start debugging") do |cmd|
        cmd.usage_suffix = "FILES"
      end
    end
    check_common_options(output)
    output.should =~ /^Usage: name \[global-options\] debug \[options\] FILES$/
    puts output if $VERBOSE
  end

  it "shows no suffix if usage_suffix is nil" do
    output = test_help('name', 'version', "debug") do |tl|
      tl.block_command("debug", "start debugging") do |cmd|
        cmd.usage_suffix = nil
      end
    end
    check_common_options(output)
    output.should =~ /^Usage: name \[global-options\] debug \[options\]$/
    puts output if $VERBOSE
  end

end
