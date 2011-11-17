module MCollective
  module Translator
    class Json
      class << self
        def translate(reply)
          reply.to_json
        end
      end
    end
  end
end
