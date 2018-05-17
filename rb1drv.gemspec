
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "rb1drv/version"

Gem::Specification.new do |spec|
  spec.name          = "rb1drv"
  spec.version       = Rb1drv::VERSION
  spec.authors       = ["Xinyue Lu"]
  spec.email         = ["i@7086.in"]

  spec.summary       = "Ruby OneDrive Library"
  spec.homepage      = "https://github.com/msg7086/rb1drv"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = '>= 2.3'

  spec.add_dependency "oauth2", "~> 1.4"
  spec.add_dependency "excon", "~> 0.62"
  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
end
