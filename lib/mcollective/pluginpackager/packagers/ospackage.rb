# MCollective plugin packager general OS implementation.
module MCollective
  module PluginPackager

    class Ospackage
      gem 'fpm', '>= 0.3.11' # TODO: Update to 0.3.12 when Sissel pushes new version of fpm

      require 'fpm/program'
      require 'facter'
      require 'tmpdir' # TODO: Change to a 1.8.5 valid implementation

      attr_accessor :package, :libdir, :package_type, :common_dependency, :tmpdir, :workingdir

      # Create packager object with package parameter containing list of files,
      # dependencies and package metadata
      def initialize(package)

        osfamily = Facter.value("osfamily")

        unless osfamily
          abort "Missing osfamily fact. Newer version of facter needed"
        end

        if osfamily.downcase == "redhat"
          @libdir = "usr/libexec/mcollective/mcollective/"
          @package_type = "rpm"
          abort "error: pakcage rpm-build is not installed." unless rpmbuild?
        elsif osfamily.downcase == "debian"
          @libdir = "usr/share/mcollective/plugins/mcollective"
          @package_type = "deb"
        end

        @package = package
      end

      # Checks if rpmbuild executable is present.
      def rpmbuild?
        ENV["PATH"].split(File::PATH_SEPARATOR).each do |path|
          rpmbuild = File.join(path, "rpmbuild")

          if File.exist?(rpmbuild)
            return true
          end
        end
        false
      end

      # Iterate package list creating tmp dirs, building the packages
      # and cleaning up after itself.
      def create_packages
        @package.packagedata.each do |type, data|
          @tmpdir = Dir.mktmpdir("mcollective_packager")
          @workingdir = File.join(@tmpdir, @libdir)
          FileUtils.mkdir_p @workingdir
          prepare_tmpdirs data
          create_package type, data
          cleanup_tmpdirs
        end
      end

      # Creates a system specific package with FPM
      def create_package(type, data)
        ::FPM::Program.new.run params(type, data)
      end

      # Constructs the list of FPM paramaters
      def params(type, data)
        params = standard_params(type)
        params += package_dependencies(data[:dependencies]) unless data[:dependencies].empty?
        params += metadata(data)
        params += postinstall if @package.postinstall
        params << @libdir
      end

      # Standard list of FPM parameters
      def standard_params(type)
        ["-s", "dir", "-C", @tmpdir, "-t", @package_type, "-a", "all", "-n", "mcollective-#{@package.metadata[:name]}-#{type}",
          "-v", @package.metadata[:version], "--iteration", @package.iteration.to_s]
      end

      # Dependencies on other packages in the mcollective package type (Like Agent)
      # and mcollective itself.
      def package_dependencies(dependencies)
        [Array.new(dependencies.size, "-d"), dependencies].transpose.flatten
      end

      def metadata(data)
        ["--url", @package.metadata[:url], "--description", @package.metadata[:description] + "\n\n#{data[:description]}",
        "--license", @package.metadata[:license], "--maintainer", @package.metadata[:author], "--vendor", @package.vendor]
      end

      def postinstall
        ["--post-install", @package.postinstall]
      end

      # Creates temporary directories and sets working directory from which
      # the packagke will be built.
      def prepare_tmpdirs(data)
        data[:files].each do |file|
          targetdir = File.join(@workingdir, File.dirname(file).gsub(@package.target_path, ""))
          target = FileUtils.mkdir(targetdir) unless File.directory? targetdir
          FileUtils.cp_r(file, targetdir)
        end
      end

      # Remove temp directories created during packaging.
      def cleanup_tmpdirs
        FileUtils.rm_r @tmpdir
      end

      def package_information
        info = %Q[
        Plugin information : #{@package.metadata[:name]}
        ------------------------------------------------
               Plugin Type : #{@package.class.to_s.gsub(/^.*::/, "")}
     Package Output Format : #{@package_type.upcase}
                   Version : #{@package.metadata[:version]}
                 Iteration : #{@package.iteration}
                    Vendor : #{@package.vendor}
       Post Install Script : #{@package.postinstall}
                    Author : #{@package.metadata[:author]}
                   License : #{@package.metadata[:license]}
                       URL : #{@package.metadata[:url]}

       Identified Packages : ]

        first = true
        @package.packagedata.each do |name, data|
          unless data[:files].empty?
            if first
              info += "#{name}\n"
              first = false
            else
              info += "%29s#{name}\n" % " "
            end
          end
        end

        puts info
      end
    end
  end
end
