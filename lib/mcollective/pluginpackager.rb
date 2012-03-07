module MCollective
  module PluginPackager
    # Plugin definition classes
    autoload :Agent, "mcollective/pluginpackager/agent"

    # Package implementation classes
    autoload :Ospackage, "mcollective/pluginpackager/packagers/ospackage"

    def self.[](klass)
      const_get(klass.capitalize)
    end
  end
end
