LOREM = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.".freeze
BIG   = ( 0 .. 5000 ).inject('') { |a, _| a << (0 .. 5).map { rand(255).chr }.join('') + LOREM }
