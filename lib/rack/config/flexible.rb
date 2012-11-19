#
# Rack::Config::Flexible - Configuration middleware for Rack
#
# Copyright (C) 2012 Tim Hentenaar. All Rights Reserved.
#
# Licensed under the Simplified BSD License. 
# See the LICENSE file for details.
#
require 'yaml'

module Rack
class Config
  #
  # === Overview
  #
  # Rack::Config::Flexible is an alternative to Rack::Config,
  # offering much greater flexibility.
  #
  # Configuration options are stored as key-value pairs in _sections_,
  # partitioned by _environments_. For example:
  #
  #   + environment
  #     + section
  #       key -> value pairs
  #
  # A simple DSL is provided and can be used either within a passed
  # configuration block (to ::new), or to the #configuration method.
  #
  # Facilities are also provided to load whole environments, and sections
  # from either a single YAML file structured like, or from a directory tree.
  #
  # Note that values from a file/directory tree can be overridden with #configure, or
  # by passing a block to ::new.
  #
  # === DSL Example
  #
  # Here's an example showing the intended usage of the provided DSL:
  #
  #
  #    require 'rack/config/flexible'
  #
  #    use Rack::Config::Flexible do
  #      environment :production
  #      section :data
  #        set :key => 'value'
  #     
  #      environment :development
  #      section :data
  #        set :key => 'dev_value'
  #      
  #      # Set the current environment
  #      environment :production
  #    end
  #
  # +data.key+ would return 'value' in *production*, and 'dev_value' in *development*; and
  # would be accessed via the Rack environment like so:
  #
  #   env['rack.config']['data.key']
  #
  # Values can also be replaced by:
  #
  #   env['rack.config']['data.key'] = 'new_value'
  #
  # Keep in mind that anything that you would be able to do inside the block you're passing
  # to ::new, can also be done in a block passed to #configure since they both run in the
  # same scope.
  #
  # === Single-File Example
  #
  # Loading settings from a single file is extremely easy:
  #
  #    require 'rack/config/flexible'
  #
  #    use Rack::Config::Flexible :from_file => 'settings.yaml' do
  #      # Set the current environment to production
  #      environment :production
  #    end
  #
  # This expects the file to be laid out as follows:
  #
  #    environment:
  #      section:
  #        key: value
  #        ...
  #
  # It's important to note that when loading from YAML files, environment names and 
  # section names will be converted to +Symbol+s.
  #
  # === Directory Tree Example
  #
  # This is just as easy as loading from a single file. In this case, instead of
  # specifying a file name, we specify a path to a directory tree.
  #
  #    require 'rack/config/flexible'
  #
  #    use Rack::Config::Flexible :from_file => 'settings' do
  #      # Set the current environment to production
  #      environment :production
  #    end
  #
  # This expects the directory tree to be laid out as follows:
  #
  #    settings/environment/section.yaml
  #
  # where each directory under _settings_ is an _environment_, containg a separate YAML
  # file for each _section_. The YAML file itself will only hold
  # key-value pairs for that particular _section_.
  #
  # === Loading Individual Environments/Sections from YAML
  #
  # You can load individual _environment_ and _section_ bits from a YAML file as follows:
  #
  #    require 'rack/config/flexible'
  #
  #    use Rack::Config::Flexible do
  #      environment :production
  #      section :data, 'cfg/production/data.yaml'
  #     
  #      environment :development, 'cfg/development.yaml'
  #      
  #      # Set the current environment
  #      environment :production
  #    end
  #
  # Any other calls to #set after #environment or #section will override the data
  # loaded from the YAML file, if the same key is specified. Otherwise, they
  # will just add to the Hash per usual.
  #
  class Flexible
    def initialize(app,options={},&block)
      @app    = app
      @values = {}
      raise ArgumentError.new('`options\' must be a Hash') unless options.is_a?(Hash)

      if options.has_key?(:from_file) && ::File.directory?(options[:from_file])
        # Load from a directory tree
        Dir[options[:from_file] + '/*'].each { |env|
          next unless ::File.directory?(env)
          environment ::File.basename(env)
           
          Dir[env + '/*.yaml'].each { |sec|
            next unless ::File.file?(sec)
            section ::File.basename(sec,'.yaml'),sec
          }
        }
      elsif options.has_key?(:from_file) && ::File.exist?(options[:from_file])
        # Load from a single file
        @values = Hash[YAML.load_file(options[:from_file]).map { |k,v|
          [k.to_sym, Hash[v.map { |k,v| [ k.to_sym,v ]}]] if k.is_a?(String) && v.is_a?(Hash)
        }]
        @env    = @values.keys.first
        @sec    = @values[@env].keys.last
      end

      instance_eval(&block) if block_given?
    end

    def call(env)
      dup._call(env) # For thread safety...
    end

    def _call(env)
      env['rack.config'] = self
      @app.call(env)
    end

    def configure(&block)
      instance_eval(&block) if block_given?
    end

    # :category:DSL
    #
    # Set the current environment
    #
    # [env]
    #   Environment to use. Defaults to +:production+
    #
    # [data] 
    #   If this is a +String+, it's assumed to be the location of a YAML file to load from. 
    #   Otherwise, a +Hash+ of data for the environment. (Optional)
    #
    def environment(env,data=nil)
      raise ArgumentError.new('`env\' must be a String or Symbol') unless env.is_a?(String) || env.is_a?(Symbol)

      # Load from a hash (if specified) or create a new hash
      @env          = env.to_sym
      @values[@env] = {} unless @values.has_key?(@env) && @values[@env].is_a?(Hash)

      # Load from a file, or hash, if specified
      if data.is_a?(String) && ::File.exist?(data)
        @values[@env].merge!(Hash[YAML.load_file(data).map { |k,v| [k.to_sym, v] if k.is_a?(String) }])
        @sec = @values[@env].keys.last
      elsif data.is_a?(Hash)
        @values[@env].merge!(data)
      end
    end

    # :category:DSL
    #
    # Set the current section
    #
    # [sec]  Section to use. Defaults to +:default+
    # [vals] 
    #   Values to prepopulate this section with. 
    #   If this is a +String+, it's assumed to be the location of a YAML file to load from.
    #
    def section(sec,vals=nil)
      raise ArgumentError.new('`sec\' must be a String or Symbol') unless sec.is_a?(String) || sec.is_a?(Symbol)

      @sec = sec.to_sym
      @values[@env][@sec] = {} unless @values[@env][@sec].is_a?(Hash)
      @values[@env][@sec].merge!(vals) if vals.is_a?(Hash)

      # If vals is a string, it's assumed to be a YAML file
      @values[@env][@sec].merge!(YAML.load_file(vals)) if vals.is_a?(String) && ::File.exist?(vals)
    end

    # :category:DSL
    #
    # Add/Update a value to/in the current section
    #
    # [vals] +Hash+ Keys/Value(s) to set
    #
    def set(vals)
      raise ArgumentError.new('`vals\' must be a Hash') unless vals.is_a?(Hash)
      @values[@env][@sec].merge!(vals)
    end

    #
    # Hash-like accessor for config data
    #
    # [idx] Path to the requested item, starting with the section (e.g. +default.key.subkey+)
    #
    # Returns the value, or +nil+ if the value cannot be located
    #
    def [](idx)
      manipulate_element(idx)
    end

    #
    # Hash-like modifier for config data
    #
    # This will replace the value at +idx+ with +value+ if, and only if,
    # +idx+ already exists.
    #
    # [idx]   Path to the requested item, starting with the section (e.g. +default.key.subkey+)
    # [value] New value to set
    #
    def []=(idx,value)
      raise ArgumentError.new('`idx\' must be a String') unless idx.is_a?(String)
      manipulate_element(idx,value)
    end

protected
    #
    # Manipulate (or lookup) the element specified by +idx+
    #
    def manipulate_element(idx,value=nil)
      raise ArgumentError.new('`idx\' must be a String') unless idx.is_a?(String)
      idx = idx + '.' unless idx.index('.')
      tmph = nil ; pieces = idx.split(/\.+/)

      pieces.each_with_index { |part,i|
        # Look for the section
        if tmph.nil?
          tmph   = @values[@env][part]
          tmph ||= @values[@env][part.to_sym]
          next
        end

        # Return nil if we can't find the value
        return nil unless tmph.is_a?(Hash) && (tmph.has_key?(part) || tmph.has_key?(part.to_sym))

        # Otherwise, return or replace the value when we do find it
        if i == (pieces.size - 1) && !value.nil?
           tmph.has_key?(part) ? tmph[part] = value : tmph[part.to_sym] = value
        else
           tmph = tmph.has_key?(part) ? tmph[part] : tmph[part.to_sym]
        end
      }

      return tmph
    end
  end
end
end

# vi:set ts=2 sw=2 expandtab sta:
