module MCollective
  module PluginPackager
    class Ospackage < PluginPackager::Base

      #TODO: Update to > 0.3.11 when Sissel pushed new version
      gem 'fpm', '>= 0.3.11'

      require 'fpm/program'
      require 'facter'

      attr_accessor :packagename, :postinstall, :tmp_dir, :libdir, :meta
      attr_accessor :dependencies, :agent, :application, :iteration, :vendor
      attr_accessor :target_dir

      def initialize
        osfamily = Facter.value("osfamily")

        unless osfamily
          abort "Missing osfamily fact. Newer version of facter needed"
        end

        if osfamily.downcase == "redhat"
          @libdir = "usr/libexec/mcollective/mcollective/"
          @package_type = "rpm"
        elsif osfamily.downcase == "debian"
          @libdir = "usr/share/mcollective/plugins/mcollective"
          @package_type = "deb"
        end

        @iteration = "1"
        @vendor = "Puppet Labs"
        @meta = create_metadata
        @packagename = @meta[:name].downcase.gsub(" ", "_")
      end

      # Creates all defined packages
      def create_package
        packages.each do |package|
          if check_dir package
            prepare_package package
            ::FPM::Program.new.run params(package)
            clean_up
          end
        end
      end

      # Construct parameter array used by fpm for standard packages
      def params(dir)
        params = standard_flags(dir)
        params += mcollective_dependencies(dir)
        params += ["-d", "mcollective-#{@packagename}-common >= #{@meta[:version]}"] if @dependencies
        params += ["--post-install", @postinstall] if @postinstall
        params += metadata(dir)
        params += package_dirs(dir)
      end

      # Options common to all type of rpm packages created by fpm
      def standard_flags(dir)
        # TODO:Fix this hash crap when build works
        package_names = {"application" => "client", "agent" => "agent", "util" => "common"}
        params = ["-s", "dir", "-C", @tmp_dir, "-t", @package_type, "-a",
          "all", "-n", "mcollective-#{@packagename}-#{package_names[dir]}", "-v",
        @meta[:version], "--iteration", @iteration]
      end

      # Meta data from mcollective
      def metadata(dir)
        ["--url", @meta[:url], "--description", @meta[:description] + "\n#{package_description(dir)}",
        "--license", @meta[:license],
        "--maintainer", @meta[:author], "--vendor", @vendor]
      end

      # Package dependencies on specific parts of mcollective
      # TODO: This sucks. Move it later when we add package types
      def mcollective_dependencies(package_type)
        case package_type
        when 'agent'
          return ["-d", "mcollective"]
        when 'application', "client"
          return ["-d", "mcollective-client"]
        when 'common', "util"
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

        Agent #{@package_type.upcase} Contents : #{package_contents("agent").join(", ")}
       Client #{@package_type.upcase} Contents : #{package_contents("application").join(", ")}
       Common #{@package_type.upcase} Contents : #{package_contents("util").join(", ")}
        ]

        puts info
      end

    end
  end
end
