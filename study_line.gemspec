# frozen_string_literal: true

require_relative "lib/study_line/version"

Gem::Specification.new do |spec|
  spec.name = "study_line"
  spec.version = StudyLine::VERSION
  spec.authors = ["kentaro0215"]
  spec.email = ["ken.runteq0215@gmail.com"]

  spec.summary = "A CLI tool to track and manage study time."
  spec.description = "StudyLine is a CLI tool designed to help users track and manage their study time effectively."
  spec.homepage = "https://github.com/kentaro0215/study_line"
  spec.required_ruby_version = ">= 2.6.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.

  # spec.files = Dir.chdir(__dir__) do
  #   `git ls-files -z`.split("\x0").reject do |f|
  #     (File.expand_path(f) == __FILE__) ||
  #       f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
  #   end
  # end

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features|.*\.gem)$})
  end
  
  spec.bindir = "bin"
  # spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.executables = ["sl"]
  spec.require_paths = ["lib"]

    # 依存関係の追加（例えば、ThorやHTTPartyなど）
    spec.add_dependency "thor"
    spec.add_dependency "httparty"  

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
