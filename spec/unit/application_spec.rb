#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

module MCollective
    describe Application do
        before do
            Application.intialize_application_options
            @argv_backup = ARGV.clone
        end

        describe "#application_options" do
            it "should return the application options" do
                Application.application_options.should == {:description  => nil,
                                                           :usage        => nil,
                                                           :cli_arguments => []}
            end
        end

        describe "#[]=" do
            it "should set the application option" do
                Application["foo"] = "bar"
                Application.application_options["foo"].should == "bar"
            end
        end

        describe "#[]" do
            it "should set the application option" do
                Application[:cli_arguments].should == []
            end
        end

        describe "#intialize_application_options" do
            it "should initialize application options correctly" do
                Application.intialize_application_options.should == {:description  => nil,
                                                                     :usage        => nil,
                                                                     :cli_arguments => []}
            end
        end

        describe "#description" do
            it "should set the description correctly" do
                Application.description "meh"
                Application[:description].should == "meh"
            end
        end

        describe "#usage" do
            it "should set the usage correctly" do
                Application.usage "meh"
                Application[:usage].should == "meh"
            end
        end

        describe "#option" do
            it "should add an option correctly" do
                Application.option :test,
                                   :description => "description",
                                   :arguments => "--config CONFIG",
                                   :type => Integer,
                                   :required => true

                Application[:cli_arguments].should == [{:name=>:test,
                                                        :arguments=>"--config CONFIG",
                                                        :required=>true,
                                                        :type=>Integer,
                                                        :description=>"description"}]
            end

            it "should set correct defaults" do
                Application.option :test, {}

                Application[:cli_arguments].should == [{:name=>:test,
                                                        :arguments=>[],
                                                        :required=>false,
                                                        :type=>String,
                                                        :description=>nil}]
            end
        end

        describe "#application_parse_options" do
            it "should set the application description as head" do
                OptionParser.any_instance.stubs(:define_head).with("meh")

                ARGV.clear

                Application.description "meh"
                Application.new.application_parse_options

                ARGV.clear
                @argv_backup.each{|a| ARGV << a}
            end

            it "should set the application usage as a banner" do
                OptionParser.any_instance.stubs(:banner).with("meh")

                ARGV.clear

                Application.usage "meh"
                Application.new.application_parse_options

                ARGV.clear
                @argv_backup.each{|a| ARGV << a}
            end

            it "should enforce required options" do
                Application.any_instance.stubs("exit!").returns(true)
                Application.any_instance.stubs("main").returns(true)
                OptionParser.any_instance.stubs("parse!").returns(true)
                IO.any_instance.expects(:puts).with(anything).at_least_once
                IO.any_instance.expects(:puts).with("The foo option is mandatory").at_least_once

                ARGV.clear
                ARGV << "--foo=bar"

                Application.option :foo,
                                   :description => "meh",
                                   :required => true,
                                   :arguments => "--foo [FOO]"

                Application.new.run

                ARGV.clear
                @argv_backup.each{|a| ARGV << a}
            end

            it "should call post_option_parser" do
                OptionParser.any_instance.stubs("parse!").returns(true)
                Application.any_instance.stubs("post_option_parser").returns(true).at_least_once
                Application.any_instance.stubs("main").returns(true)

                ARGV.clear
                ARGV << "--foo=bar"

                Application.option :foo,
                                   :description => "meh",
                                   :arguments => "--foo [FOO]"

                Application.new.run

                ARGV.clear
                @argv_backup.each{|a| ARGV << a}
            end

            it "should create an application option" do
                OptionParser.any_instance.stubs("parse!").returns(true)
                OptionParser.any_instance.expects(:on).with(anything, anything, anything, anything).at_least_once
                OptionParser.any_instance.expects(:on).with('--foo [FOO]', String, 'meh').at_least_once
                Application.any_instance.stubs("main").returns(true)

                ARGV.clear
                ARGV << "--foo=bar"

                Application.option :foo,
                                   :description => "meh",
                                   :arguments => "--foo [FOO]"

                Application.new.run

                ARGV.clear
                @argv_backup.each{|a| ARGV << a}
            end
        end

        describe "#initialize" do
            it "should parse the command line options at application run" do
                Application.any_instance.expects("application_parse_options").once
                Application.any_instance.stubs("main").returns(true)

                Application.new.run
            end
        end

        describe "#application_description" do
            it "should provide the right description" do
                Application.description "Foo"
                Application.new.application_description.should == "Foo"
            end
        end

        describe "#application_usage" do
            it "should provide the right usage" do
                Application.usage "Foo"
                Application.new.application_usage.should == "Foo"
            end
        end

        describe "#application_cli_arguments" do
            it "should provide the right usage" do
                Application.option :foo,
                                   :description => "meh",
                                   :arguments => "--foo [FOO]"

                Application.new.application_cli_arguments.should == [{:description=>"meh",
                                                                      :name=>:foo,
                                                                      :arguments=>"--foo [FOO]",
                                                                      :type=>String,
                                                                      :required=>false}]
            end
        end

        describe "#main" do
            it "should detect applications without a #main" do
                IO.any_instance.expects(:puts).with("Applications need to supply a 'main' method")
                IO.any_instance.expects(:puts).with(regexp_matches(/SystemExit/))
                Application.any_instance.stubs("exit!").returns(true)

                Application.new.run
            end
        end

        describe "#configuration" do
            it "should return the correct configuration" do
                Application.any_instance.stubs("main").returns(true)

                ARGV.clear
                ARGV << "--foo=bar"

                Application.option :foo,
                                   :description => "meh",
                                   :arguments => "--foo [FOO]"

                a = Application.new
                a.run

                a.configuration.should == {:foo => "bar"}

                ARGV.clear
                @argv_backup.each{|a| ARGV << a}
            end
        end
    end
end
