require 'mq'

module MCollective
    module Connector
        # Handles sending and receiving messages over the AMQP protocol using Bunny
        class AMQP<Base
            attr_reader :connection

            def initialize
                @config = Config.instance
                @log = Log.instance
            end

            # Connects to the AMQP middleware
            def connect
                begin
                    opts = {}

                    opts[:host] = ENV["AMQP_SERVER"] || @config.pluginconf["amqp.host"] || nil
                    opts[:port] = ENV["AMQP_PORT"] || @config.pluginconf["amqp.port"] || nil
                    opts[:user] = ENV["AMQP_USER"] || @config.pluginconf["amqp.user"] || nil
                    opts[:pass] = ENV["AMQP_PASSWORD"] || @config.pluginconf["amqp.password"] || nil

                    @log.debug("Connecting to amqp...amqp://#{opts[:host]}/")

                    Thread.new { EM.run }

                    @messages = Queue.new
                    @exchange = MQ.topic("mcollective")

                    queuename = @config.identity + "_" + $$.to_s
                    @log.debug("Creating queue #{queuename}")
                    @queue = MQ.queue(queuename)

                    fetch_messages
                rescue Exception => e
                    raise("Could not connect to AMQP Server #{e}")
                end
            end

            # Receives a message from the AMQP connection
            def receive
                @log.debug("Looking for messages from AMQP")
                msg = @messages.pop
                Request.new(msg)
            end

            # Sends a message to the AMQP connection
            def send(target, msg)
                @log.debug("Sending a message to AMQP target '#{target}'")
                @exchange.publish(msg, :routing_key => target)
            end

            # Subscribe to a topic or queue
            def subscribe(source)
                @log.debug("Subscribing to #{source}")
                @queue.bind(@exchange, :key => source)
            end

            # Subscribe to a topic or queue
            def unsubscribe(source)
                @log.debug("Unsubscribing from #{source}")
                @queue.unbind(@exchange, :key => source)
            end

            # Disconnects from the AMQP connection
            def disconnect
                @log.debug("Disconnecting from AMQP")
                MQ.close
            end

            private
            def fetch_messages
                EM.schedule do
                    @queue.subscribe do |msg|
                        @log.debug("Found a message on AMQP")
                        @messages << msg
                        @log.debug("Added messages to @messages queue")
                    end
                end
            end
        end
    end
end

# vi:tabstop=4:expandtab:ai
