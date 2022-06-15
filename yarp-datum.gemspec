# frozen_string_literal: true

require_relative "lib/datum/version"

Gem::Specification.new do |spec|
  spec.name = "yarp-datum"
  spec.version = Datum::VERSION
  spec.authors = ["Victor Gama"]
  spec.email = ["hey@vito.io"]

  spec.summary = "A Lightweight Data Layer for Ruby"
  spec.description = spec.summary
  spec.homepage = "https://github.com/libyarp/datum"
  spec.license = "LGPL-3.0-or-later"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.add_development_dependency "logrb", "~> 0.1.3"
end
