# encoding: utf-8

require 'net/ssh'

require 'sshkit'
require 'sshkit/dsl'
require 'sshkit/sudo'


module Backup
  class RemoteData < Archive
    class Error < Backup::Error; end

    include Utilities::Helpers
    #attr_reader :name, :options

    include SSHKit::DSL

    # server options
    attr_accessor :server_host
    attr_accessor :server_ssh_user
    attr_accessor :server_ssh_password
    attr_accessor :server_ssh_key
    attr_accessor :server_path
    attr_accessor :server_command
    attr_accessor :script
    attr_accessor :temp_dir_path





    def initialize(model, name, &block)
      @model   = model
      @name    = name.to_s
      @options = {
        :sudo        => false,
        :root        => false,
        :paths       => [],
        :excludes    => [],
        :tar_options => ''
      }

      DSL.new(@options).instance_eval(&block)

      #
      self.server_host = @options[:server_host]
      self.server_ssh_user = @options[:server_ssh_user]
      self.server_ssh_password = @options[:server_ssh_password]
      self.server_path = @options[:server_path]
      self.server_command = @options[:server_command]
      self.script = @options[:script]
      self.temp_dir_path = @options[:temp_dir_path] || '/tmp'
    end

    def perform!
      Logger.info "Creating Archive '#{ name }'..."

      # local archive
      path = File.join(Config.tmp_path, @model.trigger, 'archives')
      FileUtils.mkdir_p(path)

      extension = 'tar'
      #temp_archive_file = File.join(path, "#{ name }.#{ extension }")

      remote = Backup::Remote::Command.new


      remote_archive_file = server_path

      # generate backup on remote server
      remote_script = script

      if remote_script && remote_script!=""
        # use script
        # upload script

        local_script_path = File.join(Config.root_path, remote_script)

        f_remote = Tempfile.new('backup')
        remote_script_path = f_remote.path+"."+File.extname(local_script_path)

        Logger.info "upload script #{local_script_path} --> #{remote_script_path}"

        remote.ssh_upload_file(server_host, server_ssh_user, server_ssh_password, local_script_path, remote_script_path)

        cmd_remote = "chmod +x #{remote_script_path} && sh #{remote_script_path}"
        res_generate = remote.run_ssh_cmd(
            server_host, server_ssh_user, server_ssh_password,
            cmd_remote)

        # delete temp script
        cmd_delete = "rm -rf #{remote_script_path}"
        res_delete = remote.run_ssh_cmd(server_host, server_ssh_user, server_ssh_password, cmd_delete)

      else
        # use command
        cmd_remote = server_command
        res_generate = remote.run_ssh_cmd(
            server_host, server_ssh_user, server_ssh_password,
            cmd_remote)
      end

      if res_generate[:res]==0
        raise 'Cannot create backup on server'
      end



      #Dir.mktmpdir do |temp_dir|

      #temp_local_file = File.join("#{temp_dir}", File.basename(server_path))

      temp_local_file = File.join("#{temp_dir_path}/#{Time.now.to_i}#{rand(1000)}/", File.basename(server_path))

      #path = File.expand_path "#{Dir.tmpdir}/#{Time.now.to_i}#{rand(1000)}/"
      FileUtils.mkdir_p File.dirname(temp_local_file)

      # download backup
      Logger.info "download from #{remote_archive_file} to #{temp_local_file}"

      res_download = remote.ssh_download_file(
          server_host, server_ssh_user, server_ssh_password,
          remote_archive_file, temp_local_file)

      if res_download[:res]==0
        raise 'Cannot download file from server'
      end

      # delete archive on server
      res_delete = remote.run_ssh_cmd(
          server_host, server_ssh_user, server_ssh_password,
          "rm #{remote_archive_file}")


      # process archive locally

      pipeline = Pipeline.new

      #temp_tar_root= tar_root
      temp_tar_root= temp_dir_path
      pipeline.add(
          "#{ tar_command } #{ tar_options } -cPf - -C #{temp_tar_root } #{ File.basename(temp_local_file) }",
          tar_success_codes
      )

      extension = 'tar'
      @model.compressor.compress_with do |command, ext|
        pipeline << command
        extension << ext
      end if @model.compressor

      pipeline << "#{ utility(:cat) } > '#{ File.join(path, "#{ name }.#{ extension }") }'"

      #puts "commands: #{pipeline.commands}"
      #exit

      pipeline.run


      if pipeline.success?
        Logger.info "Archive '#{ name }' Complete!"
      else
        raise Error, "Failed to Create Archive '#{ name }'\n" +
            pipeline.error_messages
      end

      if File.exists?(temp_local_file)
        FileUtils.rm_rf(temp_local_file)
        FileUtils.rm_rf(File.dirname(temp_local_file))
      end

    end

    private

    def tar_command
      tar = utility(:tar)
      options[:sudo] ? "#{ utility(:sudo) } -n #{ tar }" : tar
    end

    def tar_root
      options[:root] ? " -C '#{ File.expand_path(options[:root]) }'" : ''
    end

    def paths_to_package
      options[:paths].map {|path| prepare_path(path) }
    end

    def with_files_from(paths)
      tmpfile = Tempfile.new('backup-archive-paths')
      paths.each {|path| tmpfile.puts path }
      tmpfile.close

      #yield "-T '#{ tmpfile.path }'"
      yield "#{ tmpfile.path }"
    ensure

      tmpfile.delete
    end

    def paths_to_exclude
      options[:excludes].map {|path|
        "--exclude='#{ prepare_path(path) }'"
      }.join(' ')
    end

    def prepare_path(path)
      options[:root] ? path : File.expand_path(path)
    end

    def tar_options
      args = options[:tar_options]
      gnu_tar? ? "--ignore-failed-read #{ args }".strip : args
    end

    def tar_success_codes
      gnu_tar? ? [0, 1] : [0]
    end


    ### DSL for RemoteArchive
    class DSL
      def initialize(options)
        @options = options
      end


      ### remote server
      def server_host=(val = true)
        @options[:server_host] = val
      end

      def server_ssh_user=(val = true)
        @options[:server_ssh_user] = val
      end
      def server_ssh_password=(val = true)
        @options[:server_ssh_password] = val
      end

      def server_command=(val = true)
        @options[:server_command] = val
      end
      def script=(val = true)
        @options[:script] = val
      end
      def server_path=(val = true)
        @options[:server_path] = val
      end

      def temp_dir_path=(val = true)
        @options[:temp_dir_path] = val
      end

      ###
      def use_sudo(val = true)
        @options[:sudo] = val
      end

      def root(path)
        @options[:root] = path
      end

      def add(path)
        @options[:paths] << path
      end

      def exclude(path)
        @options[:excludes] << path
      end

      def tar_options(opts)
        @options[:tar_options] = opts
      end
    end

  end
end
