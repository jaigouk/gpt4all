# frozen_string_literal: true

require_relative 'lib/gpt4all/version'

Gem::Specification.new do |spec|
  spec.name = 'gpt4all'
  spec.version = Gpt4all::VERSION
  spec.authors = ['Jaigouk Kim']
  spec.email = ['ping@jaigouk.kim']

  spec.summary = 'gpt4all'
  spec.description = 'interface to gpt4all'
  spec.homepage = 'https://github.com/jaigouk/gpt4all'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.metadata['allowed_push_host'] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/jaigouk/gpt4all'
  spec.metadata['changelog_uri'] = 'https://github.com/jaigouk/gpt4all/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'faraday', '~> 2.7'
  spec.add_dependency 'os', '~> 1.1'
  spec.add_dependency 'tty-progressbar', '~> 0.18.2'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
