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

include Command

describe Toplevel, "command definitions" do

  it "allows two-block definitions" do
    called = nil
    @toplevel = Toplevel.new("name", "version") do |dl|
      dl.block_command("debug", ["go"], "Start the debugger") do |cmd|
        cmd.run do |args|
          called += 1
        end
        cmd.parms do |opts|
        end
      end
    end
    # guard against programming errors above - don't assign value
    # until here
    called = 0 
    @toplevel.parse("debug")
    called.should be(1)
  end

  it "allows parms to be defined and called using two-block definitions" do
    parm_value = nil
    remaining_args = nil
    @toplevel = Toplevel.new("name", "version") do |dl|
      dl.block_command("debug", ["go"], "Start the debugger") do |cmd|
        cmd.parms do |opts|
          opts.on("-p", "--parm-value INTEGER", Integer, "Set the parm value") do |i|
            parm_value = i
          end
        end
        cmd.run do |args|
          remaining_args = args.dup
        end
      end
    end
    @toplevel.parse(["debug", "-p", "77"])
    parm_value.should be(77)
    remaining_args.length.should be(0)
  end

  it "should present parm help when using two-block definitions" do
    output = StringIO.new
    @toplevel = Toplevel.new("name", "version", output) do |dl|
      dl.block_command("debug", ["go"], "Start the debugger") do |cmd|
        cmd.parms do |opts|
          opts.on("-p", "--parm-value INTEGER", Integer, "Set the parm value") do |i|
          end
        end
      end
    end
    lambda {@toplevel.parse(["debug", "--help"])}.should exit_with_code(0)
    output.string.should =~ /Debug command options:/
    output.string.should =~ /--parm-value INTEGER.*Set the parm value/
  end

  class CommandClass
    def initialize
      @value = 0
      @increment = 1
    end
    def run
      @value += @increment
    end
    def define_parms(opts)
      opts.on("-i", "--increment INTEGER", Integer, "Set increment amount") do |i|
        @increment = i
      end
    end
    attr_reader :increment, :value
  end

  it "allows object for commands" do
    command_object = CommandClass.new
    @toplevel = Toplevel.new("name", "version") do |dl|
      dl.object_command("incr", command_object, ["add"], "Start the debugger")
    end

    @toplevel.parse("incr")
    command_object.value.should be(1)
  end

  it "object parms are defined and take effect" do
    command_object = CommandClass.new
    @toplevel = Toplevel.new("name", "version") do |dl|
      dl.object_command("incr", command_object, ["add"], "Increment a counter")
    end

    @toplevel.parse(["incr", "-i", "10"])
    command_object.value.should be(10)

    @toplevel.parse(["add", "--increment", "5"])
    command_object.value.should be(15)
  end

  it "object parms described in command help" do
    command_object = CommandClass.new
    output = StringIO.new
    @toplevel = Toplevel.new("name", "version",output) do |dl|
      dl.object_command("incr", command_object, ["add"], "Increment a counter")
    end

    lambda {@toplevel.parse(["incr", "--help"])}.should exit_with_code(0)
    puts output.string if $VERBOSE
    output.string.should =~ /--increment INTEGER.*Set increment amount/
    output.string.should =~ /Incr command options:/
  end
end
