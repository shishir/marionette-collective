module MCollective
  module PluginPackager
    class Gempackage < PluginPackager::Base
      require 'erb'
      attr_accessor :packagename, :postinstall, :tmp_dir, :libdir, :meta
      attr_accessor :dependencies, :agent, :application, :iteration, :vendor
      attr_accessor :target_dir

      def initialize
        @libdir=""
        @meta = create_metadata
        @tmp_dir = Dir.mktmpdir("mcollective_plugin_packager")
        @packagename = @meta[:name]
        identify_packages
      end

      def get_binding
        binding
      end

      def create_package
        make_gem("agent") if @agent
        make_gem("client") if @application
        make_gem("common") if @dependencies
      end

      def make_gem(packagetype)
        @packagetype = packagetype
        specfile = ERB.new(File.read("#{Config.instance.libdir.first}/mcollective/pluginpackager/templates/gemspec.erb"))
        (File.open("#{@tmp_dir}/mcollective-#{@packagename}-#{@packagetype}.gemspec", "w") <<  specfile.result(self.get_binding)).close
        %x[gem build "#{@tmp_dir}/mcollective-#{@packagename}-#{@packagetype}.gemspec" --quiet]
      end
    end
  end
end
