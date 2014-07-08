
watch( '(lib|t)/.*\.rb' ) do
  system 'tput reset; rake test'
end

