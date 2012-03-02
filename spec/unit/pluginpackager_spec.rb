require 'spec_helper'
require '../../lib/mcollective/plugin'

module MCollective
  module PluginPackager
    describe PluginPackager::Base do
      before do
        class TestPackager < PluginPackager::Base
          attr_accessor :tmp_dir, :libdir, :dependencies, :agent, :application, :packagename
        end
        @testpackager = TestPackager.new
        @testpackager.libdir = "libdir"

        tmpfile = Tempfile.new("mc_plugin_packagers_spec")
        path = tmpfile.path
        tmpfile.close!

        @tmpdir = FileUtils.mkdir_p(path)
        @tmpdir = @tmpdir[0] if @tmpdir.is_a?(Array) # ruby 1.9.2
      end

      after do
        FileUtils.rm_r(@tmpdir) if File.exist? @tmpdir
      end

      describe "#packages" do
        it "should return an array of defined package types" do
          @testpackager.packages.class.should == Array
        end
      end

      describe "#clean_up" do
        it "should remove temporary direcories" do
          @testpackager.tmp_dir = @tmpdir
          @testpackager.clean_up
          (File.exist? @testpackager.tmp_dir).should == false
        end
      end

      describe "#prepare_package" do
        before do
          Dir.expects(:mktmpdir).with("mcollective_plugin_packager").returns(@tmpdir)
          FileUtils.expects(:mkdir_p)
        end

        it "should setup a 'common' package" do
          FileUtils.expects(:cp_r)
          @testpackager.prepare_package("common")
          @testpackager.dependencies.should == true
        end

        it "should setup an 'agent' package" do
          FileUtils.expects(:mkdir).with(File.join([@tmpdir, "libdir", "agent"]))
          Dir.expects(:glob).with("**/*.ddl").returns(["test.ddl"])
          Dir.expects(:glob).with("**/*").returns(["foo.rb"])
          FileUtils.expects(:cp).with(["foo.rb"], File.join([@tmpdir, "libdir", "agent"]))
          @testpackager.prepare_package("agent")
          @testpackager.agent.should == true
        end

        it "should setup a 'client' package" do
          FileUtils.expects(:cp_r).with("application", File.join(@tmpdir, "libdir"))
          FileUtils.expects(:mkdir).with(File.join(@tmpdir, "libdir", "agent"))
          Dir.expects(:glob).with("**/*.ddl").returns("test.ddl")
          FileUtils.expects(:cp).with("test.ddl", File.join([@tmpdir, "libdir", "agent"]))
          @testpackager.prepare_package("client")
          @testpackager.application.should == true
        end

        it "should fail for undefined package types" do
          expect{
            @testpackager.prepare_package("foo")
          }.to raise_error "Undefined Plugin Type"
        end
      end

      describe "#create_metadata" do
        it "should raise an exception if no ddl file is present" do
          expect{
            @testpackager.create_metadata
          }.to raise_error "Could not read agent DDL File"
        end

        it "should load a ddl if one is present" do
          Dir.expects(:glob).with("**/*.ddl").returns(["test.ddl"])
          File.expects(:read).with("test.ddl").returns("a ddl")
          MCollective::RPC::DDL.any_instance.expects(:instance_eval).with("a ddl")
          @testpackager.create_metadata
        end
      end

      describe "#package_description" do
        it "should return the correct description for each package type" do
          @testpackager.packagename = "test"
          @testpackager.package_description("common").should == "Common libraries for test."
          @testpackager.package_description("agent").should == "Agent plugin for test."
          @testpackager.package_description("client").should == "Client plugin for test."
        end
      end

      describe "#package_dirs" do
        it "should return the correct list of directories for each package type" do
          File.expects(:join).with('libdir', "agent")
          @testpackager.package_dirs("agent")
          File.expects(:join).with('libdir', "application")
          File.expects(:join).with('libdir', "agent")
          @testpackager.package_dirs("application")
          File.expects(:join).with('libdir', "util")
          @testpackager.package_dirs("util")
        end
      end

      describe "#package_contents" do
        it "should return a list of files for each package" do
          Dir.expects(:glob).with("agent/**")
          @testpackager.package_contents("agent")
          Dir.expects(:glob).with("application/**").returns([])
          Dir.expects(:glob).with("agent/*.ddl").returns([])
          @testpackager.package_contents("client")
          Dir.expects(:glob).with("util/**")
          @testpackager.package_contents("common")
        end
      end
    end
  end
end
