class Pushycat
  require 'rubygems'
  require 'slop'
  require 'yaml'
  require 'net/ssh'

  attr :nostart

  def initialize
    load_config
    get_options
  end

  def load_config
    config = YAML.load_file("pushycat.yml")
    config.each {|key, value| instance_variable_set("@#{key}", value)}
  end

  def get_options
    opts = Slop.parse do
      on :s, :server, 'Server to be deployed', :optional => true
      on :b, :branch, 'Branch to use', :optional => true
      on :n, :nostart, 'avoid restarting the server'
      on :v, :version, 'use an older war version YYYYMMDDHHMM', :optional => true
      on :h, :help, 'Print this message', :tail => true do
        puts help
        exit
      end
    end
    @server = opts[:server] if opts.server?
    @branch = opts[:branch] if opts.branch?
    @version = opts.version? ? opts[:version] : Time.now.strftime("%Y%m%d%H%M")
    @new_build = opts.version? ? false : true
    @nostart = true if opts.nostart?
  end

  def what_to_do
    if @new_build == true
      puts "I will check out the latest source from #{@branch} branch"
      puts "I will build a war named #{@application}.war.#{@version}"
    else
      puts "I will use the existing war file #{@application}.war.#{@version}"
    end
    puts "I will copy the war #{@application}.war.#{@version} to the server #{@server}"
    unless @nostart == true
      puts "I will stop the tomcat as user #{@tomcat_user}"
      puts "I will delete the directory #{@webapps_dir}/#{@application} as user #{@user}"
      puts "I will delete the war file #{@webapps_dir}/#{@application}.war as user #{@user}"
      puts "I will install the war #{@application}.war.#{@version} to #{@webapps_dir}/ as #{@application}.war"
      puts "I will restart the tomcat as user #{@tomcat_user}"
    end
  end

  def get_sources
    if @new_build
      puts "*** pulling latest version from github for branch #{@branch}"
      execute = []
      execute << "cd #{@build_dir}"
      execute << "git config remote.origin.url #{@repository}"
      execute << "git config remote.origin.fetch +refs/heads/#{@branch}:refs/remotes/origin/#{@branch}"
      execute << "git pull origin"
      execute = execute.join(" && ")

      output = `#{execute}`
      puts output
    else
      puts "*** no need to fetch sources"
    end
  end

  def build_war
    if @new_build
      puts "*** building prod war #{@backup_dir}/#{@application}.war.#{@version}"
      execute = []
      execute << "cd #{@build_dir}"
      execute << "/opt/grails/bin/grails prod war #{@backup_dir}/#{@application}.war.#{@version}"
      execute = execute.join(" && ")

      output = `#{execute}`
      puts output
    else 
      puts "*** using old version #{@backup_dir}/#{@application}.war.#{@version}"
    end
  end

  def copy_war
    puts "*** copying #{@backup_dir}/#{@application}.war.#{@version} to #{@server}"
    execute = "scp #{@backup_dir}/#{@application}.war.#{@version} #{@user}@#{@server}:#{@application}.war"

    output = `#{execute}`
    puts output
  end

  def stop_tomcat
    Net::SSH.start(@server, @user) do |ssh|
      puts "*** stopping tomcat on #{@server}"
      execute = []
      output = ssh.exec!("sudo -u #{@tomcat_user} /etc/init.d/tomcat stop")

      if output =~/\[OK\]/
        puts "*** tomcat stopped"
      else
        puts output
      end

      #TODO: add another loop, if the tomcat process didn't shut down correctly
    end
  end
  def clean_webapps
    Net::SSH.start(@server, @user) do |ssh|
      puts "*** removing #{@webapps_dir}/#{@application}"
      puts "*** removing #{@webapps_dir}/#{@application}.war"
      execute = []
      execute << "sudo -u #{@tomcat_user} rm -rf #{@webapps_dir}/#{@application}"
      execute << "sudo -u #{@tomcat_user} rm -rf #{@webapps_dir}/#{@application}.war"

      execute = execute.join(" && ")

      output = ssh.exec!(execute)
      puts output
    end
  end
  def install_war
    puts "*** installing war #{@application}.war to #{@webapps_dir}"
     Net::SSH.start(@server, @user) do |ssh|
       output = ssh.exec!("cp ~/#{@application}.war #{@webapps_dir}/#{@application}.war ")
       puts output
     end
  end
  def start_tomcat
    Net::SSH.start(@server, @user) do |ssh|
      puts "*** starting tomcat on #{@server}"
      execute = []
      output = ssh.exec!("sudo -u #{@tomcat_user} /etc/init.d/tomcat start")

      if output =~/\[OK\]/
        puts "*** tomcat started"
      else
        puts output
      end
    end
  end
end
