#!/usr/local/bin/ruby
#
#
directory = File.dirname(__FILE__)
require "#{directory}/pushycat"

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

  if pc.restart == true 
    pc.stop_tomcat
    pc.clean_webapps
    pc.install_war
    pc.start_tomcat
  end
end
