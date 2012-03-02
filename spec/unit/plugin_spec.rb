require 'spec_helper'

module MCollective
  describe Plugins do
    before do
      tmpfile = Tempfile.new("mc_plugin_spec")
      path = tmpfile.path
      tmpfile.close!

      @tmpdir = FileUtils.mkdir_p(path)
      @tmpdir = @tmpdir[0] if @tmpdir.is_a?(Array) # ruby 1.9.2
      @plugindir = File.join([@tmpdir, "mcollective", "pluginpackager"])

      FileUtils.mkdir_p(@plugindir)

      logger = mock
      logger.stubs(:log)
      logger.stubs(:start)
      Log.configure(logger)
    end

    after do
      FileUtils.rm_r(@tmpdir)
    end

    describe '#initialize' do

      it "should fail if configuration has not been loaded" do
        Config.any_instance.expects(:configured).returns(false)

        expect {
          Plugins.new
        }.to raise_error "Configuration has not been loaded, can't load package plugins"
      end

      it "should load plugin packagers" do
        Config.any_instance.expects(:configured).returns(true)
        Plugins.any_instance.expects(:load_packagers).once

        Plugins.new
      end
    end

    describe '#clear!' do
      it "should delete all loading plugin packagers" do
        Config.any_instance.expects(:configured).returns(true).at_least_once
        Config.any_instance.expects(:libdir).returns([@tmpdir])
        PluginManager.expects(:delete).with("foo_packager").once

        a = Plugins.new("foo")
      end
    end

    describe '#load_packagers' do
      before do
        Config.any_instance.stubs(:configured).returns(true)
        Config.any_instance.stubs(:libdir).returns([@tmpdir])
        Agents.any_instance.stubs("clear!").returns(true)
      end

      it "should delete all existing plugin packagers" do
        Plugins.any_instance.expects("clear!").once
        Plugins.new
      end

      it "should attempt to load plugin packagers from all libdirs" do
        Config.any_instance.expects(:libdir).returns(["/nonexisting", "/nonexisting"])
        File.expects("directory?").with("/nonexisting/mcollective/pluginpackager").twice
        Plugins.new
      end

      it "should load found plugin packagers" do
        PluginManager.expects(:loadclass).with("MCollective::PluginPackager::Test")

        FileUtils.touch(File.join([@plugindir, "test.rb"]))
        Plugins.new
      end

      it "should not load found plugin packagers unless they have already been loaded" do
        PluginManager.expects(:loadclass).with("MCollective::PluginPackager::Test").never
        PluginManager.expects(:include?).with("test_packager").returns("true").twice
        FileUtils.touch(File.join([@plugindir, "test.rb"]))
        Plugins.new()
      end

    end
  end
end
