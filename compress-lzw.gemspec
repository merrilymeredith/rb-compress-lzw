Gem::Specification.new do |s|
  s.name        = 'compress-lzw'
  s.version     = '0.0.1'
  s.summary     = "Scaling LZW compression"
  s.description = "Scaling LZW compression, compatible with unix compress(1)"
  s.authors     = [ "Meredith Howard"  ]
  s.email       = [ 'mhoward@cpan.org' ]
  s.license     = 'MIT'
  s.homepage    = 'https://github.com/merrilymeredith/rb-compress-lzw'

  s.files       = ["lib/"]

  s.required_ruby_version = '~> 2.0'

  s.add_development_dependency 'minitest'
end

