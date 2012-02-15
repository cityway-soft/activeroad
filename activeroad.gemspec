# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "active_road/version"

Gem::Specification.new do |s|
  s.name        = "activeroad"
  s.version     = ActiveRoad::VERSION
  s.authors     = ["Alban Peignier"]
  s.email       = ["alban.peignier@dryade.net"]
  s.homepage    = ""
  s.summary     = %q{Manage roads for Rails}
  s.description = %q{Find street numbers and road ways}

  s.rubyforge_project = "activeroad"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"

  s.add_development_dependency "rspec"
  s.add_development_dependency "guard"
  s.add_development_dependency "guard-rspec"
  s.add_development_dependency "database_cleaner"
  s.add_development_dependency "factory_girl"
  s.add_development_dependency "rcov"
  s.add_development_dependency "pg"

  s.add_runtime_dependency 'rails'
  s.add_runtime_dependency 'postgis_adapter', '~> 0.8.1'
  s.add_runtime_dependency 'shortest_path'
end
