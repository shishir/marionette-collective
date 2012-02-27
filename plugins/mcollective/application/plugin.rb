module MCollective
  class Application::Plugin<Application
    description "Creates a package"

    option  :packagename,
            :description => "Package name",
            :arguments => ["-n", "--name NAME"],
            :type => String

    option  :postinstall,
            :description => "Post install script",
            :arguments => ["--postinstall POSTINSTALL"],
            :type => String

    option  :iteration,
            :description => "Iteration number",
            :arguments => ["-i", "--iteration ITERATION"],
            :type => String

    option  :vendor,
            :description => "Vendor name",
            :arguments => ["-v", "--vendor VENDOR"],
            :type => String

    option  :outputformat,
            :description => "Package output format. Defaults to rpm or deb",
            :arguments => ["--outputformat"],
            :type => String

    def post_option_parser(configuration)
      if ARGV.length >= 1
        configuration[:action] = ARGV[0]
        ARGV.delete_at(0)
        if ARGV[0]
          configuration[:target] = ARGV[0]
          ARGV.delete_at(0)
        end
      end
    end

    def main
      raise "No action specified" unless configuration.include? :action

      MCollective::Plugins.new

      case configuration[:action]
      when "package"
        create_package
      when "info"
        package_info
      else
        raise "#{configuration[:action]} is not a valid action for Plugin application."
      end
    end

    def package_info
      packager = MCollective::PluginManager["ospackage_packager"]
      prepare_package(packager)
      packager.package_information
      packager.clean_up
    end

    def create_package
      case configuration[:outputformat]
      when "gem"
      else
        create_os_package
      end
    end

    def create_os_package
      packager = MCollective::PluginManager["ospackage_packager"]
      prepare_package(packager)
      packager.create_package
      packager.clean_up
    end

    def prepare_package(packager)
      packager.packagename = configuration[:packagename] if configuration[:packagename]
      packager.postinstall = configuration[:postinstall] if configuration[:postinstall]
      packager.iteration = configuration[:iteration] if configuration[:iteration]
      packager.vendor = configuration[:vendor] if configuration[:vendor]
      packager.target_dir = target if configuration[:target]
    end

    def target
      if configuration[:target] =~ /^.*\/$/
        configuration[:target]
      else
        configuration[:target] += "/"
      end
    end
  end
end
