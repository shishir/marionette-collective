module MCollective
    class Application
        include RPC

        class << self
            def application_options
                intialize_application_options unless @application_options
                @application_options
            end

            def []=(option, value)
                intialize_application_options unless @application_options
                @application_options[option] = value
            end

            def [](option)
                intialize_application_options unless @application_options
                @application_options[option]
            end

            def description(descr)
                self[:description] = descr
            end

            def usage(usage)
                self[:usage] = usage
            end

            def option(name, arguments)
                opt = {:name => name,
                       :description => nil,
                       :arguments => [],
                       :type => String,
                       :required => false}

                arguments.each_pair{|k,v| opt[k] = v}

                self[:cli_arguments] << opt
            end

            def intialize_application_options
                @application_options = {:description   => nil,
                                        :usage         => nil,
                                        :cli_arguments => []}
            end
        end

        def initialize
            application_parse_options
        end

        def configuration
            @application_configuration ||= {}
            @application_configuration
        end

        def options
            @options
        end

        def application_parse_options
            @options = rpcoptions do |parser, options|
                parser.define_head application_description if application_description
                parser.banner = application_usage if application_usage

                application_cli_arguments.each do |carg|
                    opts_array = []

                    opts_array << :on

                    if carg[:arguments].is_a?(Array)
                        carg[:arguments].each {|a| opts_array << a}
                    else
                        opts_array << carg[:arguments]
                    end

                    opts_array << carg[:type] if carg[:type]

                    opts_array << carg[:description]

                    parser.send(*opts_array) do |v|
                        configuration[carg[:name]] = v
                    end
                end
            end

            # Check all required parameters were set
            validation_passed = true
            application_cli_arguments.each do |carg|
                if carg[:required]
                    unless configuration[ carg[:name] ]
                        validation_passed = false
                        STDERR.puts "The #{carg[:name]} option is mandatory"
                    end
                end
            end

            unless validation_passed
                STDERR.puts "\nPlease run with --help for detailed help"
                exit! 1
            end

            post_option_parser(configuration) if respond_to?(:post_option_parser)
        rescue Exception => e
            application_failure(e)
        end

        def application_description
            self.class.application_options[:description]
        end

        def application_usage
            self.class.application_options[:usage]
        end

        def application_cli_arguments
            self.class.application_options[:cli_arguments]
        end

        def application_failure(e)
            STDERR.puts "#{$0} failed to run: #{e} (#{e.class})"

            if options
                e.backtrace.each{|l| STDERR.puts "\tfrom #{l}"} if options[:verbose]
            else
                e.backtrace.each{|l| STDERR.puts "\tfrom #{l}"}
            end

            exit! 1
        end

        def run
            validate_configuration(configuration) if respond_to?(:validate_configuration)

            main
        rescue Exception => e
            application_failure(e)
        end

        # abstract
        def main
            STDERR.puts "Applications need to supply a 'main' method"
            exit 1
        end
    end
end
