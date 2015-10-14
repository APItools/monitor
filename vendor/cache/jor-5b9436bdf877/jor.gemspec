# -*- encoding: utf-8 -*-
# stub: jor 0.1.1 ruby lib

Gem::Specification.new do |s|
  s.name = "jor"
  s.version = "0.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Josep M. Pujol"]
  s.date = "2015-10-14"
  s.description = "JSON on top of Redis"
  s.email = "josep@3scale.net"
  s.files = [".gitignore", "Gemfile", "LICENCE", "README.md", "Rakefile", "config.ru", "jor.gemspec", "lib/jor.rb", "lib/jor/collection.rb", "lib/jor/doc.rb", "lib/jor/errors.rb", "lib/jor/server.rb", "lib/jor/storage.rb", "lib/jor/version.rb", "test/test_helper.rb", "test/test_helpers/fixtures.rb", "test/unit/collection_test.rb", "test/unit/doc_test.rb", "test/unit/server_test.rb", "test/unit/storage_test.rb", "test/unit/test_case.rb"]
  s.homepage = ""
  s.rubygems_version = "2.4.8"
  s.summary = "Storage engine for JSON documents using Redis. It allows fast find operations (index) by any field of the JSON document (ala MongoDB)"
  s.test_files = ["test/test_helper.rb", "test/test_helpers/fixtures.rb", "test/unit/collection_test.rb", "test/unit/doc_test.rb", "test/unit/server_test.rb", "test/unit/storage_test.rb", "test/unit/test_case.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<hiredis>, [">= 0"])
      s.add_runtime_dependency(%q<redis>, ["~> 3.0"])
      s.add_runtime_dependency(%q<rack>, ["~> 1.5"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<rack-test>, [">= 0"])
      s.add_development_dependency(%q<thin>, [">= 0"])
    else
      s.add_dependency(%q<hiredis>, [">= 0"])
      s.add_dependency(%q<redis>, ["~> 3.0"])
      s.add_dependency(%q<rack>, ["~> 1.5"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<rack-test>, [">= 0"])
      s.add_dependency(%q<thin>, [">= 0"])
    end
  else
    s.add_dependency(%q<hiredis>, [">= 0"])
    s.add_dependency(%q<redis>, ["~> 3.0"])
    s.add_dependency(%q<rack>, ["~> 1.5"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<rack-test>, [">= 0"])
    s.add_dependency(%q<thin>, [">= 0"])
  end
end
