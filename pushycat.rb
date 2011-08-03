class Pushycat
  require 'rubygems'
  require 'slop'
  require 'yaml'
  require 'net/ssh'

  attr :restart

  def initialize
    load_config
    get_options
  end

  def load_config
    directory = File.dirname(__FILE__)
    config = YAML.load_file("#{directory}/pushycat.yml")
    config.each {|key, value| instance_variable_set("@#{key}", value)}
  end

  def get_options
    opts = Slop.parse do
      on :s, :server, 'server to be deployed', :optional => true
      on :b, :branch, 'branch to use', :optional => true
      on :r, :restart, 'restart the server. Doesn\'t work to avoid restart'
      on :v, :version, 'use an older war version YYYYMMDDHHMM', :optional => true
      on :u, :user, 'user for ssh login', :optional => true   
      on :t, :tomcat, 'user for tomcat', :optional => true   
      on :h, :help, 'print this message', :tail => true do
        puts help
        exit
      end
    end
    @server = opts[:server] if opts.server?
    @branch = opts[:branch] if opts.branch?
    @user = opts[:user] if opts.user?
    @tomcat_user = opts[:tomcat] if opts.tomcat?
    @version = opts.version? ? opts[:version] : Time.now.strftime("%Y%m%d%H%M")
    @new_build = opts.version? ? false : true
    @restart = true if opts.restart?
  end

  def what_to_do
    if @new_build == true
      puts "I will check out the latest source from #{@branch} branch into #{@build_dir}"
      puts "I will build a war named #{@application}.war.#{@version} and store it in #{@backup_dir}"
    else
      puts "I will use the existing war file #{@application}.war.#{@version}"
    end
    puts "I will copy the war #{@application}.war.#{@version} to the server #{@server} as user #{@user}"
    if @restart == true
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
      execute << "rm -Rf #{@build_dir}"
      execute << "git clone #{@repository} #{@build_dir}"
      execute << "cd #{@build_dir}"
      execute << "git remote update"
      execute << "git checkout -t -b #{@branch} origin/#{@branch}"
      execute = execute.join(" && ")

      output = `#{execute}`
      puts output
    else
      puts "*** no need to fetch sources"
    end
  end

  def build_war
    if @new_build
      puts "*** building prod war --non-interactive #{@backup_dir}/#{@application}.war.#{@version}"
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
      execute = []
      retries = 0
      puts "*** stopping tomcat on #{@server}"
      puts tomcat_shutdown(ssh)

      if !tomcat_running?(ssh)
        puts "*** tomcat stopped"
      else
        puts "*** waiting 30 seconds for tomcat to shutdown completely"
        sleep 30

        while tomcat_running?(ssh) && retries < 5 do
          puts "*** tomcat still running"
          sleep 30
          retries += 1
        end

        if tomcat_running?(ssh)
          puts "trying again to stop it"
          puts tomcat_shutdown(ssh)
          sleep 30
        end

        if tomcat_running?(ssh)
          puts "*** please kill tomcat manually"
        else
          puts "*** tomcat stopped"
        end
      end
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

      output = ssh.exec!("ps -Cjava -opid,args | grep tomcat | cut -c1-5")

      if output && output.to_i > 1
        puts "*** tomcat still running with pid #{output}"
        puts "*** trying to restart tomcat on #{@server}"
        output = ssh.exec!("sudo -u #{@tomcat_user} /etc/init.d/tomcat restart")
        
        puts output
      else
        puts "*** starting tomcat on #{@server}"
        output = ssh.exec!("sudo -u #{@tomcat_user} /etc/init.d/tomcat start")

        if output =~/\[OK\]/
          puts "*** tomcat started"
        else
          puts output
        end
      end
    end
  end

  private
  def tomcat_shutdown(ssh)
      output = ssh.exec!("sudo -u #{@tomcat_user} /etc/init.d/tomcat stop")
  end
  def tomcat_running?(ssh)
      output = ssh.exec!("ps -Cjava -opid,args | grep tomcat | grep -v solr | cut -c1-5")
      output.to_i > 0
  end
end
