module MCollective

  #Overriden rpcoptions removes standard mcollective flags. TODO:Make a ticket for RIP to change in MCollective
  module RPC
    def rpcoptions
      oparser = MCollective::Optionparser.new({:verbose => false, :progress_bar => true}) #removed filters param

      def oparser.parse(&block)
        yield(@parser, @options) if block_given?

        #removed add_common_options

        [@include].flatten.compact.each do |i|
         options_name = "add_#{i}_options"
          send(options_name)  if respond_to?(options_name)
        end

        @parser.environment("MCOLLECTIVE_EXTRA_OPTS")

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
  end

  class Application::Plugin<Application

    attr_accessor :package_plugin

    description "MCollective Plugin management tool."

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

    option  :outputformat,
            :description => "Package output format. Defaults to rpm or deb",
            :arguments => ["--outputformat OUTPUTFORMAT"],
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

    def package_plugin
      case configuration[:outputformat]
      when "gem"
        MCollective::PluginManager["gempackage_packager"]
      else
        MCollective::PluginManager["ospackage_packager"]
      end
    end

    def package_info
      prepare_package
      @package_plugin.package_information
      @package_plugin.clean_up
    end

    def create_package
      prepare_package
      @package_plugin.create_package
      @package_plugin.clean_up
    end

    def prepare_package
      @package_plugin.packagename = configuration[:packagename] if configuration[:packagename]
      @package_plugin.postinstall = configuration[:postinstall] if configuration[:postinstall]
      @package_plugin.iteration = configuration[:iteration] if configuration[:iteration]
      @package_plugin.vendor = configuration[:vendor] if configuration[:vendor]
      @package_plugin.target_dir = target if configuration[:target]
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
