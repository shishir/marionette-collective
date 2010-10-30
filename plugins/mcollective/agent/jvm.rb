module MCollective
    module Agent
        # Proof of concept agent to export Java memory usage to SimpleRPC via JRuby
        #
        # See:
        #   http://download.oracle.com/javase/1.5.0/docs/api/java/lang/management/MemoryMXBean.html
        #   http://www.engineyard.com/blog/2010/monitoring-the-jvm-heap-with-jruby/
        class Jvm<RPC::Agent
            require 'java'

            import java.lang.management.ManagementFactory

            metadata    :name        => "jvm",
                        :description => "Agent to manage the Java Virtual Machine",
                        :author      => "R.I.Pienaar <rip@devco.net>",
                        :license     => "Apache 2.0",
                        :version     => "1.0",
                        :url         => "http://www.devco.net/",
                        :timeout     => 20

            # memory stats about the running VM, see
            action "memory_stats" do
                mem_bean = ManagementFactory.memory_mxbean

                heap = mem_bean.getHeapMemoryUsage
                nonheap = mem_bean.getNonHeapMemoryUsage

                reply[:heap] = memory_usage_to_hash(mem_bean.getHeapMemoryUsage)
                reply[:non_heap] = memory_usage_to_hash(mem_bean.getNonHeapMemoryUsage)
                reply[:wait_to_finalize] = mem_bean.getObjectPendingFinalizationCount
            end

            # Get stats about garbage collections from the VM
            action "gc_stats" do
                gc_beans = ManagementFactory.garbage_collector_mxbeans

                gc = {}
                total_collections = 0
                total_time = 0

                gc_beans.each do |gc_bean|
                    name = gc_bean.name.to_sym

                    gc[name] = {}
                    gc[name][:pool] = gc_bean.memory_pool_names.to_a
                    gc[name][:collections] = gc_bean.collection_count
                    gc[name][:time] = gc_bean.collection_time

                    total_collections += gc_bean.collection_count
                    total_time += gc_bean.collection_time
                end

                reply[:gcstats] = gc
                reply[:gccount] = total_collections
                reply[:gctime] = total_time
            end

            # Force a garbage collection
            action "gc" do
                mem_bean = ManagementFactory.memory_mxbean
                mem_bean.verbose = true
                mem_bean.gc

                reply[:gc] = "OK"
            end

            private
            def memory_usage_to_hash(mem)
                {:comitted => mem.committed,
                 :used     => mem.used,
                 :max      => mem.max,
                 :init     => mem.init}
            end
        end
    end
end
