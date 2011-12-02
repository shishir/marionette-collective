module MCollective
  module Versionable
    module ClassHelpers
      def versioned_send(version, method, *args)
        raise "#{self.class} don't have a verion #{version} of the method #{method}" unless __has_version?(version)

        @__versioned_impl[version].send(method, *args)
      end

      def version(version, klass=nil, &block)
        __register_version(version, klass, &block)
      end

      def __has_version?(version)
        !!@__versioned_impl[version]
      end

      def __register_version(version, klass, &block)
        @__versioned_impl ||= {}

        if klass
          @__versioned_impl[version] = klass
        else
          @__versioned_impl[version] = BlankSlate.new
          @__versioned_impl[version].instance_eval(&block) if block_given?
        end
      end
    end
  end
end
