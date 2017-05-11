require 'net/ssh'
require 'sshkit'
require 'sshkit/dsl'
require 'sshkit/sudo'


module Backup
  module Remote
    class Command

      include SSHKit::DSL


      def self.build_sshkit_host(hostname, ssh_options)
        puts "DEBUG: #{ssh_options}"
        ssh_user = ssh_options[:user]
        ssh_pass = ssh_options[:password]
        ssh_key = ssh_options[:key]

        host = SSHKit::Host.new({hostname: hostname, user: ssh_user})
        host.port = ssh_options[:port] || 22
        host.key = ssh_key if ssh_key
        host.password = ssh_pass if ssh_pass

        host
      end

      def run_ssh_cmd(hostname, ssh_options, cmd)
        #puts "run ssh cmd: #{hostname}, #{ssh_user}, #{ssh_pass}, #{cmd}"
        host = Command.build_sshkit_host(hostname, ssh_options)

        #srv = ssh_user+'@'+hostname
        all_servers = [host]

        output = ''

        SSHKit::Coordinator.new(host).each in: :sequence do
          output = capture cmd
        end


=begin
        on all_servers do |srv|
          as(user: ssh_user) do
            #execute(cmd)
            output = capture(cmd)
          end
        end
=end

        puts "output: #{output}"

        #
        return {     res: 1,      output: output   }

      rescue => e
        puts "ssh error: #{e.message}, #{e.backtrace}"

        {
            res: 0,
            output: output,
            error: e.message
        }
      end

      def run_ssh_cmd_sudo(hostname, ssh_user, ssh_pass, cmd, handler=nil)
        host = SSHKit::Host.new("#{ssh_user}@#{hostname}")
        host.password = ssh_pass

        on host do |host|
          execute("#{cmd}", interaction_handler: handler)
        end

        #
        return {res: 1, output: ""}

      rescue => e
        {
            res: 0,
            error: e.message
        }
      end

      def self.interaction_handler_pwd(user, pwd, host='')
        {
            "#{user}@#{host}'s password:" => "#{pwd}\n",
            /#{user}@#{host}'s password: */ => "#{pwd}\n",
            "password: " => "#{pwd}\n",
            "password:" => "#{pwd}\n",
            "Password: " => "#{pwd}\n",
        }
      end



  def ssh_download_file(hostname, ssh_options, remote_filename, dest_filename)
    return ssh_download_file_sshkit(hostname, ssh_options, remote_filename, dest_filename)
    #return ssh_download_file_scp(hostname, ssh_user, ssh_pass, remote_filename, dest_filename)
  end

  def ssh_download_file_scp(hostname, ssh_options, remote_filename, dest_filename)
    ssh_user = ssh_options[:ssh_user]
    ssh_pass = ssh_options[:ssh_password]
    ssh_key = ssh_options[:ssh_key]

    # work
    Net::SCP.download!(hostname, ssh_user, remote_filename, dest_filename, :ssh => { :password => ssh_pass })

    #
    return {res: 1, output: ""}

  rescue => e
    {
        res: 0,
        error: e.message
    }
  end

  # !! NOT work on big files > 4Gb
  def ssh_download_file_sshkit(hostname, ssh_options, remote_filename, dest_filename)
    host = Command.build_sshkit_host(hostname, ssh_options)

    on host do |host|
      download! remote_filename, dest_filename
    end

    #
    return {res: 1, output: ""}

  rescue => e
    {
        res: 0,
        error: e.message
    }
  end

  def ssh_upload_file(hostname, ssh_options, source_file, dest_file, handler=nil)
    host = Command.build_sshkit_host(hostname, ssh_options)

    # scp
    f_temp = "/tmp/#{SecureRandom.uuid}"

    # sshkit
    SSHKit::Coordinator.new(host).each in: :sequence do
      # upload to temp file
      upload! source_file, f_temp

      # upload to dest
      execute("cp #{f_temp} #{dest_file}", interaction_handler: handler)

    end

=begin
    on host do |host|
      # NOT WORK with sudo
      #upload! source_file, dest_file


      as(user: ssh_user) do
        # upload to temp file
        upload! source_file, f_temp

        # upload to dest
        execute("cp #{f_temp} #{dest_file}", interaction_handler: handler)

      end
    end
=end

    #
    return     {res: 1, output: ""}
  rescue => e
    {
        res: 0,
        error: e.message
    }
  end

end
end
end
