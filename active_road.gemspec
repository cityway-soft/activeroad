# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "active_road/version"

Gem::Specification.new do |s|
  s.name        = "active_road"
  s.version     = ActiveRoad::VERSION
  s.authors     = ["Alban Peignier", "Luc Donnet", "Marc Florisson"]
  s.email       = ["alban@tryphon.eu", "luc.donnet@free.fr", "mflorisson@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Rails engine to manage roads and rails model}
  s.description = %q{Find street numbers and road ways}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "guard"
  s.add_development_dependency "guard-bundler"
  s.add_development_dependency "guard-rspec"
  s.add_development_dependency "factory_girl_rails", ">= 4.2.1"
  s.add_development_dependency 'rspec-rails', '~> 3.1.0'
  s.add_development_dependency 'rails', '>= 4.0.0'

  s.add_dependency 'activerecord', '>= 4.0.0'
  s.add_dependency 'activerecord-postgis-adapter', '>= 0.6.0' 
  s.add_dependency 'ffi-geos'
  s.add_dependency 'sqlite3', '~> 1.3.7'
  s.add_dependency 'pg', '>= 0.15.1'
  s.add_dependency 'activerecord-import', '>= 0.5.0'
  s.add_dependency 'nokogiri'
  s.add_dependency 'saxerator'
  s.add_dependency 'shortest_path', '0.0.4'
  s.add_dependency 'enumerize', '0.7.0'
  s.add_dependency "pbf_parser", '~> 0.0.6'
  s.add_dependency "leveldb-native", '~> 0.6'
  s.add_dependency 'postgres-copy'
end
