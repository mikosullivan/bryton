#!/usr/bin/ruby -w
require_relative '../../cl-dev.rb'
require 'bryton/tester'
Bryton::Tester.die_on_fail = true

exception() do |test|
	test.id = 'whatever'
	test.sep = ':'
	
	test.exec do
		raise 'whatever: 1'
	end
end

# done
# puts '[done]'
Bryton.tester.done
