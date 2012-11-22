# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "gw_command/version"

Gem::Specification.new do |s|
  s.name        = "gw_command"
  s.version     = GwCommand::VERSION
  s.authors     = ["Greg Whiteley"]
  s.email       = ["whitty@users.sourceforge.net"]
  s.homepage    = ""
  s.summary     = %q{gw_command eases creation of tools with sub-commands}
  s.description = %q{gw_command eases creation of tools with sub-commands}

  s.rubyforge_project = "gw_command"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
