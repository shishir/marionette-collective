module MCollective
    module Facts
        require 'java'

        # A factsource that reads a hash of facts from a YAML file
        #
        # Multiple files can be specified seperated with a : in the
        # config file, they will be merged with later files overriding
        # earlier ones in the list.
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
