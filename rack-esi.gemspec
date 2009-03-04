# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rack-esi}
  s.version = "0.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Christoffer Sawicki", "Daniel Mendler"]
  s.date = %q{2009-03-04}
  s.email = ["christoffer.sawicki@gmail.com", "mail@daniel-mendler.de"]
  s.extra_rdoc_files = ["COPYING.txt"]
  s.files = ["COPYING.txt", "examples/basic_example_application.ru", "examples/basic_example_application.rb", "examples/basic_example_application_with_caching.ru", "lib/rack/esi.rb", "Rakefile", "README.markdown", "test/test_rack_esi.rb"]
  s.has_rdoc = true
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{rack-esi}
  s.rubygems_version = %q{1.3.1}
  s.summary = 'Implementation of Edge Side Includes subset for rack'
  s.test_files = ["test/test_rack_esi.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<hoe>, [">= 1.8.3"])
    else
      s.add_dependency(%q<hoe>, [">= 1.8.3"])
    end
  else
    s.add_dependency(%q<hoe>, [">= 1.8.3"])
  end
end
