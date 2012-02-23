# The Marionette Collective Packge Tool
#
# Basic implementaion of Os package creation.
module MCollective
  module PluginPackager
    class Ospackage < PluginPackager::Base
      require 'fpm/program'
      require 'facter'

      attr_accessor :packagename, :postinstall, :tmp_dir, :libdir, :meta
      attr_accessor :dependencies, :agent, :appplication, :iteration, :vendor
      attr_accessor :target_dir

      def initialize

        if Facter.value("osfamily").downcase == "redhat"
          @libdir = "usr/libexec/mcollective/mcollective/"
          @package_type = "rpm"
        elsif Facter.value("osfamily").downcase == "debian"
          @libdir = "usr/share/mcollective/plugins/mcollective"
          @package_type = "deb"
        end

        @postinstall = nil
        @tmp_dir = Dir.mktmpdir("mcollective_plugin_packager")
        @dependencies = false
        @agent = false
        @application = false
        @iteration = "1"
        @vendor = "Unknown"
        @target_dir = nil
      end

      # Creates all defined packages
      def create_package
        @meta = create_metadata
        @packagename = @meta[:name]
        identify_packages
        #TODO: Deal with fpm output
        create_dependencies if @dependencies
        FPM::Program.new.run params("agent") if @agent
        FPM::Program.new.run params("client") if @application
      end

      # Displays information relative to the package.
      def package_information
        @meta = create_metadata
        @packagename = @meta[:name]
        puts "\nPackage information : #{@packagename}"
        puts "---------"
        puts "Output format : #{@package_type}"
        @meta.each do |k, v|
          puts "#{k} : #{v}"
        end

        puts
        puts "Files included in package :"
        Dir.glob("#{@target_dir}**/*").each do |file|
          puts "\t#{file}"
        end
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
      # TODO: Consider moving this up to package when we've added more complex plugin types
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
    end
  end
end
