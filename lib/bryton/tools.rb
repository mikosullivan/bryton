require 'xeme'
require 'talk-to-me'


#===============================================================================
# Bryton
#
module Bryton
	# instance properties
	@exit_on_fail = false
	@ready = true
	@keep_count = true
	@line_comments = false
	
	
	#---------------------------------------------------------------------------
	# accessors
	#
	class << self
		attr_accessor :exit_on_fail
		attr_accessor :ready
		attr_accessor :keep_count
		attr_accessor :xeme
		attr_accessor :line_comments
	end
	#
	# accessors
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# accessor methods
	#
	def self.verbose
		return TTM.io ? true : false
	end
	
	def self.verbose=(bool)
		if bool
			TTM.io = STDERR
		else
			TTM.io = nil
		end
	end
	#
	# accessor methods
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# reset
	#
	def self.reset()
		self.verbose= true
		@xeme = Xeme.new()
		@xeme['count'] = 0
	end
	
	reset()
	#
	# reset
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# pause_counting
	#
	def self.pause_counting
		hold_keep_count = @keep_count
		@keep_count = false
		yield
	ensure
		@keep_count = hold_keep_count
	end
	#
	# pause_counting
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# increment_count
	#
	def self.increment_count
		if @keep_count
			@xeme['count'] += 1
		end
	end
	#
	# increment_count
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# succeed
	#
	def self.succeed
		if not @ready
			@xeme.error 'not-ready'
		end
		
		# set success to true
		@xeme.try_succeed()
		
		# output
		puts xeme.to_json()
	end
	#
	# succeed
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# line_error
	#
	def self.line_error(level=1)
		loc = caller_locations[level]
		error = @xeme.error('line-' + loc.lineno.to_s)
		
		# get line comment if there is one
		line_comment error, loc
		
		# exit if exiting on first fail
		maybe_exit_on_fail()
	end
	#
	# line_error
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# line_comment
	#
	def self.line_comment(error, loc)
		@line_comments or return
		
		# KLUDGE: I don't understand why loc.lineno and the line number are two
		# apart.
		idx = 2
		
		# read file
		File.foreach(loc.path) do |line|
			if idx == loc.lineno
				if line.sub!(/\A\s*\#\#\s*/mu, '')
					if line.match(/\S/mu)
						line = line.sub(/\s+\z/mu, '')
						error['comment'] = line
					end
				end
				
				# we're done
				return
			end
			
			# increment current line number
			idx += 1
		end
	end
	#
	# line_comment
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# maybe_exit_on_fail
	#
	def self.maybe_exit_on_fail
		if @exit_on_fail
			puts xeme.to_json()
			exit
		end
	end
	#
	# maybe_exit_on_fail
	#---------------------------------------------------------------------------
	
	
	### tests
	
	
	#---------------------------------------------------------------------------
	# pass, fail
	#
	def self.pass
		Bryton.increment_count()
	end
	
	def self.fail
		increment_count()
		line_error()
	end
	#
	# pass, fail
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# structure comparisons
	#
	def self.compare(should, is)
		TTM.hrm
		return Bryton::StructureComp.compare(should, is)
	end
	#
	# structure comparisons
	#---------------------------------------------------------------------------
	
	
	#-------------------------------------------------------------------------------
	# isa
	#
	def self.isa(obj, clss)
		Bryton.increment_count()
		
		# success
		if obj.is_a?(clss)
			return true
		
		# failure
		else
			Bryton.line_error(2)
			return false
		end
	end
	#
	# isa
	#-------------------------------------------------------------------------------
end
#
# Bryton
#===============================================================================


#===============================================================================
# Bryton::ExceptionTest
#
class Bryton::ExceptionTest
	attr_accessor :err_class
	
	
	#---------------------------------------------------------------------------
	# initialize
	#
	def initialize
		@err_class = nil
	end
	#
	# initialize
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# exec
	#
	def exec
		Bryton.increment()
		success = false
		e = nil
		
		# Run the block. If it runs successfully then it fails the test.
		begin
			yield
			success = true
			
			# verbosify
			TTM.puts 'block-did-not-fail'
			
		# We want to get to this rescue block because that means the block
		# failed, which is what it's supposed to do.
		rescue => e
			# verbosify if necessary
			
			TTM.puts "error class: #{e.class.to_s}"
			TTM.puts "error:       #{e}"
			
			# if error id, add that
			if e.respond_to?('id')
				TTM.puts "error id:    #{e}"
			end
		
			
			# check error class
			if @err_class
				if not e.class == @err_class
					if @verbose
						puts "error class was #{e.class.to_s} but should have been #{@err_class.to_s}"
					end
					
					Bryton.line_error(2)
				end
			end
		end
		
		# if yield succeeded, then an exception did not occur
		if success
			Bryton.line_error()
		end
		
		# return error
		return e
	end
	#
	# exec
	#---------------------------------------------------------------------------
end
#
# Bryton::ExceptionTest
#===============================================================================


#===============================================================================
# Bryton::StructureComp
#
module Bryton::StructureComp
	#-------------------------------------------------------------------------------
	# array_comp
	#
	def self.array_comp(should, is, opts={'recurse'=>true})
		should.each_with_index do |should_el, idx|
			element_comp should_el, is[idx], opts
		end
	end
	#
	# array_comp
	#-------------------------------------------------------------------------------
	
	
	#-------------------------------------------------------------------------------
	# hash_comp
	#
	def self.hash_comp(should, is, opts={})
		Bryton.increment()
		opts = {'recurse'=>true}.merge(opts)
		
		
		# early exit: is is null
		defined is
		is or return
		
		# is a hash
		isa is, Hash
		is.is_a?(Hash) or return
		
		# if not a hash, return
		if not is.is_a?(Hash)
			return false
		end
		
		# should be of same length
		eq should.length, is.length
		
		# loop through keys
		should.keys.each do |should_k|
			element_comp should[should_k], is[should_k], opts
		end
	end
	#
	# hash_comp
	#-------------------------------------------------------------------------------
	
	
	#-------------------------------------------------------------------------------
	# compare
	#
	def self.compare(should, is, opts)
		Bryton.increment_count()
		
		# should be same classes
		if not Bryton.isa(is, should.class)
			return
		end
		
		# pause counting and recurse
		Bryton.pause_counting do
			# if should element is a hash
			if should.is_a?(Hash)
				return hash_comp(should, is, opts)
				
			# if should is an array
			elsif should.is_a?(Array)
				return array_comp(should, is, opts)
				
			# if should is a string
			elsif should.is_a?(String)
				return Bryon.eq(should, is)
			end
		end
	end
	#
	# compare
	#-------------------------------------------------------------------------------
end
#
# Bryton::StructureComp
#===============================================================================