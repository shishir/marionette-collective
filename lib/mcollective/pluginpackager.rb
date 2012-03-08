module MCollective
  module PluginPackager
    # Plugin definition classes
    autoload :Agent, "mcollective/pluginpackager/agent"

    # Package implementation plugins
    def self.load_packagers
      Config.instance.libdir.each do |libdir|
        packagedir = "#{libdir}mcollective/pluginpackager"
        Dir.new(packagedir).grep(/\.rb$/).each do |packager|
          packagername = File.basename(packager, ".rb")
          classname = "MCollective::PluginPackager::#{packagername.capitalize}"
          PluginManager.loadclass(classname) unless PluginManager.include?("#{packagername.capitalize}")
        end
      end
    end

    def self.[](klass)
      const_get(klass.capitalize)
    end
  end
end
