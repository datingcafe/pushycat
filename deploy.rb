#!/usr/bin/ruby
#
require 'rubygems'
require 'slop'
require 'yaml'

config = YAML.load_file("deploy.yml")
config.each {|key, value| instance_variable_set("@#{key}", value)}

opts = Slop.parse do
  on :s, :server, 'Server to be deployed'
  on :b, :branch, 'Branch to use'
  on :c, :copy, 'second server to copy war to', :optional => true
  on :n, :nostart, 'avoid restarting the server', :optional => true
  on :h, :help, 'Print this message', :tail => true do
    puts help
    exit
  end
end

@server = opts.server if opts.server?
@branch = opts.branch if opts.branch?
@
