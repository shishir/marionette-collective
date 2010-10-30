module MCollective
    module Facts
        require 'java'

        # A fact source for mcollective when running
        # under jruby, sets all system properties as
        # facts
        class Jvm<Base
            include_class java.lang.System

            def get_facts
                facts = {}

                System.get_properties.to_a.each do |prop|
                    facts[prop[0]] = prop[1]
                end

                facts
            end
        end
    end
end
# vi:tabstop=4:expandtab:ai
