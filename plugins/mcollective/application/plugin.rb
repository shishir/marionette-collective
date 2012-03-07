module MCollective
  class Application::Plugin<Application
    description "MCollective Plugin Application"
    usage <<-END_OF_USAGE
mco plugin [info|package] [options] <directory>

   info : Display plugin information including package details.
package : Create all available plugin packages.
    END_OF_USAGE

    option  :pluginname,
            :description => "Plugin name",
            :arguments => ["-n", "--name NAME"],
            :type => String

    option :postinstall,
           :description => "Post install script",
           :arguments => ["--postinstall POSTINSTALL"],
           :type => String

    option :iteration,
           :description => "Iteration number",
           :arguments => ["--iteration ITERATION"],
           :type => String

    option :vendor,
           :description => "Vendor name",
           :arguments => ["--vendor VENDOR"],
           :type => String

    option :format,
           :description => "Package output format. Defaults to rpm or deb",
           :arguments => ["--format OUTPUTFORMAT"],
           :type => String

    option :plugintype,
           :description => "Plugin type.",
           :arguments => ["--plugintype PLUGINTYPE"],
           :type => String

    # Handle alternative format that optparser can't parse.
    def post_option_parser(configuration)
      if ARGV.length >= 1
        configuration[:action] = ARGV.delete_at(0)

        configuration[:target] = ARGV.delete_at(0) || "."
      end
    end

    def main
      raise "No action specified" unless configuration.include?(:action)

      set_plugin_type unless configuration[:plugintype]

      configuration[:format] = "ospackage" unless configuration[:format]

      plugin_class = PluginPackager[configuration[:plugintype]]
      packager = PluginPackager[configuration[:format]]

      plugin = plugin_class.new(configuration[:target], configuration[:pluginname], configuration[:vendor], configuration[:postinstall], configuration[:iteration])

      case configuration[:action]
        when "info"
          packager.new(plugin).package_information
        when "package"
          packager.new(plugin).create_packages
        else
          abort "error: actions are [info|package]"
      end
    end

    def directory_for_type(type)
      File.directory?(File.join(configuration[:target], type))
    end

    # Identify plugin type if not provided.
    def set_plugin_type
      if directory_for_type("agent") || directory_for_type("application")
        configuration[:plugintype] = "agent"
      end
    end
  end
end
