require 'net/ssh'
require 'sshkit'
require 'sshkit/dsl'
require 'sshkit/sudo'


module Backup
  module Remote

    class Command

  include SSHKit::DSL


  def run_ssh_cmd(hostname, ssh_user, ssh_pass, cmd)
    srv = ssh_user+'@'+hostname
    all_servers = [srv]

    output = ''

    on all_servers do |srv|
      as(user: ssh_user) do
        #execute(cmd)
        output = capture(cmd)
      end

    end

    #
    return {     res: 1,      output: output   }
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


      def ssh_download_file(hostname, ssh_user, ssh_pass, remote_filename, dest_filename)
        host = SSHKit::Host.new("#{ssh_user}@#{hostname}")
        host.password = ssh_pass

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

end
end
end
