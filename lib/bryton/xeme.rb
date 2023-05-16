require 'xeme'


#===============================================================================
# Bryton::Xeme
# Kludge: I'm sure there's a way to delegate test_count and test_count= to
# @hsh['test_count'], but I don't know the syntax.
#
class Bryton::Xeme < Xeme
	# initialize
	def initialize(p_hsh={})
		super(p_hsh)
		@hsh['test_count'] = 0
	end
	
	# test_count
	def test_count
		return @hsh['test_count']
	end
	
	# test_count=
	def test_count=(val)
		@hsh['test_count'] = val
	end
end
#
# Bryton::Xeme
#===============================================================================


#===============================================================================
# Bryton::Xeme::File
#
class Bryton::Xeme::File < Bryton::Xeme
end
#
# Bryton::Xeme::File
#===============================================================================


#===============================================================================
# Bryton::Xeme::Dir
#
class Bryton::Xeme::Dir < Bryton::Xeme::File
	# add a key for which the element must be an array
	def array_keys
		rv = super()
		rv.push 'tests'
		return rv
	end
	
	# add a key for which the element must be a hash
	def hash_keys
		rv = super()
		rv.push 'tests'
		return rv
	end
	
	# tests
	def tests
		return self['tests']
	end
end
#
# Bryton::Xeme::Dir
#===============================================================================