module MCollective

  module PluginPackager
    autoload :Base, "mcollective/pluginpackager/base"
  end

  class Plugins

    def initialize(pluginpackagers = [])
      @config = Config.instance
      @packagers = pluginpackagers
      raise("Configuration has not been loaded, can't load package plugins") unless @config.configured

      load_packagers
    end

    def clear!
      @packagers.each do |package|
        PluginManager.delete "#{package}_packager"
      end
    end

    def load_packagers
      clear!

      @config.libdir.each do |libdir|
        packagerdir = "#{libdir}/mcollective/pluginpackager"
        next unless File.directory?(packagerdir)

        Dir.new(packagerdir).grep(/\.rb$/).each do |packager|
          packagername = File.basename(packager, ".rb")
          classname = "MCollective::PluginPackager::#{packagername.capitalize}"
          PluginManager.loadclass(classname) unless PluginManager.include?("#{packagername}_packager")
          PluginManager << {:type => "#{packagername}_packager", :class => classname} unless PluginManager.include?("#{packagername}_packager")
          @packagers << packagername
        end
      end
    end
  end
end
