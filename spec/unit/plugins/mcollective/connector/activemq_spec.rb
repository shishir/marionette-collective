#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../../spec_helper'
require File.dirname(__FILE__) + '/../../../../../plugins/mcollective/connector/activemq.rb'

module MCollective
    module Connector
        describe Activemq do
            before do
                config = mock
                config.stubs(:configured).returns(true)
                config.stubs(:identity).returns("rspec")
                config.stubs(:collectives).returns(["mcollective"])
                config.stubs(:pluginconfg).returns({"activemq.pool.size" => 2,
                                                    "activemq.pool.1.host" => "host1",
                                                    "activemq.pool.1.port" => "port1",
                                                    "activemq.pool.1.user" => "user1",
                                                    "activemq.pool.1.password" => "password1",
                                                    "activemq.pool.1.ssl" => "ssl1",
                                                    "activemq.pool.2.host" => "host2",
                                                    "activemq.pool.2.port" => "port2",
                                                    "activemq.pool.2.user" => "user2",
                                                    "activemq.pool.2.password" => "password2",
                                                    "activemq.pool.2.ssl" => "ssl2"})

                logger = mock
                logger.stubs(:log)
                logger.stubs(:start)
                Log.configure(logger)

                Config.stubs(:instance).returns(config)

                @subscription = mock
                @subscription.stubs("<<").returns(true)
                @subscription.stubs("include?").returns(false)
                @subscription.stubs("delete").returns(false)

                @connection = mock
                @connection.stubs(:subscribe).returns(true)
                @connection.stubs(:unsubscribe).returns(true)

                @c = Activemq.new
                @c.instance_variable_set("@subscriptions", @subscription)
                @c.instance_variable_set("@connection", @connection)
            end

            describe "#make_target" do
                it "should create correct targets" do
                    @c.make_target("test", :broadcast, "mcollective").should == {:target => "/topic/mcollective.test.command",
                                                                                 :headers => {}}

                    @c.make_target("test", :directed, "mcollective").should == {:target => "/queue/mcollective.test.command",
                                                                                :headers => {"selector" => "mcollective_identity = 'rspec'"}}

                    @c.make_target("test", :reply, "mcollective").should == {:target => "/topic/mcollective.test.reply",
                                                                                :headers => {}}
                end

                it "should raise an error for unknown collectives" do
                    expect {
                        @c.make_target("test", :broadcast, "foo")
                    }.to raise_error("Unknown collective 'foo' known collectives are 'mcollective'")
                end

                it "should raise an error for unknown types" do
                    expect {
                        @c.make_target("test", :test, "mcollective")
                    }.to raise_error("Invalid or unsupported target type test")
                end
            end

            describe "#unsubscribe" do
                it "should use make_target correctly" do
                    @c.expects("make_target").with("test", :broadcast, "mcollective").returns({:target => "test", :headers => {}})
                    @c.unsubscribe("test", :broadcast, "mcollective")
                end

                it "should not unsubscribe from empty targets" do
                    @c.expects("make_target").with("foo", :broadcast, "mcollective").returns({:target => nil, :headers => {}})

                    connection = mock
                    connection.expects(:unsubscribe).never
                    @c.instance_variable_set("@connection", connection)

                    @c.subscribe("foo", :broadcast, "mcollective")
                end

                it "should unsubscribe from the target" do
                    @c.expects("make_target").with("test", :broadcast, "mcollective").returns({:target => "test", :headers => {}})
                    @connection.expects(:unsubscribe).with("test").once

                    @c.unsubscribe("test", :broadcast, "mcollective")
                end

                it "should delete the source from subscriptions" do
                    @c.expects("make_target").with("test", :broadcast, "mcollective").returns({:target => "test", :headers => {}})
                    @subscription.expects(:delete).with({:target => "test", :headers => {}}).once

                    @c.unsubscribe("test", :broadcast, "mcollective")
                end
            end

            describe "#subscribe" do
                it "should use the make_target correctly" do
                    @c.expects("make_target").with("test", :broadcast, "mcollective").returns({:target => "test", :headers => {}})
                    @c.subscribe("test", :broadcast, "mcollective")
                end

                it "should not subscribe to empty targets" do
                    @c.expects("make_target").with("foo", :broadcast, "mcollective").returns({:target => nil, :headers => {}})

                    connection = mock
                    connection.expects(:subscribe).never
                    @c.instance_variable_set("@connection", connection)

                    @subscription.expects("include?").never

                    @c.subscribe("foo", :broadcast, "mcollective")
                end

                it "should check for existing subscriptions" do
                    source = {:target => "test", :headers => {}}

                    @c.expects("make_target").returns(source).once
                    @subscription.expects("include?").with(source).returns(false)
                    @connection.expects(:subscribe).never

                    @c.subscribe("test", :broadcast, "mcollective")
                end

                it "subscribe to the middleware" do
                    @c.expects("make_target").returns({:target => "test", :headers => {}})
                    @connection.expects("subscribe").with("test", {}).once
                    @c.subscribe("test", :broadcast, "mcollective")
                end

                it "add to the list of subscriptions" do
                    source = {:target => "test", :headers => {}}
                    @c.expects("make_target").returns(source)
                    @subscription.expects("<<").with(source)
                    @c.subscribe("test", :broadcast, "mcollective")
                end
            end
        end
    end
end
