module MCollective
    # Connector plugins handle the communications with the middleware, you can provide your own to speak
    # to something other than Stomp, your plugins must inherit from MCollective::Connector::Base and should
    # provide the following methods:
    #
    # connect       - Creates a connection to the middleware, no arguments should get its parameters from the config
    # receive       - Receive data from the middleware, should act like a blocking call only returning if/when data
    #                 was received.  It should get data from all subscribed channels/topics.  Individual messages
    #                 should be returned as MCollective::Request objects with the payload provided
    # send          - Takes a target and msg, should send the message to the supplied target topic or destination
    # subscribe     - Adds a subscription to a specific message source
    # unsubscribe   - Removes a subscription to a specific message source
    # disconnect    - Disconnects from the middleware
    # temp_target   - If your middleware has a concept of temp targets you can use this to create such targets
    #
    # These methods are all that's needed for a new connector protocol and should hopefully be simple
    # enough to not have tied us to Stomp.
    module Connector
        class Base
            def self.inherited(klass)
                PluginManager << {:type => "connector_plugin", :class => klass.to_s}
            end

            # Constructs a typical reply topic on a middleware with no special
            # temp-topic semantics, this is backward compat with how mcollective
            # always worked
            def temp_target(agent, type, collective)
                config = Config.instance

                ["#{config.topicprefix}#{collective}", agent, type].join(config.topicsep)
            end
        end
    end
end

# vi:tabstop=4:expandtab:ai
