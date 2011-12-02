module MCollective
  autoload :ClassHelpers, "mcollective/versionable/classhelpers"
  autoload :BlankSlate, "mcollective/versionable/blankslate"

  module Versionable
    def self.included(base)
      base.extend ClassHelpers
    end

    def versioned_send(version, method, *args)
      self.class.versioned_send(version, method, *args)
    end

    def version(version, klass=nil, &block)
      self.class.__register_version(version, klass, &block)
    end
  end
end
