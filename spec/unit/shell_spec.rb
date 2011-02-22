#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

module MCollective
    describe Shell do
        describe "#initialize" do
            it "should set locale by default" do
                Shell.any_instance.stubs("runcommand").returns(true).once
                s = Shell.new("date")
                s.environment.should == {"LC_ALL" => "C"}
            end

            it "should merge environment and keep locale" do
                Shell.any_instance.stubs("runcommand").returns(true).once
                s = Shell.new("date", :environment => {"foo" => "bar"})
                s.environment.should == {"LC_ALL" => "C", "foo" => "bar"}
            end

            it "should set no environment when given nil" do
                Shell.any_instance.stubs("runcommand").returns(true).once
                s = Shell.new("date", :environment => nil)
                s.environment.should == {}
            end

            it "should save the command" do
                Shell.any_instance.stubs("runcommand").returns(true).once
                s = Shell.new("date")
                s.command.should == "date"
            end

            it "should run the command" do
                Shell.any_instance.stubs("runcommand").returns(true).once
                s = Shell.new("date")
            end

            it "should warn of illegal stdout" do
                expect {
                    s = Shell.new("date", :stdout => nil)
                }.to raise_error "stdout should support <<"
            end

            it "should warn of illegal stderr" do
                expect {
                    s = Shell.new("date", :stderr => nil)
                }.to raise_error "stderr should support <<"
            end

            it "should set stdout" do
                Shell.any_instance.stubs("runcommand").returns(true).once
                s = Shell.new("date", :stdout => "stdout")
                s.stdout.should == "stdout"
            end

            it "should set stderr" do
                Shell.any_instance.stubs("runcommand").returns(true).once
                s = Shell.new("date", :stderr => "stderr")
                s.stderr.should == "stderr"
            end
        end

        describe "#runcommand" do
            it "should run the command" do
                Shell.any_instance.stubs("systemu").returns(true).once.with("date", "stdout" => '', "stderr" => '', "env" => {"LC_ALL" => "C"})
                s = Shell.new("date")
            end

            it "should set stdin, stdout and status" do
                s = Shell.new('ruby -e "STDERR.puts \"stderr\"; STDOUT.puts \"stdout\""')
                s.stdout.should == "stdout\n"
                s.stderr.should == "stderr\n"
                s.status.exitstatus.should == 0
            end

            it "shold have correct environment" do
                s = Shell.new('echo $LC_ALL;echo $foo', :environment => {"foo" => "bar"})
                s.stdout.should == "C\nbar\n"
            end

            it "should save stdout in custom stdout variable" do
                out = "STDOUT"

                s = Shell.new('echo foo', :stdout => out)
                s.stdout.should == "STDOUTfoo\n"
                out.should == "STDOUTfoo\n"
            end

            it "should save stderr in custom stderr variable" do
                out = "STDERR"

                s = Shell.new('ruby -e "STDERR.puts \"foo\""', :stderr => out)
                s.stderr.should == "STDERRfoo\n"
                out.should == "STDERRfoo\n"
            end
        end
    end
end
