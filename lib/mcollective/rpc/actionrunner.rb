module MCollective
    module RPC
        class ActionRunner
            attr_reader :command, :agent, :action, :format, :stdout, :stderr, :request

            def initialize(command, request, format=:json)
                @command = command
                @agent = request.agent
                @action = request.action
                @format = format
                @request = request
                @stdout = ""
                @stderr = ""
            end

            def run
                unless canrun?(command)
                    Log.warn("Cannot run #{to_s}")
                    reply.fail! "Cannot execute #{to_s}"
                end

                Log.debug("Running #{to_s}")

                request_file = saverequest(request)
                reply_file = tempfile("reply")
                reply_file.close

                runner = shell(command, request_file.path, reply_file.path)

                runner.runcommand

                Log.debug("#{command} exited with #{runner.status.exitstatus}")

                stderr.each_line {|l| Log.error("#{to_s}: #{l}")} unless stderr.empty?
                stdout.each_line {|l| Log.info("#{to_s}: #{l}")} unless stdout.empty?

                {:exitstatus => runner.status.exitstatus,
                 :stdout     => runner.stdout,
                 :stderr     => runner.stderr,
                 :data       => load_results(reply_file.path)}
            ensure
                request_file.close! if request_file.respond_to?("close!")
                reply_file.close! if reply_file.respond_to?("close")
            end

            def shell(command, infile, outfile)
                env = {"MCOLLECTIVE_REQUEST_FILE" => infile,
                       "MCOLLECTIVE_REPLY_FILE"   => outfile}

                Shell.new("#{command} #{infile} #{outfile}", :cwd => "/tmp", :stdout => stdout, :stderr => stderr, :environment => env)
            end

            def load_results(file)
                data = JSON.load(File.read(file))
                reply = {}

                data.each_pair do |k,v|
                    reply[k.to_sym] = v
                end

                reply
            end

            def saverequest(req)
                request_file = tempfile("request")
                request_file.puts req.to_json
                request_file.close

                request_file
            end

            def canrun?(command)
                File.executable?(command)
            end

            def to_s
                "#{agent}##{action} command: #{command}"
            end

            def tempfile(prefix)
                Tempfile.new("mcollective_#{prefix}", "/tmp")
            end
        end
    end
end
