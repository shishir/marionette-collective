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
        @packagename = @meta[:name].downcase.gsub(" ", "_")
        @tmp_dir = Dir.mktmpdir("mcollective_plugin_packager")
        @libdir = "lib/mcollective/"
        @target_dir = nil
      end

      def get_binding
        binding
      end

      # Creates gems if directories have been identified as present
      def create_package
        packages.each do |package|
          if check_dir package
            prepare_package package
            make_gem(package)
            clean_up
          end
        end
      end

      # Creates a gem of the packagetype.
      def make_gem(packagetype)
        @packagetype = packagetype
        @package_names = {"application" => "client", "agent" => "agent", "util" => "common"}
        specfile = ERB.new(File.read("#{Config.instance.libdir.first}/mcollective/pluginpackager/templates/gemspec.erb"))
        (File.open("#{@tmp_dir}/mcollective-#{@packagename}-#{@package_names[@packagetype]}.gemspec", "w") <<  specfile.result(self.get_binding)).close
        current_dir = FileUtils.pwd
        FileUtils.cd @tmp_dir
        puts %x[gem build "mcollective-#{@packagename}-#{@package_names[@packagetype]}.gemspec"]
        FileUtils.cp "mcollective-#{@packagename}-#{@package_names[@packagetype]}-#{@meta[:version]}.gem", current_dir
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

          Agent Gem Contents : #{package_contents("agent").join(", ")}
         Client Gem Contents : #{package_contents("application").join(", ")}
         Common Gem Contents : #{package_contents("util").join(", ")}
        ]
        puts info
      end

    end
  end
end
