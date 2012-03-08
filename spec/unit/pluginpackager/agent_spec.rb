require 'spec_helper'

module MCollective
  module PluginPackager
    describe Agent do

      describe "#identify_packages" do

        before do
          Agent.any_instance.expects(:get_metadata).once.returns({:name=>"foo"})
        end

        it "should attempt to identify all agent packages" do
          Agent.any_instance.expects(:common).once.returns(:check)
          Agent.any_instance.expects(:agent).once.returns(:check)
          Agent.any_instance.expects(:client).once.returns(:check)

          agent = Agent.new(".", nil, nil, nil, nil)
          agent.packagedata[:common].should == :check
          agent.packagedata[:agent].should == :check
          agent.packagedata[:client].should == :check
        end
      end

      describe "#agent" do
        before do
          Agent.any_instance.expects(:get_metadata).once.returns({:name=>"foo"})
          Agent.any_instance.expects(:client).once
        end

        it "should not populate the agent files if the agent directory is empty" do
          Agent.any_instance.expects(:common).returns(nil)
          Agent.any_instance.expects(:check_dir).returns(false)
          agent = Agent.new(".", nil, nil, nil, nil)
          agent.packagedata[:agent][:files].should == []
          agent.packagedata[:agent][:dependencies].should == ["mcollective"]
        end

        it "should populate the agent files if the agent directory is present and not empty" do
          Agent.any_instance.expects(:common).returns(nil)
          Agent.any_instance.expects(:check_dir).returns(true)
          File.expects(:join).returns("tmpdir")
          Dir.expects(:glob).with("tmpdir/*.ddl").returns([])
          Dir.expects(:glob).with("tmpdir/*").returns(["file.rb"])

          agent = Agent.new(".", nil, nil, nil, nil)
          agent.packagedata[:agent][:files].should == ["file.rb"]
        end

        it "should add common package as dependency if present" do
          Agent.any_instance.expects(:common).returns(true)
          Agent.any_instance.expects(:check_dir).returns(true)
          File.expects(:join).returns("tmpdir")
          Dir.expects(:glob).with("tmpdir/*.ddl").returns([])
          Dir.expects(:glob).with("tmpdir/*").returns(["file.rb"])

          agent = Agent.new(".", nil, nil, nil, nil)
          agent.packagedata[:agent][:dependencies].should == ["mcollective", "mcollective-foo-common"]
        end
      end

      describe "#common" do
        before do
          Agent.any_instance.expects(:get_metadata).once.returns({:name=>"foo"})
          Agent.any_instance.expects(:agent)
          Agent.any_instance.expects(:client)
        end

        it "should not populate the commong files if the util directory is empty" do
          Agent.any_instance.expects(:check_dir).returns(false)
          common = Agent.new(".", nil, nil, nil, nil)
          common.packagedata[:common][:files].should == []
        end

        it "should populate the agent files if the agent directory is present and not empty" do
          Agent.any_instance.expects(:check_dir).returns(true)
          File.expects(:join).returns("tmpdir")
          Dir.expects(:glob).with("tmpdir/*").returns(["file.rb"])
          common = Agent.new(".", nil, nil, nil, nil)
          common.packagedata[:common][:files].should == ["file.rb"]
        end
      end

      describe "#client" do
        before do
          Agent.any_instance.expects(:get_metadata).once.returns({:name=>"foo"})
          Agent.any_instance.expects(:agent).returns(nil)
          File.expects(:join).with(".", "application").returns("clientdir")
          File.expects(:join).with(".", "bin").returns("bindir")
          File.expects(:join).with(".", "agent").returns("agentdir")

        end

        it "should populate client files if all directories are present" do
          Agent.any_instance.expects(:common).returns(nil)
          Agent.any_instance.expects(:check_dir).times(3).returns(true)
          Dir.expects(:glob).with("clientdir/*").returns(["client.rb"])
          Dir.expects(:glob).with("bindir/*").returns(["bin.rb"])
          Dir.expects(:glob).with("agentdir/*.ddl").returns(["agent.ddl"])

          client = Agent.new(".", nil, nil, nil, nil)
          client.packagedata[:client][:files].should == ["client.rb", "bin.rb", "agent.ddl"]
        end

        it "should not populate client files if directories are not present" do
          Agent.any_instance.expects(:common).returns(nil)
          Agent.any_instance.expects(:check_dir).times(3).returns(false)

          client = Agent.new(".", nil, nil, nil, nil)
          client.packagedata[:client][:files].should == []
        end

        it "should add common package as dependency if present" do
          Agent.any_instance.expects(:common).returns("common")
          Agent.any_instance.expects(:check_dir).times(3).returns(false)

          client = Agent.new(".", nil, nil, nil, nil)
          client.packagedata[:client][:dependencies].should == ["mcollective-client", "mcollective-foo-common"]
        end
      end

      describe "#get_metadata" do
        it "should raise and exception if the ddl file is not present" do
          expect {
            Agent.new(".", nil, nil, nil, nil)
          }.to raise_error "error: could not read agent DDL File"
        end
      end

      it "should load the ddl file if its present" do
        File.stubs(:read).returns("metadata :name => \"testpackage\",
                                            :description => \"Test Package\",
                                            :author => \"Test\",
                                            :license => \"Apache 2\",
                                            :version => \"0\",
                                            :url => \"foo.com\",
                                            :timeout => 5")
        testpackage = Agent.new(".", nil, nil, nil, nil)
        testpackage.metadata.should == {:name => "testpackage",
                                        :description => "Test Package",
                                        :author => "Test",
                                        :license => "Apache 2",
                                        :version => "0",
                                        :url => "foo.com",
                                        :timeout => 5}
      end
    end
  end
end
