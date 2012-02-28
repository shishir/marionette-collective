module MCollective
  module PluginPackager
    class Ospackage < PluginPackager::Base

      require 'fpm/program'
      require 'facter'

      attr_accessor :packagename, :postinstall, :tmp_dir, :libdir, :meta
      attr_accessor :dependencies, :agent, :application, :iteration, :vendor
      attr_accessor :target_dir

      def initialize
        if Facter.value("osfamily").downcase == "redhat"
          @libdir = "usr/libexec/mcollective/mcollective/"
          @package_type = "rpm"
        elsif Facter.value("osfamily").downcase == "debian"
          @libdir = "usr/share/mcollective/plugins/mcollective"
          @package_type = "deb"
        end

        @tmp_dir = Dir.mktmpdir("mcollective_plugin_packager")
        @iteration = "1"
        @vendor = "Puppet Labs"
        @meta = create_metadata
        @packagename = @meta[:name] unless @packagename
      end

      # Creates all defined packages
      def create_package
        identify_packages
        #TODO: Deal with fpm output
        create_dependencies if @dependencies
        FPM::Program.new.run params("agent") if @agent
        FPM::Program.new.run params("client") if @application
      end


      # Creates the common package for other packages to depend on
      def create_dependencies
        FPM::Program.new.run dep_params
      end

      # Construct parameter array used by fpm for standard packages
      def params(dir)
        params = standard_flags(dir)
        params += mcollective_dependencies(dir)
        params += ["-d", "mcollective-#{@packagename}-common >= #{@meta[:version]}"] if @dependencies
        params += ["--post-install", @postinstall] if @postinstall
        params += metadata
        params << File.join(@libdir, (dir == "client") ? "application" : dir)
      end

      # Constructs parameter array
      def dep_params
        params = standard_flags
        params += metadata
        params += mcollective_dependencies('common')
        params << File.join(@libdir, "util")
      end

      # Options common to all type of rpm packages created by fpm
      def standard_flags(dir = "common")
        params = ["-s", "dir", "-C", @tmp_dir, "-t", @package_type, "-a",
          "all", "-n", "mcollective-#{@packagename}-#{dir}", "-v",
        @meta[:version], "--iteration", @iteration]
      end

      # Meta data from mcollective
      def metadata
        ["--url", @meta[:url], "--description", @meta[:description],
        "--license", @meta[:license],
        "--maintainer", @meta[:author], "--vendor", @vendor]
      end

      # Package dependencies on specific parts of mcollective
      # TODO: This sucks. Move it later when we add package types
      def mcollective_dependencies(package_type)
        case package_type
        when 'agent'
          return ["-d", "mcollective"]
        when 'client'
          return ["-d", "mcollective-client"]
        when 'common'
          return ["-d", "mcollective-common"]
        else
          raise "Invalid package"
        end
      end

      # Displays information relative to the package.
      def package_information

        info = %Q[
        Plugin information : #{@packagename}
        ------------------------------------
              Outputformat : #{@package_type.upcase}
                   Version : #{@meta[:version]}
                 Iteration : #{@iteration}
                    Vendor : #{@vendor}
       Post Install Script : #{@postinstall ? @postinstall : "None"}
                    Author : #{@meta[:author]}
                   License : #{@meta[:license]}
                       Url : #{@meta[:url]}
                 Agent #{@package_type.upcase} Contents : #{package_contents("agent")}
                 Client #{@package_type.upcase} Contents : #{package_contents("application")}
                 Common #{@package_type.upcase} Contents : #{package_contents("util")}
        ]

        puts info
      end

      def package_contents(package)
        contents = Dir.glob("#{@target_dir}#{package}/**")
        if contents.size == 0
          "Not present"
        elsif contents.size == 1
          contents
        else
          "[#{contents.join(", ")}]"
        end
      end

    end
  end
end
