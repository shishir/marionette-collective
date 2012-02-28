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
        @packagename = @meta[:name]
        @tmp_dir = Dir.mktmpdir("mcollective_plugin_packager")
        @libdir = "lib/mcollective/"
        @target_dir = nil
        identify_packages
      end

      def get_binding
        binding
      end

      # Creates gems if directories have been identified as present
      def create_package
        make_gem("agent") if @agent
        make_gem("client") if @application
        make_gem("common") if @dependencies
      end

      # Creates a gem of the packagetype.
      def make_gem(packagetype)
        @packagetype = packagetype
        specfile = ERB.new(File.read("#{Config.instance.libdir.first}/mcollective/pluginpackager/templates/gemspec.erb"))
        (File.open("#{@tmp_dir}/mcollective-#{@packagename}-#{@packagetype}.gemspec", "w") <<  specfile.result(self.get_binding)).close
        current_dir = FileUtils.pwd
        FileUtils.cd @tmp_dir
        %x[gem build "mcollective-#{@packagename}-#{@packagetype}.gemspec"]
        FileUtils.cp "mcollective-#{@packagename}-#{@packagetype}-#{@meta[:version]}.gem", current_dir
        FileUtils.cd current_dir
      end

      # Displays package information
      def package_information
        info = %Q[
          Plugin information : #{@packagename}
          -------------------------------------
                Outputformat : Gem
                     License : #{@meta[:license]}
                      Author : #{@meta[:author]}
                     Version : #{@meta[:version]}
                       Email : #{(@meta[:author] =~ /^.*(\<)(.*)(\>)$/) ? $2 : "Unknown"}
                 Description : #{@meta[:description]}
                     Summary : #{@meta[:description].first}
                    Homepage : #{@meta[:url]}
          Agent Gem Contents : #{gem_contents("agent")}
         Client Gem Contents : #{gem_contents("application")}
         Common Gem Contents : #{gem_contents("util")}
        ]
        puts info
      end

      def gem_contents(gem)
        contents = Dir.glob("#{@target_dir}#{gem}/**")
        if contents.size == 0
          "Not present"
        elsif contents.size == 1
          contents
        else
          "[#{contents.join(", ")}]"
        end
      end
    end
  end
end
