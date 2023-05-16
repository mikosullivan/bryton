#!/usr/bin/ruby -w
require 'timeout'
require 'json'
require 'fso'
require 'hash/digger'
require 'talk-to-me'


#===============================================================================
# Bryton
#
module Bryton
end
#
# Bryton
#===============================================================================


# load bryton xeme classes
require 'bryton/xeme'


#===============================================================================
# Bryton::FSO
# Just initializing namespace.
#
module Bryton::FSO
end
#
# Bryton::FSO
#===============================================================================


#===============================================================================
# Bryton::FSO::Dir
#
class Bryton::FSO::Dir < FSO::Dir
	attr_reader :xeme
	attr_accessor :stop_on_fail
	attr_accessor :verbose
	attr_accessor :run_tests
	
	#---------------------------------------------------------------------------
	# classes
	#
	def self.classes
		return {
			'dir'=>Bryton::FSO::Dir,
			'file'=>Bryton::FSO::File
		};
	end
	#
	# classes
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# initialize
	#
	def initialize(p_path='./')
		super(p_path)
		@settings = nil
		@children = nil
		@stop_on_fail = false
	end
	#
	# initialize
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# settings
	#
	def settings
		# cache bryton.json if necessary
		if not @settings
			settings_path = "#{path}/bryton.json"
			@settings = {'active'=>true}
			
			# slurp in settings file
			if ::File.exist?(settings_path)
				explicit = ::File.read(settings_path)
				explicit = JSON.parse(explicit)
				@settings = @settings.merge(explicit)
			end
		end
		
		# return
		return @settings
	end
	#
	# settings
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# meta
	#
	def meta
		return settings['meta'] || {}
	end
	#
	# meta
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# children
	#
	def children(opts={})
		# cache @children if it's not already defined
		if not @children
			chdir do
				@children = []
				
				# special case: files element exists but is false
				if settings.has_key?('files') and (not settings['files'])
					return @children
				end
				
				# build list of child files
				children_explicit opts
				children_implicit super(), opts
			end
		end
		
		# return
		return @children
	end
	#
	# children
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# children_explicit
	#
	def children_explicit(opts)
		explicits = settings['files'] || {}
		
		explicits.each do |child_path, child_settings|
			if child_settings
				if child = self.class.existing(child_path)
					if child.settings['active']
						@children.push child
					end
				else
					raise 'non-existent-file-in-list: ' + child_path
				end
			end
		end
	end
	#
	# children_explicit
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# children_implicit
	# skips dev.* files
	#
	def children_implicit(kids, opts)
		# early exit: if filter is true, don't import implicit children
		settings['listed-only'] and return
		
		kids.each do |child|
			if not child_names.include?(child.name)
				unless child.name.match(/\Adev\./mu)
					if child.dir?
						@children.push child
					elsif child.executable?
						@children.push child
					end
				end
			end
		end
	end
	#
	# children_implicit
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# child_names
	#
	def child_names
		return @children.map{|child| child.name}
	end
	#
	# child_names
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# run
	#
	def run(opts={})
		opts = {'nested'=>0}.merge(opts)
		xeme = Xeme.new()
		
		# verbosify
		unless opts['first']
			TTM.puts title(opts)
		end
		
		# operate in own directory
		chdir() do
			TTM.indent('skip'=>opts.delete('first')) do
				run_children xeme, opts
				run_commands xeme, opts
			end
		end
		
		# At this point, all tests in the have been run. Attempt to succeed.
		xeme.try_succeed
		
		# if set as not ready, fail anyway
		if xeme.success?
			if meta.has_key?('ready') and (not meta['ready'])
				xeme['success-but-not-ready'] = true
				xeme.fail
			end
		end
		
		# return xeme
		return xeme
	end
	#
	# run
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# run_children
	#
	def run_children(xeme, opts)
		children.each do |child|
			if child.executable? or child.dir? and child.settings['active']
				send_opts = opts.clone
				send_opts['nested'] += 1 
				
				# run child, add to nested if any results
				if nest = child.run(send_opts)
					xeme['nested'].push nest
					
					if nest.failure? and @stop_on_fail
						return
					end
				end
			end
		end
	end
	#
	# run_children
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# run_commands
	#
	def run_commands(xeme, opts)
		commands = settings['commands'] || []
		commands.empty? and return
		
		# load EzCapture
		require 'ezcapture'
		
		# loop through commands
		commands.each do |cmd|
			nest = run_command(cmd)
			xeme['nested'].push nest
			
			# exit if error
			if nest.failure? and @stop_on_fail
				return
			end
		end
	end
	#
	# run_commands
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# run_command
	#
	def run_command(cmd)
		capture = EzCapture.new(*cmd)
		xeme = Xeme.last_line(capture.stdout)
		
		# if no stdout, return failure xeme
		if not xeme
			xeme = Xeme.new()
			xeme.error 'did-not-get-xeme-in-stdout'
			return xeme
		end
		
		# return
		return xeme
	end
	#
	# run_command
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# title
	# Determines the string that should be displayed when this file is listed
	# when verbose setting is true.
	#
	def title(opts)
		# if defined name for this directory
		if explicit = settings.digger('meta', 'title')
			return explicit
		
		# else return the name of the directory
		else
			return name
		end
	end
	#
	# title
	#---------------------------------------------------------------------------
end
#
# Bryton::FSO::Dir
#===============================================================================


#===============================================================================
# Bryton::FSO::File
#
class Bryton::FSO::File < FSO::File
	#---------------------------------------------------------------------------
	# classes
	#
	def self.classes
		return {
			'file' => Bryton::FSO::File,
			'dir'  => Bryton::FSO::Dir
		};
	end
	#
	# classes
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# initialize
	#
	def initialize(*opts)
		super(*opts)
		@children = nil
		@settings = nil
	end
	#
	# initialize
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# settings
	#
	def settings()
		# cache if necessary
		if not @settings
			default = {'active'=>true}
			explicit = dir.settings.digger('files', name)
			
			# If no explicit definition of the file, initialize to empty hash.
			if explicit.nil?
				explicit = {}
				
			# If explicit is defined but is not a hash, the non-hash value is
			# assumed to be the "active" value.
			elsif not explicit.is_a?(Hash)
				explicit = {'active'=>explicit}
			end
			
			# by this point explicit is a hash
			
			# merge explicit and default
			@settings = default.merge(explicit)
		end
		
		# return
		return @settings
	end
	#
	# settings
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# run
	#
	def run(opts={})
		# If the file is not active, do nothing - don't even print the name.
		if not settings['active']
			return nil
		end
		
		# verbosify
		if opts['verbose']
			TTM.puts title(opts)
			
			# message before running
			if before = @settings.digger('messages', 'before')
				TTM.indent do
					TTM.puts before
				end
			end
		end
		
		# run and return xeme if necessary
		unless opts['list_only']
			return run_test(opts)
		end
	end
	#
	# run
	#---------------------------------------------------------------------------
	
	
	#---------------------------------------------------------------------------
	# run_test
	#
	def run_test(opts)
		capture = execute()
		xeme = Xeme.last_line(capture.stdout)
		
		# if no stdout, return failure xeme
		if not xeme
			xeme = Xeme.new()
			xeme.error 'did-not-get-xeme-in-stdout'
			return xeme
		end
		
		# return
		return xeme
	end
	#
	# run_test
	#---------------------------------------------------------------------------
		
	
	#---------------------------------------------------------------------------
	# title
	#
	def title(opts)
		return name
	end
	#
	# title
	#---------------------------------------------------------------------------
end
#
# Bryton::FSO::File
#===============================================================================