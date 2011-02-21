module MCollective
    # Simple module to manage vendored code.
    #
    # To vendor a library simply download its whole git repo or untar
    # into vendor/libraryname and create a load_libraryname.rb file
    # to add its libdir into the $:.
    #
    # Once you have that file, add a require line in vendor/require_vendored.rb
    # which will run after all the load_* files.
    #
    # The intention is to not change vendored libraries and to eventually
    # make adding them in optional so that distros can simply adjust their
    # packaging to exclude this directory and the various load_xxx.rb scripts
    # if they wish to install these gems as native packages.
    module Vendor
        def self.load_vendored
            vendor_dir = File.join([File.dirname(__FILE__), "vendor"])
            Dir.entries(vendor_dir).each do |entry|
                if entry.match(/load_(\w+?)\.rb$/)
                    Log.debug("Loading vendored #{$1}")
                    load "#{vendor_dir}/#{entry}"
                end
            end

            require 'mcollective/vendor/require_vendored'
        end
    end
end
