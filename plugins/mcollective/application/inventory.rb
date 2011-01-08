require 'pp'

# Monkey patching array with a in_groups_of method
# that walks an array in groups, pass a block to
# call the block on each sub array
class Array
    def in_groups_of(chunk_size, padded_with=nil)
        arr = self.clone

        # how many to add
        padding = chunk_size - (arr.size % chunk_size)

        # pad at the end
        arr.concat([padded_with] * padding)

        # how many chunks we'll make
        count = arr.size / chunk_size

        # make that many arrays
        result = []
        count.times {|s| result <<  arr[s * chunk_size, chunk_size]}

        if block_given?
            result.each{|a| yield(a)}
        else
            result
        end
    end
end

class MCollective::Application::Inventory<MCollective::Application
    description "Shows an inventory for a given node"

    option :script,
        :description    => "Script to run",
        :arguments      => ["--script SCRIPT"]

    def post_option_parser(configuration)
        configuration[:node] = ARGV.shift if ARGV.size > 0
    end

    def validate_configuration(configuration)
        unless configuration.include?(:node) || configuration.include?(:script)
            raise "Need to specify either a node name or a script to run"
        end
    end

    def node_inventory
        node = configuration[:node]

        util = rpcclient("rpcutil", :options => options)
        util.identity_filter node
        util.progress = false

        nodestats = util.custom_request("daemon_stats", {}, node, {"identity" => node})

        util.custom_request("inventory", {}, node, {"identity" => node}).each do |resp|
            puts "Inventory for #{resp[:sender]}:"
            puts

            if nodestats.is_a?(Array)
                nodestats = nodestats.first[:data]

                puts "   Server Statistics:"
                puts "                      Version: #{nodestats[:version]}"
                puts "                   Start Time: #{Time.at(nodestats[:starttime])}"
                puts "                  Config File: #{nodestats[:configfile]}"
                puts "                   Process ID: #{nodestats[:pid]}"
                puts "               Total Messages: #{nodestats[:total]}"
                puts "      Messages Passed Filters: #{nodestats[:passed]}"
                puts "            Messages Filtered: #{nodestats[:filtered]}"
                puts "                 Replies Sent: #{nodestats[:replies]}"
                puts "         Total Processor Time: #{nodestats[:times][:utime]} seconds"
                puts "                  System Time: #{nodestats[:times][:stime]} seconds"

                puts
            end

            puts "   Agents:"
            resp[:data][:agents].sort.in_groups_of(3, "") do |agents|
                puts "      %-15s %-15s %-15s" % agents
            end
            puts

            puts "   Configuration Management Classes:"
            resp[:data][:classes].sort.in_groups_of(2, "") do |klasses|
                puts "      %-30s %-30s" % klasses
            end
            puts

            puts "   Facts:"
            resp[:data][:facts].sort_by{|f| f[0]}.each do |f|
                puts "      #{f[0]} => #{f[1]}"
            end

            break
        end

        util.disconnect
    end

    def main
        node_inventory
    end
end
