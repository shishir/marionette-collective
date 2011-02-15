class MCollective::Application::Collectivemap<MCollective::Application
    description "Creates a dot graph of a running collective"
    usage "rpc collectivemap <graph file>"

    def post_option_parser(configuration)
        configuration[:graph_file] = ARGV.shift if ARGV.size > 0
    end

    def validate_configuration(configuration)
        unless configuration.include?(:graph_file)
            raise "Need to specify a file to output the graph to"
        end
    end

    def getcollectives(client)
        collectives = {}

        client.collective_info.each do |resp|
            data = resp[:data]

            if data.include?(:collectives)
                data[:collectives].each do |c|
                    collectives[c] = [] unless collectives.include?(c)

                    collectives[c] << resp[:sender]
                end
            end
        end

        collectives
    end

    def main
        File.open(configuration[:graph_file], "w") do |graph|
            shelper = rpcclient("rpcutil", :options => options)

            collectives = getcollectives(shelper)

            graph.puts "graph {"

            collectives.keys.sort.each do |collective|
                graph.puts "\tsubgraph #{collective} {"

                collectives[collective].each do |member|
                    member_name = member.gsub('.', '_').gsub('-', '_')

                    graph.puts "\t\t\"#{member}\" -- #{collective};"
                end

                graph.puts "\t}"
            end

            graph.puts "}"

            puts "Graph of #{shelper.discover.size} nodes has been written to #{configuration[:graph_file]}"
        end
    end
end
