# frozen_string_literal: true

require_relative 'lib/openskill/version'

Gem::Specification.new do |spec|
  spec.name = 'openskill'
  spec.version = OpenSkill::VERSION
  spec.authors = ['Tamas Erdos']
  spec.email = ['tamas at tamaserdos.com']

  spec.summary = 'Multiplayer rating system for Ruby'
  spec.description = 'A Ruby implementation of the OpenSkill rating system, ' \
                       'providing Bayesian skill ratings for multiplayer games'
  spec.homepage = 'https://github.com/erdostom/openskill-ruby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.files = Dir['lib/**/*', 'LICENSE', 'README.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'bigdecimal', '~> 3.1'
  spec.add_dependency 'distribution', '~> 0.8'
  spec.add_dependency 'prime', '~> 0.1'

  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '~> 13.0'
end
