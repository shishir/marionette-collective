module MCollective
    module Facts
        require 'java'

        # A fact source for mcollective when running
        # under jruby, sets all system properties as
        # facts
        class Jvm<Base
            include_class java.lang.System
            import java.lang.management.ManagementFactory

            def get_facts
                facts = {}

                System.get_properties.to_a.each do |prop|
                    facts[prop[0]] = prop[1]
                end

                runtime_bean = ManagementFactory.getRuntimeMXBean
                facts["java.vm.uptime"] = runtime_bean.getUptime / 1000

                classloading_bean = ManagementFactory.getClassLoadingMXBean
                facts["java.vm.loaded_classes"] = classloading_bean.getLoadedClassCount
                facts["java.vm.total_loaded_classes"] = classloading_bean.getTotalLoadedClassCount
                facts["java.vm.unloaded_classes"] = classloading_bean.getUnloadedClassCount

                os_bean = ManagementFactory.getOperatingSystemMXBean
                facts["os.available_processors"] = os_bean.getAvailableProcessors

                facts
            end
        end
    end
end
# vi:tabstop=4:expandtab:ai
