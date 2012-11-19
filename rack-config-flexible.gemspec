Gem::Specification.new do |gem|
  gem.name        = 'rack-config-flexible'
  gem.version     = '0.1.4'
  gem.author      = 'Tim Hentenaar'
  gem.email       = 'tim.hentenaar@gmail.com'
  gem.homepage    = 'https://github.com/thentenaar/rack-config-flexible'
  gem.summary     = 'An alternative to Rack::Config, offering much greater flexibility'
  gem.description = <<__XXX__
  Rack::Config::Flexible is an alternative to Rack::Config,
  offering much greater flexibility.
  
  Configuration options are stored as key-value pairs in _sections_,
  partitioned by _environments_. For example:
  
    + environment
      + section
        key -> value pairs
  
  A simple DSL is provided and can be used either within a passed
  configuration block (to ::new), or to the #configuration method.
  
  Facilities are also provided to load whole environments, and sections
  from either a single YAML file structured like, or from a directory tree.

  See the README file or RDoc documentation for more info.
__XXX__

  gem.files = Dir['lib/**/*','README*', 'LICENSE']
end

# vi:set ts=2 sw=2 expandtab sta:
