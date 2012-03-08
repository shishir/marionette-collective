module MCollective
  module PluginPackager
    # MCollective plugin packager general OS implementation.
    class Ospackage
      gem 'fpm', '>= 0.3.11' # TODO: Update to 0.3.12 when Sissel pushes new version of fpm

      require 'fpm/program'
      require 'facter'
      require 'tmpdir' # TODO: Change to a 1.8.5 valid implementation

      attr_accessor :package, :libdir, :package_type, :common_dependency, :tmpdir, :workingdir

      # Create packager object with package parameter containing list of files,
      # dependencies and package metadata
      def initialize(package)

        if File.exists?("/etc/redhat-release")
          @libdir = "usr/libexec/mcollective/mcollective/"
          @package_type = "rpm"
          raise "error: package 'rpm-build' is not installed." unless build_tool?("rpmbuild")
        elsif File.exists?("/etc/debian_version")
          @libdir = "usr/share/mcollective/plugins/mcollective"
          @package_type = "deb"
          raise "error: package 'ar' is not installed." unless build_tool?("ar")
        else
          raise "error: cannot identify operating system."
        end

        @package = package
      end

      # Checks if rpmbuild executable is present.
      def build_tool?(build_tool)
        ENV["PATH"].split(File::PATH_SEPARATOR).each do |path|
          builder = File.join(path, build_tool)

          if File.exists?(builder)
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
        ["-s", "dir", "-C", @tmpdir, "-t", @package_type, "-a", "all", "-n",
         "mcollective-#{@package.metadata[:name]}-#{type}", "-v",
          @package.metadata[:version], "--iteration", @package.iteration.to_s]
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
        FileUtils.rm_r @tmpdir if @tmpdir
      end

      # Displays the package metadata and detected files
      def package_information
        puts
        puts "%30s%s" % ["Plugin information : ", @package.metadata[:name]]
        puts "%30s%s" % ["-" * 22, "-" * 22]
        puts "%30s%s" % ["Plugin Type : ", @package.class.to_s.gsub(/^.*::/, "")]
        puts "%30s%s" % ["Package Output Format : ", @package_type.upcase]
        puts "%30s%s" % ["Version : ", @package.metadata[:version]]
        puts "%30s%s" % ["Iteration : ", @package.iteration]
        puts "%30s%s" % ["Vendor : ", @package.vendor]
        puts "%30s%s" % ["Post Install Script : ", @package.postinstall]
        puts "%30s%s" % ["Author : ", @package.metadata[:author]]
        puts "%30s%s" % ["License : ", @package.metadata[:license]]
        puts "%30s%s" % ["URL : ", @package.metadata[:url]]

        if @package.packagedata.size > 0
          @package.packagedata.each_with_index do |values, i|
            next if values[1][:files].empty?
            if i == 0
              puts "%30s%s" % ["Identified Packages : ", values[0]]
            else
              puts "%30s%s" % [" ", values[0]]
            end
        end

        end
      end
    end
  end
end
