module MCollective
  class Application::Plugin<Application
    description "Creates a package"

    option :action,
            :description => "Action to call",
            :arguments => ["-a", "--action"],
            :type => String

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

    option  :target,
            :description => "Target directory. Defaults to current working directory if omitted.",
            :arguments => ["--targetdir TARGET"],
            :type => String

    option  :test,
            :description => "Displays package information. Does not build package.",
            :arguments => ["--test"],
            :type => :bool,
            :default => "false"

    option  :outputformat,
            :description => "Package output format. Defaults to rpm or deb",
            :arguments => ["--outputformat"],
            :type => String

    def post_option_parser(configuration)
      if ARGV.length >= 1
        configuration[:action] = ARGV[0]
        ARGV.delete_at(0)
      end
    end

    def main
      unless configuration.include? :action
        raise "No action specified"
      end

      case configuration[:action]
      when "package"
        create_package
      else
        raise "#{configuration[:action]} is not a valid action for Plugin application."
      end
    end

    def create_package
      MCollective::Plugins.new
      unless configuration[:outputformat]
        create_os_package
      end
    end

    def create_os_package
      packager = MCollective::PluginManager["ospackage_packager"]
      prepare_package(packager)
      if configuration[:test] == "true"
        packager.package_information
      else
        packager.create_package
      end
      packager.clean_up
    end

    def prepare_package(packager)
      packager.packagename = configuration[:packagename] if configuration[:packagename]
      packager.postinstall = configuration[:postinstall] if configuration[:postinstall]
      packager.iteration = configuration[:iteration] if configuration[:iteration]
      packager.vendor = configuration[:vendor] if configuration[:vendor]
      packager.target_dir = configuration[:target] if configuration[:target]
    end

  end
end
