require 'java'

module MCollective
    module Connector
        # Handles sending and receiving messages over the Stomp protocol for JRuby
        #
        # A simple plugin that speaks STOMP from within JRuby, this is a proof of
        # concept, we should be using native JMS instead.
        #
        #    connector = jstomp
        #    plugin.stomp.host = stomp.your.net
        #    plugin.stomp.port = 6163
        #    plugin.stomp.user = you
        #    plugin.stomp.password = secret
        #
        # All of these can be overriden per user using environment variables:
        #
        #    STOMP_SERVER, STOMP_PORT, STOMP_USER, STOMP_PASSWORD
        #
        # For this to work you should have the ActiveMQ jars in your class path
        #
        # KNOWN ISSUES:
        # Does not work well with Marshal based security plugins, Marshal data
        # tend to have lots of null characters in it that confuse this library.
        class Jstomp<Base
            include_class "org.apache.activemq.transport.stomp.StompConnection"

            attr_reader :connection

            def initialize
                @config = Config.instance
                @subscriptions = []

                @log = Log.instance
            end

            # Connects to the Stomp middleware
            def connect
                if @connection
                    @log.debug("Already connection, not re-initializing connection")
                    return
                end

                begin
                    host = nil
                    port = nil
                    user = nil
                    password = nil

                    host = get_env_or_option("STOMP_SERVER", "stomp.host")
                    port = get_env_or_option("STOMP_PORT", "stomp.port", 6163).to_i
                    user = get_env_or_option("STOMP_USER", "stomp.user")
                    password = get_env_or_option("STOMP_PASSWORD", "stomp.password")

                    @log.debug("Connecting to #{host}:#{port}")
                    @connection = StompConnection.new
                    @connection.open(host, port)
                    @connection.connect(user, password)
                rescue Exception => e
                    raise("Could not connect to Stomp Server: #{e}")
                end
            end

            # Receives a message from the Stomp connection
            def receive
                @log.debug("Waiting for a message from Stomp")
                msg = @connection.receive

                Request.new(msg.getBody)
            end

            # Sends a message to the Stomp connection
            def send(target, msg)
                @log.debug("Sending a message to Stomp target '#{target}'")

                # deal with deprecation warnings in newer stomp gems
                if @connection.respond_to?("publish")
                    @connection.publish(target, msg)
                else
                    @connection.send(target, msg)
                end
            end

            # Subscribe to a topic or queue
            def subscribe(source)
                unless @subscriptions.include?(source)
                    @log.debug("Subscribing to #{source}")
                    @connection.subscribe(source)
                    @subscriptions << source
                end
            end

            # Subscribe to a topic or queue
            def unsubscribe(source)
                @log.debug("Unsubscribing from #{source}")
                @connection.unsubscribe(source)
                @subscriptions.delete(source)
            end

            # Disconnects from the Stomp connection
            def disconnect
                @log.debug("Disconnecting from Stomp")
                @connection.disconnect
            end

            private
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
