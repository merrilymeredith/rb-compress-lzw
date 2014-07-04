
test:
	find t/ -type f -name '*.rb' -exec ruby -Ilib '{}' \;

