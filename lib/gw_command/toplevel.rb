#/usr/bin/env ruby -w
#
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

require 'optparse'
require 'delegate'
require 'pp'

module Command

class CommandError < Exception
  def initialize(details, return_code = -1, display_usage = true)
    super(details)
    @return_code = return_code
    @display_usage = display_usage
  end
  attr_reader :return_code, :display_usage
end

class Toplevel

  # define a new program with top-level dispatch
  # +name+::    Name of program (for usage)
  # +version+:: Version of program (for --version)
  # +output+::  Optionally override output for testing - default is $stdout
  #
  # Optional block allows definition of commands as follows
  #   Toplevel.new('mytool', '1.0') do |tl|
  #     tl.command(:doit, DoItClass, "Do what we're asked")
  #     tl.command(:start, StartClass, ['begin'] "Start (or begin)")
  #   end
  def initialize(name, version, output = $stdout)
    @name = name
    @version = version
    @output = output

    @commands = []
    yield CommandEntries.new(@commands) if block_given?

    @commands_map = OptionParser::CompletingHash.new
    @commands.each do |command|
      @commands_map[command.name] = command
      if command.name.is_a?(Symbol)
        @commands_map[command.name.to_s] = command
      end
      command.aliases.each {|a| @commands_map[a] = command}
    end
  end

  def toplevel_name
    @name
  end
  attr_reader :version
  attr_reader :output
  def version_string
    "#{toplevel_name}: #{version}"
  end
  def usage_string(command = "command")
    "#{@name} [global-options] #{command} [options]"
  end

  module CommonOptions
    def common_options(opts, version_string)
      opts.separator ""
      opts.separator "Common options:"

      opts.on("--[no-]debug", "Show debugging output") do |v|
        $DEBUG = v
      end
      opts.on("-v", "--[no-]verbose", "Show extra output") do |v|
        $VERBOSE = v
      end

      opts.on_tail("-h", "--help", "Show this message") do
        output.puts opts.help
        exit 0
      end

      opts.on("--version", "Show version") do
        output.puts version_string
        exit
      end
    end

  end
  include CommonOptions

  # parse the given command-line arguments
  def parse(args)

    opts_parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{usage_string}"

      commands_usage(opts)

      common_options(opts, version_string)
    end

    rest = opts_parser.order(args)
    if args.length == 0 then
      @output.puts "No command provided"
      usage_and_exit(opts_parser)
      exit
    end
    dispatch_command(opts_parser, rest)
  end

