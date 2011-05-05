#!/usr/local/bin/ruby
#
#
require 'pushycat'

pc = Pushycat.new

pc.what_to_do

puts "Do you want to deploy? (y/n)"
answer = STDIN.gets.chomp

if answer.downcase == "n"
  exit
elsif answer.downcase == "y"
  pc.get_sources
  pc.build_war
  pc.copy_war

  unless pc.nostart == true 
    pc.stop_tomcat
    pc.clean_webapps
    pc.install_war
    pc.start_tomcat
  end
end
