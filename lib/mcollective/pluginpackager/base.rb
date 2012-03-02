module MCollective
  module PluginPackager
    class Base
      require 'fileutils'
      require 'tmpdir'

      #Available list of packages
      def packages
        ["util", "agent", "application"]
      end

      # Deletes temp directories created during package creation.
      def clean_up
        FileUtils.rm_r @tmp_dir
      end

      # Create temp directories and copy package files
      def prepare_package(type)
        @tmp_dir = Dir.mktmpdir("mcollective_plugin_packager")
        working_dir = File.join(@tmp_dir, @libdir)
        #TODO: Find another tmpdir implementation that works on ruby 1.8.5
        FileUtils.mkdir_p working_dir

        case type
        when "util", "common"
          FileUtils.cp_r "#{@target_dir}util", working_dir
          @dependencies = true
        when "agent"
          #TODO:Temporary solution to debian not letting multiple packages look after
          #one file. Currently packaging ddl's with clients
          FileUtils.mkdir File.join(working_dir, "agent")
          ddls = Dir.glob("#{@target_dir}**/*.ddl")
          FileUtils.cp(Dir.glob("#{@target_dir}**/*") - ddls, File.join(working_dir, "agent"))
          @agent = true
        when "application", "client"
          FileUtils.cp_r "#{@target_dir}application", working_dir
          FileUtils.mkdir File.join(working_dir, "agent")
          FileUtils.cp Dir.glob("#{@target_dir}**/*.ddl").first, File.join(working_dir, "agent")
          @application = true
        else
          raise "Undefined Plugin Type"
        end
      end

      # Identifies and loads plugin meta data from ddl
      def create_metadata
        ddl = MCollective::RPC::DDL.new("package", false)
        ddl.instance_eval File.read(Dir.glob("#{@target_dir}**/*.ddl").first)
        @meta = ddl.meta
        rescue
          raise "Could not read agent DDL File"
      end

      # Checks if dir is present and not empty
      def check_dir(dir)
        File.directory?(File.join(Dir.pwd, dir)) && !Dir.glob(File.join(Dir.pwd, dir) + "/*").empty?
      end

      # Extended package description
      def package_description(dir)
        case dir
        when "agent"
          "Agent plugin for #{@packagename}."
        when "application", "client"
          "Client plugin for #{@packagename}."
        when "util",  "common"
          "Common libraries for #{@packagename}."
        end
      end

      def package_dirs(package)
        case package
        when "agent"
          [File.join(@libdir, "agent")]
        when "application", "client"
          [File.join(@libdir,"application"),File.join(@libdir, "agent")]
        when "util", "common"
          [File.join(@libdir, "util")]
        end
      end

      def package_contents(dir)
        case dir
        when "agent"
          Dir.glob("#{@target_dir}agent/**")
        when "application", "client"
          Dir.glob("#{@target_dir}application/**") + Dir.glob("#{@target_dir}agent/*.ddl")
        when "util", "common"
          Dir.glob("#{@target_dir}util/**")
        end
      end

    end
  end
end
