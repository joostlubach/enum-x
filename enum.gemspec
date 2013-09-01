# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'enum/version'

Gem::Specification.new do |spec|
  spec.name          = "enum"
  spec.version       = Enum::VERSION
  spec.authors       = ["Joost Lubach"]
  spec.email         = ["joost@yoazt.com"]
  spec.description   = %q[ Allows a finite set of options for a field. ]
  spec.summary       = %q[ Allows a finite set of options for a field. ]
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^test/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
