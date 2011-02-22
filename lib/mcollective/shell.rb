module MCollective
    # Class to provide various wrappers to assist users
    # running shell commands in a way thats robust and
    # make it easy to access stdout, stderr and status
    class Shell
        attr_reader :environment, :command, :status, :stdout, :stderr

        def initialize(command, options={})
            @environment = {"LC_ALL" => "C"}
            @command = command
            @status = nil
            @stdout = ""
            @stderr = ""

            options.each do |opt, val|
                case opt.to_s
                    when "stdout"
                        raise "stdout should support <<" unless val.respond_to?("<<")
                        @stdout = val

                    when "stderr"
                        raise "stderr should support <<" unless val.respond_to?("<<")
                        @stderr = val

                    when "environment"
                        if val.nil?
                            @environment = {}
                        else
                            @environment.merge!(val.dup)
                        end
                end
            end

            runcommand
        end

        private
        def runcommand
            @status = systemu(@command, "env" => @environment, "stdout" => @stdout, "stderr" => @stderr)
        end
    end
end
