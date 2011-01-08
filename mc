#!/usr/bin/env ruby

require 'mcollective'

known_applications = MCollective::Applications.list

if known_applications.include?(ARGV.first)
    app_name = ARGV.first
    ARGV.delete_at(0)

    # make sure the various options classes shows the right help etc
    $0 = app_name

    MCollective::Applications.run(app_name)

    exit
end


puts "The Marionette Collective verion #{MCollective.version}"
puts
puts "#{$0}: sub-application (options)"
puts
puts "Known sub applications: #{known_applications.join " "}"
