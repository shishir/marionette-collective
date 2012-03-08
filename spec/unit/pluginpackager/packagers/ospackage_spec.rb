require 'spec_helper'

module MCollective
  module PluginPackager
    describe Ospackage do

      before :all do
        class Ospackage
          ENV = {"PATH" => "."}
        end

        class TestPlugin
          attr_accessor :path, :packagedata, :metadata, :target_path, :vendor, :iteration
          attr_accessor :postinstall

          def initialize
            @path = "/tmp"
            @packagedata = {:testpackage => {:files => ["/tmp/test.rb"],
                                             :dependencies => ["mcollective"],
                                             :description => ["testpackage"]}}
            @iteration = 1
            @postinstall = "/tmp/test.sh"
            @metadata = {:name => "testplugin",
                         :description => "A Test Plugin",
                         :author => "Psy",
                         :license => "Apache 2",
                         :version => "0",
                         :url => "http://foo.bar.com",
                         :timeout => 5}
            @vendor = "Puppet Labs"
            @target_path = "/tmp"
          end
        end

        @testplugin = TestPlugin.new
      end

      describe "#initialize" do
        it "should correctly identify a RedHat system" do
          File.expects(:exists?).with("/etc/redhat-release").returns(true)
          Ospackage.any_instance.expects(:build_tool?).with("rpmbuild").returns(true)

          ospackage = Ospackage.new(@testplugin)
          ospackage.libdir.should == "usr/libexec/mcollective/mcollective/"
          ospackage.package_type.should == "rpm"
        end

        it "should correctly identify a Debian System" do
          File.expects(:exists?).with("/etc/redhat-release").returns(false)
          File.expects(:exists?).with("/etc/debian_version").returns(true)
          Ospackage.any_instance.expects(:build_tool?).with("ar").returns(true)

          ospackage = Ospackage.new(@testplugin)
          ospackage.libdir.should == "usr/share/mcollective/plugins/mcollective"
          ospackage.package_type.should == "deb"
        end

        it "should raise an exception if it cannot identify the operating system" do
          File.expects(:exists?).with("/etc/redhat-release").returns(false)
          File.expects(:exists?).with("/etc/debian_version").returns(false)

          expect{
            ospackage = Ospackage.new(@testplugin)
          }.to raise_exception "error: cannot identify operating system."
        end

        it "should identify if rpmbuild is present for RedHat systems" do
          File.expects(:exists?).with("/etc/redhat-release").returns(true)
          File.expects(:exists?).with("./rpmbuild").returns(true)
          ospackage = Ospackage.new(@testplugin)
        end

        it "should raise an exception if rpmbuild is not present for RedHat systems" do
          File.expects(:exists?).with("/etc/redhat-release").returns(true)
          File.expects(:exists?).with("./rpmbuild").returns(false)
          expect{
            ospackage = Ospackage.new(@testplugin)
          }.to raise_error "error: package 'rpm-build' is not installed."
        end

        it "should identify if ar is present for Debian systems" do
          File.expects(:exists?).with("/etc/redhat-release").returns(false)
          File.expects(:exists?).with("/etc/debian_version").returns(true)
          File.expects(:exists?).with("./ar").returns(true)

          ospackage = Ospackage.new(@testplugin)
        end

        it "should raise an exception if the build tool is not present" do
          File.expects(:exists?).with("/etc/redhat-release").returns(false)
          File.expects(:exists?).with("/etc/debian_version").returns(true)
          File.expects(:exists?).with("./ar").returns(false)
          expect{
            ospackage = Ospackage.new(@testplugin)
          }.to raise_error "error: package 'ar' is not installed."
        end
      end

      describe "#create_packages" do
        it "should prepare temp directories, create a package and clean up when done" do
          File.expects(:exists?).with("/etc/redhat-release").returns(true)
          Ospackage.any_instance.expects(:build_tool?).with("rpmbuild").returns(true)
          Dir.expects(:mktmpdir).with("mcollective_packager").returns("/tmp/mcollective_packager")
          FileUtils.expects(:mkdir_p).with("/tmp/mcollective_packager/usr/libexec/mcollective/mcollective/")

          ospackage = Ospackage.new(@testplugin)
          ospackage.expects(:prepare_tmpdirs).once
          ospackage.expects(:create_package).once
          ospackage.expects(:cleanup_tmpdirs).once

          ospackage.create_packages
        end
      end

      describe "#create_package" do
        it "should run fpm with the correct parameters" do
          File.expects(:exists?).with("/etc/redhat-release").returns(true)
          Ospackage.any_instance.expects(:build_tool?).with("rpmbuild").returns(true)

          ospackage = Ospackage.new(@testplugin)
          ospackage.expects(:params)

          fpm = mock
          ::FPM::Program.expects(:new).returns(fpm).once
          fpm.expects(:run).once

          ospackage.create_package(:testpackage, @testplugin.packagedata[:testpackage])
        end
      end

      describe "#params" do
        it "should create all paramaters needed by fpm" do
          File.expects(:exists?).with("/etc/redhat-release").returns(true)
          Ospackage.any_instance.expects(:build_tool?).with("rpmbuild").returns(true)

          ospackage = Ospackage.new(@testplugin)
          ospackage.expects(:standard_params).with(:testpackage).returns([])
          ospackage.expects(:package_dependencies).with(["mcollective"]).returns([])
          ospackage.expects(:metadata).with(@testplugin.packagedata[:testpackage]).returns([])

          ospackage.params(:testpackage, @testplugin.packagedata[:testpackage])
        end
      end

      describe "#standard_params" do
        it "should return correctly formatted standard params for fpm" do
          File.expects(:exists?).with("/etc/redhat-release").returns(true)
          Ospackage.any_instance.expects(:build_tool?).with("rpmbuild").returns(true)

          ospackage = Ospackage.new(@testplugin)
          params = ospackage.standard_params(:testpackage)
          params.should == ["-s", "dir", "-C", @tmpdir, "-t", "rpm", "-a", "all", "-n",
                           "mcollective-testplugin-testpackage", "-v", "0", "--iteration", "1"]
        end
      end

      describe "#package_dependencies" do
        it "should return dependencies in the correct format" do
          File.expects(:exists?).with("/etc/redhat-release").returns(true)
          Ospackage.any_instance.expects(:build_tool?).with("rpmbuild").returns(true)

          ospackage = Ospackage.new(@testplugin)
          params = ospackage.package_dependencies(["mcollective"])
          params.should == ["-d", "mcollective"]
          params = ospackage.package_dependencies(["mcollective", "another-dependency"])
          params.should == ["-d", "mcollective", "-d", "another-dependency"]
        end
      end

      describe "#metadata" do
        it "should return metadata parameters" do
          File.expects(:exists?).with("/etc/redhat-release").returns(true)
          Ospackage.any_instance.expects(:build_tool?).with("rpmbuild").returns(true)

          ospackage = Ospackage.new(@testplugin)
          params = ospackage.metadata(@testplugin.packagedata[:testpackage])
          params.should == ["--url", "http://foo.bar.com", "--description",
            "A Test Plugin\n\ntestpackage", "--license", "Apache 2", "--maintainer", "Psy",
            "--vendor", "Puppet Labs"]
        end
      end

      describe "#postinstall" do
        it "should return postinstall parameters if post install script is defined" do
          File.expects(:exists?).with("/etc/redhat-release").returns(true)
          Ospackage.any_instance.expects(:build_tool?).with("rpmbuild").returns(true)

          ospackage = Ospackage.new(@testplugin)
          params = ospackage.postinstall
          params.should == ["--post-install", "/tmp/test.sh"]
        end
      end

      describe "#prepare_tmpdirs" do
        it "should create temp directories and copy package files" do
          File.expects(:exists?).with("/etc/redhat-release").returns(true)
          Ospackage.any_instance.expects(:build_tool?).with("rpmbuild").returns(true)
          FileUtils.expects(:mkdir).with("/tmp/mcollective_packager/")
          FileUtils.expects(:cp_r).with("/tmp/test.rb", "/tmp/mcollective_packager/")

          ospackage = Ospackage.new(@testplugin)
          ospackage.workingdir = "/tmp/mcollective_packager/"
          ospackage.prepare_tmpdirs(@testplugin.packagedata[:testpackage])
        end
      end

      describe "#cleanup_tmpdirs" do
        it "should remove temp directories" do
          File.expects(:exists?).with("/etc/redhat-release").returns(true)
          Ospackage.any_instance.expects(:build_tool?).with("rpmbuild").returns(true)
          FileUtils.expects(:rm_r).with("/tmp/mcollective_packager/")

          ospackage = Ospackage.new(@testplugin)
          ospackage.tmpdir = "/tmp/mcollective_packager/"
          ospackage.cleanup_tmpdirs
        end
      end
    end
  end
end
