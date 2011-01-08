module MCollective
    class Application::Help<Application
        description "Application list"

        def main
            puts "The Marionette Collection verion #{MCollective.version}"
            puts

            Applications.list.each do |app|
                puts "  %-10s      %s" % [app, Applications[app].application_description]
            end

            puts
        end
    end
end
