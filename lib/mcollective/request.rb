module MCollective
    # A simple container class for messages from the middleware.
    #
    # By design we put everything we care for in a payload of the message and
    # do not rely on any headers, special data formats etc as produced by the
    # middleware, using this abstraction means we can enforce that
    class Request
        attr_reader :headers
        attr_accessor :reply_to, :payload

        def initialize(payload, headers={})
            @payload = payload
            @headers = headers

            @reply_to = nil
            @body = nil
        end
    end
end
# vi:tabstop=4:expandtab:ai
