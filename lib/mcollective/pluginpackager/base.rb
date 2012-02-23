# The Marionette Collective Package Tool
#
# Base class which all external package implementations extend.
module MCollective
  module PluginPackager
    class Base
      require 'fileutils'
      require 'tmpdir'

      def identify_packages
        prepare_package :common if File.directory?(File.join(Dir.pwd, "util"))
        prepare_package :agent if File.directory?(File.join(Dir.pwd, "agent"))
        prepare_package :application if File.directory?(File.join(Dir.pwd, "application"))
      end

      def clean_up
        FileUtils.rm_r @tmp_dir
      end

      def prepare_package(type)
        tmpdir = File.join(@tmp_dir, @libdir)
        #TODO: Find another tmpdir implementation that works on ruby 1.8.5
        FileUtils.mkdir_p tmpdir

        case type
        when :common
          FileUtils.cp_r "#{@target_dir}util", tmpdir
          @dependencies = true
        when :agent
          FileUtils.cp_r "#{@target_dir}agent", tmpdir
          @agent = true
        when :application
          FileUtils.cp_r "#{@target_dir}application", tmpdir
          @application = true
        else
          raise "Undefined Plugin Type"
        end
      end

      def create_metadata
        ddl = MCollective::RPC::DDL.new("package", false)
        ddl.instance_eval File.read(Dir.glob("#{@target_dir}**/*.ddl").first)
        @meta = ddl.meta
        rescue
          raise "Could not read agent DDL File"
      end
    end
  end
end
