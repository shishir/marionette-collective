module MCollective
  class Application::Plugin<Application

    #Overriden rpcoptions removes standard mcollective flags. TODO:Make a ticket for RIP to change in MCollective
    def rpcoptions
      oparser = MCollective::Optionparser.new({:verbose => false, :progress_bar => true}) #removed filters param

      def oparser.parse
        yield(@parser, @options) if block_given?

        [@include].flatten.compact.each do |i|
          options_name = "add_#{i}_options"
          send(options_name)  if respond_to?(options_name)
        end

        @parser.environment("MCOLLECTIVE_EXTRA_OPTS")
        @parser.on('-c', '--config FILE', 'Load configuratuion from file rather than default') do |f|
          @options[:config] = f
        end

        @parser.parse!

        @options[:collective] = Config.instance.main_collective unless @options.include?(:collective)

        @options
      end

      options = oparser.parse do |parser, options|
        if block_given?
          yield(parser, options)
        end
      end
    end

    attr_accessor :package_plugin

    description "MCollective Plugin Application"
    usage <<-END_OF_USAGE
mco plugin [info|package] [options] <directory>

   info : Display plugin information including package details.
package : Create all available plugin packages.
    END_OF_USAGE

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

    option  :format,
      :description => "Package output format. Defaults to rpm or deb",
      :arguments => ["--format OUTPUTFORMAT"],
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
      if configuration[:format]
        begin
          MCollective::PluginManager["#{configuration[:format]}package_packager"]
        rescue Exception => e
          raise "Cannot load plugin - #{configuration[:format]}"
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
    end

    # Creates a package. Note that all package inplementations must must implement
    # create_package()
    def create_package
      prepare_package
      @package_plugin.create_package
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
