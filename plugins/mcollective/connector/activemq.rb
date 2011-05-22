require 'stomp'

module MCollective
    module Connector
        # Handles sending and receiving messages over the Stomp protocol
        # to ActiveMQ servers.  This is not a general Stomp connector as
        # it impliments some ActiveMQ specific settings.
        #
        # This plugin supports version 1.1.6 and newer of the Stomp rubygem.
        #
        # Configuration is as follows:
        #
        #     connector = activemq
        #     plugin.activemq.pool.size = 2
        #
        #     plugin.activemq.pool.1.host = stomp1.your.net
        #     plugin.activemq.pool.1.port = 6163
        #     plugin.activemq.pool.1.user = you
        #     plugin.activemq.pool.1.password = secret
        #     plugin.activemq.pool.1.ssl = true
        #
        #     plugin.activemq.pool.2.host = stomp2.your.net
        #     plugin.activemq.pool.2.port = 6163
        #     plugin.activemq.pool.2.user = you
        #     plugin.activemq.pool.2.password = secret
        #     plugin.activemq.pool.2.ssl = false
        #
        # Using this method you can set environment variables STOMP_USER and
        # STOMP_PASSWORD. You have to supply the hostname for each pool member
        # in the config.  The port will default to 6163 if not specified.
        #
        # In addition you can set the following options
        #
        #     plugin.activemq.pool.initial_reconnect_delay = 0.01
        #     plugin.activemq.pool.max_reconnect_delay = 30.0
        #     plugin.activemq.pool.use_exponential_back_off = true
        #     plugin.activemq.pool.back_off_multiplier = 2
        #     plugin.activemq.pool.max_reconnect_attempts = 0
        #     plugin.activemq.pool.randomize = false
        #     plugin.activemq.pool.timeout = -1
        #     plugin.activemq.priority = 4
        class Activemq<Base
            attr_reader :connection

            def initialize
                @config = Config.instance
                @subscriptions = []
            end

            # Connects to the Stomp middleware
            def connect
                if @connection
                    Log.debug("Already connection, not re-initializing connection")
                    return
                end

                begin
                    @base64 = get_bool_option("activemq.base64", false)
                    @msgpriority = get_option("activemq.priority", 0).to_i

                    @connection = ::Stomp::Connection.new(build_connection)
                rescue Exception => e
                    raise("Could not connect to ActiveMQ Server: #{e.class}: #{e}")
                end
            end

            # creates a stomp 1.1.6 and newer connection hash
            def build_connection
                pools = @config.pluginconf["activemq.pool.size"].to_i
                hosts = []

                1.upto(pools) do |poolnum|
                    host = {}

                    host[:host] = get_option("activemq.pool.#{poolnum}.host")
                    host[:port] = get_option("activemq.pool.#{poolnum}.port", 6163).to_i
                    host[:login] = get_env_or_option("STOMP_USER", "activemq.pool.#{poolnum}.user")
                    host[:passcode] = get_env_or_option("STOMP_PASSWORD", "activemq.pool.#{poolnum}.password")
                    host[:ssl] = get_bool_option("activemq.pool.#{poolnum}.ssl", false)

                    Log.debug("Adding #{host[:host]}:#{host[:port]} to the connection pool")
                    hosts << host
                end

                raise "No hosts found for the ActiveMQ connection pool" if hosts.size == 0

                connection = {:hosts => hosts}

                # Various STOMP gem options, defaults here matches defaults for 1.1.6 the meaning of
                # these can be guessed, the documentation isn't clear
                connection[:initial_reconnect_delay] = get_option("activemq.pool.initial_reconnect_delay", 0.01).to_f
                connection[:max_reconnect_delay] = get_option("activemq.pool.max_reconnect_delay", 30.0).to_f
                connection[:use_exponential_back_off] = get_bool_option("activemq.pool.use_exponential_back_off", true)
                connection[:back_off_multiplier] = get_bool_option("activemq.pool.back_off_multiplier", 2).to_i
                connection[:max_reconnect_attempts] = get_option("activemq.pool.max_reconnect_attempts", 0)
                connection[:randomize] = get_bool_option("activemq.pool.randomize", false)
                connection[:backup] = get_bool_option("activemq.pool.backup", false)
                connection[:timeout] = get_option("activemq.pool.timeout", -1).to_i

                return connection
            end

            # Receives a message from the Stomp connection
            def receive
                Log.debug("Waiting for a message from Stomp")
                msg = @connection.receive

                # STOMP puts the payload in the body variable, pass that
                # into the payload of MCollective::Request and discard all the
                # other headers etc that stomp provides
                if @base64
                    Request.new(SSL.base64_decode(msg.body))
                else
                    Request.new(msg.body)
                end
            end

            # Sends a message to the Stomp connection
            def send(target, msg)
                Log.debug("Sending a message to Stomp target '#{target}'")

                msg = SSL.base64_encode(msg) if @base64

                @connection.publish(target, msg, msgheaders)
            end

            # Creates a target for a specific type of message and agent
            #
            # This will create a topic per agent and a single queue per
            # agent where each node will subscribe to the same queue but using JMS
            # selectors they will subscribe to messages directed just at them
            def make_target(agent, type, collective)
                raise("Unknown collective '#{collective}' known collectives are '#{@config.collectives.join ', '}'") unless @config.collectives.include?(collective)
                raise("Invalid or unsupported target type #{type}") unless [:broadcast, :directed, :reply].include?(type)

                target = {:headers => {},
                          :target  => nil}

                case type
                    when :broadcast
                        target[:target] = "/topic/#{collective}.#{agent}.command"

                    when :directed
                        target[:target] = "/queue/#{collective}.#{agent}.command"
                        target[:headers] = {"selector" => "mcollective_identity = '#{@config.identity}'"}

                    when :reply
                        # in future we'll use the excellent temp-queues provided by activemq,
                        # for now we'll just do something backwards compat
                        #
                        # target[:target] = "/temp-queue/#{collective}.#{agent}.#{@config.identity}.reply"
                        target[:target] = "/topic/#{collective}.#{agent}.reply"
                end

                return target
            end

            # Subscribe to destination for a specific agent
            # types can be:
            #
            #  - :broadcast - a subscription used for receiving braodcast messages
            #                 like a topic in the Stomp protocol
            #  - :directed  - a subscription for point to point requests
            #                 like a queue in the Stomp protocol
            #  - :reply     - a subscription for replies back from agents this
            #                 could be a topic or temp-queue etc in the Stomp protocol
            def subscribe(agent, type, collective)
                source = make_target(agent, type, collective)

                if source[:target]
                    unless @subscriptions.include?(source)
                        Log.debug("Subscribing to #{source[:target]} for agent #{type} #{agent} in collective #{collective}")
                        @connection.subscribe(source[:target], source[:headers])
                        @subscriptions << source
                    end
                end

                return source[:target]
            end

            # Subscribe to a topic or queue
            def unsubscribe(agent, type, collective)
                source = make_target(agent, type, collective)

                if source[:target]
                    Log.debug("Unsubscribing from #{source[:target]} for agent #{type} #{agent} in collective #{collective}")
                    @connection.unsubscribe(source[:target])
                    @subscriptions.delete(source)
                end
            end

            # Disconnects from the Stomp connection
            def disconnect
                Log.debug("Disconnecting from Stomp")
                @connection.disconnect
            end

            private
            def msgheaders
                headers = {}
                headers = {"priority" => @msgpriority} if @msgpriority > 0

                return headers
            end

            # looks in the environment first then in the config file
            # for a specific option, accepts an optional default.
            #
            # raises an exception when it cant find a value anywhere
            def get_env_or_option(env, opt, default=nil)
                return ENV[env] if ENV.include?(env)
                return @config.pluginconf[opt] if @config.pluginconf.include?(opt)
                return default if default

                raise("No #{env} environment or plugin.#{opt} configuration option given")
            end

            # looks for a config option, accepts an optional default
            #
            # raises an exception when it cant find a value anywhere
            def get_option(opt, default=nil)
                return @config.pluginconf[opt] if @config.pluginconf.include?(opt)
                return default if default

                raise("No plugin.#{opt} configuration option given")
            end

            # gets a boolean option from the config, supports y/n/true/false/1/0
            def get_bool_option(opt, default)
                return default unless @config.pluginconf.include?(opt)

                val = @config.pluginconf[opt]

                if val =~ /^1|yes|true/
                    return true
                elsif val =~ /^0|no|false/
                    return false
                else
                    return default
                end
            end
        end
    end
end

# vi:tabstop=4:expandtab:ai
