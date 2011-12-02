module MCollective
  module Versionable
    class BlankSlate
      instance_methods.each do |method|
        undef_method method unless method =~ /^(__|instance_eval|send)/
      end
    end
  end
end
