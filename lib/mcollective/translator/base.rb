module MCollective
  module Translator
    class Base
      # Register plugins that inherits base
      def self.inherited(klass)
        translator = klass.split("::").last
        PluginManager << {:type => "#{translator}_translator", :class => klass.to_s}
      end
    end
  end
end