private

  def commands_usage(opts, width = 80, indent = 0)
    return if @commands.length == 0
    opts.separator ""
    opts.separator "Commands: "
    # Review this isn't safe if command-length exceeds summary width
    # or if description exceeds the remainder
    max = opts.summary_width
    @commands.each do |command|
      names = [command.name.to_s].concat(command.aliases).join(", ")
      opts.separator(opts.summary_indent + names.ljust(max) + " " + command.description)
    end
  end

  def dispatch_command(opts, rest)
    if rest.length > 0
      command = rest.shift
      begin
        method = :match
        # workaround version 1.8
        method = :complete if RUBY_VERSION =~ /^1\.8/
        
        unless entry = @commands_map.send(method, command)
          @output.puts "Unknown command '#{command}'"
          usage_and_exit(opts)
        end
      rescue OptionParser::AmbiguousArgument => e
        @output.puts "Ambiguous command '#{command}'"
        usage_and_exit(opts)
      rescue NameError => e
        # workaround for ruby 1.8 - complete throws name-error with :ambiguous
        raise unless RUBY_VERSION =~ /^1\.8/
        raise unless e.name == :ambiguous
        @output.puts "Ambiguous command '#{command}'"
        usage_and_exit(opts)
      end
      # for some reason exect matches come out differently to
      # inexact matches :(
      match = entry.first
      command = entry.last

      if command.klass
        command_obj = command.klass.new
      else
        command_obj = command.object
      end

      default_command(command.name, command_obj, rest)
    end
  end

  # Hmmm,... this seems pretty risky consider only omitting parms if
  # the method or block not provided
  class OptionParserWrapper
    def initialize(opts)
      @opts = opts
      @on_called = false
      @deferred = []
    end

    @@supported_methods = [:on, :on_head, :on_tail, :separator]
    @@on_methods = [:on, :on_head, :on_tail]
    def method_missing(symbol, *args, &blk)
      unless @@supported_methods.find {|x| x == symbol}
        raise NoMethodError.new("OptionParserWrapper only supports methods: #{@@supported_methods.join(", ")}", symbol, args)
      end
      @on_called = true if ! @on_called and @@on_methods.find {|x| x == symbol}
      @deferred << [symbol, args, blk]
    end

    def run_deferred
      @deferred.each do |symbol, args, blk|
        @opts.send(symbol, *args, &blk)
      end
    end
    attr_reader :on_called
  end

  # 'normal' commands are executed using this method.
  # In the future custom commands (may) be supported, which just call
  # an object's method or block
  def default_command(name, object, args)

    opts_parser = OptionParser.new do |opts|
      suffix = object.usage_suffix if object.respond_to?(:usage_suffix)
      if suffix.nil?
        suffix = ""
      else
        suffix = " " + suffix
      end
      opts.banner = "Usage: #{usage_string(name)}#{suffix}"

      wrapped_opts = OptionParserWrapper.new(opts)
      object.define_parms(wrapped_opts) if object.respond_to?(:define_parms)

      if wrapped_opts.on_called then
        opts.separator ""
        opts.separator "#{name.to_s.capitalize} command options: "
      end
      wrapped_opts.run_deferred

      common_options(opts, version_string)
    end

    rest = opts_parser.order(args)
    begin
      object.run(*rest) if object.respond_to?(:run)
    rescue CommandError => e
      @output.puts "Error: #{e.message}"
      @output.puts opts_parser if e.display_usage
      exit(e.return_code)
    end
  end

  def usage_and_exit(opts, code = -1)
    output.puts opts.help
    exit(code)
  end

  CommandEntry = Struct.new(:name, :klass, :aliases, :description, :object)
  
  # object passed out to allow commands to be defined against toplevel
  class CommandEntries
    def initialize(arr)
      @entries = arr
    end

    # object passed out to allow run and parms to pass blocks in to
    # CommandEntries#block_command
    class BlockCommandEntry
      def initialize
        @run_block = nil
        @parms_block = nil
        @usage_suffix = nil
      end
      def run(&blk)
        @run_block = blk
      end
      def parms(&blk)
        @parms_block = blk
      end
      attr_reader :run_block, :parms_block
      attr_accessor :usage_suffix
    end

    # Adapter to take blocks from BlockCommandEntry and present them
    # like the normal object interface
    class BlocksCommand
      def initialize(entry)
        @run_block = entry.run_block
        @parms_block = entry.parms_block
        @usage_suffix = entry.usage_suffix
      end
      def run(*args)
        @run_block.call(args) if @run_block
      end
      def define_parms(*args)
        @parms_block.call(*args) if @parms_block
      end
      attr_reader :usage_suffix
    end

    # parse alias and description
    def parse_trailing_args(args)
      aliases = []
      if args.length > 1
        aliases = args.shift
      end
      description = args.shift
      raise ArgumentError("Unexpected arguments #{args.inspect}") if args.length != 0
      [aliases, description]
    end
    private :parse_trailing_args

    # yield BlockCommandEntry to allow go and parm blocks to be defined
    def block_command(name, *args)
      aliases, description = parse_trailing_args(args)

      entry = BlockCommandEntry.new
      yield entry

      @entries << CommandEntry.new(name, nil, aliases, description, 
                                   BlocksCommand.new(entry))      
    end

    # allow a command to be defined against an object that takes calls
    # to define_parms and run
    def object_command(name, object, *args)
      aliases, description = parse_trailing_args(args)
      @entries << CommandEntry.new(name, nil, aliases, description, object)
    end

    # allow a command to be defined against an class that will be
    # instantiated, then passed calls to define_parms and run
    def command(name, klass, *args)
      aliases, description = parse_trailing_args(args)
      @entries << CommandEntry.new(name, klass, aliases, description)
    end
  end

end

end # Command
