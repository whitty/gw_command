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

require 'rubygems'
require 'bundler/setup'
require 'rspec'

module ExitCodeMatchers
  RSpec::Matchers.define :exit_with_code do |code|
    actual = nil
    match do |block|
      begin
        block.call
      rescue SystemExit => e
        actual = e.status
      end
      actual and actual == code
    end
    failure_message_for_should do |block|
      "expected block to call exit(#{code}) but exit" +
        (actual.nil? ? " not called" : "(#{actual}) was called")
    end
    failure_message_for_should_not do |block|
      "expected block not to call exit(#{code})"
    end
    description do
      "expect block to call exit(#{code})"
    end    
  end  
end

RSpec.configure do |config|
  config.include(ExitCodeMatchers)
  # from rspec --init
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
end

module MockCommandHelpers

  def mock_command_class
    command_object = mock(Command)
    command_class = mock(Class)
    command_class.should_receive(:new).and_return(command_object)
    [command_object, command_class]
  end
  def no_usage_suffix(command_object)
    command_object.should_receive(:respond_to?).with(:usage_suffix).and_return(false)
  end
  def no_parms(command_object)
    command_object.should_receive(:respond_to?).with(:define_parms).and_return(false)
  end
end

module HelpCommandHelpers
  def check_common_options(string)
    string.should =~ /^Usage: name \[global-options\]/
    string.should =~ /^Common options:/
    string.should =~ /--\[no-\]debug\s+Show debugging output/
    string.should =~ /-v,\s+--\[no-\]verbose\s+Show extra output/
    string.should =~ /--version\s+Show version/
    string.should =~ /--help\s+Show this message/
  end
end
