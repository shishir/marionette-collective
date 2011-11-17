module MCollective
  module Translator
    autoload :Base, "mcollective/translator/base"

    def self.[](translator)
      klass = "MCollective::Translator::#{translator.capitalize}"
      pluginname = "#{translator}_translator"

      PluginManager.loadclass(klass) unless PluginManager.include?(pluginname)

      PluginManager[pluginname]
    end
  end
end
