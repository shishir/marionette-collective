module MCollective
  class Application::Plugin<Application

    #Overriden rpcoptions removes standard mcollective flags. TODO:Make a ticket for RIP to change in MCollective
    def rpcoptions
      oparser = MCollective::Optionparser.new({:verbose => false, :progress_bar => true}) #removed filters param

      options = oparser.parse do |parser, options|
        if block_given?
          yield(parser, options)
        end
      end
    end

    attr_accessor :package_plugin

    description "MCollective Plugin Application"

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
      :arguments => ["--iteration ITERATION"],
      :type => String

    option  :vendor,
      :description => "Vendor name",
      :arguments => ["--vendor VENDOR"],
      :type => String

    option  :ptype,
      :description => "Package output format. Defaults to rpm or deb",
      :arguments => ["--ptype OUTPUTFORMAT"],
      :type => String

    # Handle alternative format that optparser can't parse.
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

      @package_plugin = package_plugin

      case configuration[:action]
      when "package"
        create_package
      when "info"
        package_info
      else
        raise "#{configuration[:action]} is not a valid action for Plugin application."
      end
    end

    # Identifies and returns the correct plugin to be used for packaging.
    def package_plugin
      if configuration[:ptype]
        begin
          MCollective::PluginManager["#{configuration[:ptype]}package_packager"]
        rescue Exception => e
          raise "Cannot load plugin - #{configuration[:ptype]}"
        end
      else
        MCollective::PluginManager["ospackage_packager"]
      end
    end

    # Displays package information. Note that all package implementations must implement
    # package_information()
    def package_info
      prepare_package
      @package_plugin.package_information
      @package_plugin.clean_up
    end

    # Creates a package. Note that all package inplementations must must implement
    # create_package()
    def create_package
      prepare_package
      @package_plugin.create_package
      @package_plugin.clean_up
    end

    # Sets package plugin instance variables based on values parsed by optparse.
    def prepare_package
      @package_plugin.packagename = configuration[:packagename] if configuration[:packagename]
      @package_plugin.postinstall = configuration[:postinstall] if configuration[:postinstall]
      @package_plugin.iteration = configuration[:iteration] if configuration[:iteration]
      @package_plugin.vendor = configuration[:vendor] if configuration[:vendor]
      @package_plugin.target_dir = target if configuration[:target]
    end

    # Appends '/' to the target directory if missing
    def target
      if configuration[:target] =~ /^.*\/$/
        configuration[:target]
      else
        configuration[:target] += "/"
      end
    end
  end
end
