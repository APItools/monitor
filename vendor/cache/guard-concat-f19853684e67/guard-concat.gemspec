# -*- encoding: utf-8 -*-
# stub: guard-concat 0.0.5 ruby lib

Gem::Specification.new do |s|
  s.name = "guard-concat"
  s.version = "0.0.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Francesco 'makevoid' Canessa"]
  s.date = "2014-11-17"
  s.description = "    Guard::Concat automatically concatenates files in one when watched files are modified.\n"
  s.email = "makevoid@gmail.com"
  s.files = ["LICENSE", "Readme.md", "lib/guard", "lib/guard/concat", "lib/guard/concat.rb", "lib/guard/concat/templates", "lib/guard/concat/templates/Guardfile"]
  s.homepage = "http://github.com/makevoid/guard-concat"
  s.rubygems_version = "2.2.2"
  s.summary = "Guard gem for concatenating (js/css) files"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<guard>, [">= 1.1.0"])
    else
      s.add_dependency(%q<guard>, [">= 1.1.0"])
    end
  else
    s.add_dependency(%q<guard>, [">= 1.1.0"])
  end
end
