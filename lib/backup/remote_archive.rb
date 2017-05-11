# encoding: utf-8

require 'net/ssh'

require 'sshkit'
require 'sshkit/dsl'
require 'sshkit/sudo'


module Backup
  class RemoteArchive < Archive
    class Error < Backup::Error; end

    include Utilities::Helpers
    #attr_reader :name, :options

    include SSHKit::DSL

    # server options
    attr_accessor :server_host
    attr_accessor :server_ssh_options
    attr_accessor :server_backup_path



    ##
    # Adds a new Archive to a Backup Model.
    #
    #     Backup::Model.new(:my_backup, 'My Backup') do
    #       remote_archive :my_archive do |archive|
    #         archive.add 'path/to/archive'
    #         archive.add '/another/path/to/archive'
    #         archive.exclude 'path/to/exclude'
    #         archive.exclude '/another/path/to/exclude'
    #       end
    #     end
    #
    # All paths added using `add` or `exclude` will be expanded to their
    # full paths from the root of the filesystem. Files will be added to
    # the tar archive using these full paths, and their leading `/` will
    # be preserved (using tar's `-P` option).
    #
    #     /path/to/pwd/path/to/archive/...
    #     /another/path/to/archive/...
    #
    # When a `root` path is given, paths to add/exclude are taken as
    # relative to the `root` path, unless given as absolute paths.
    #
    #     Backup::Model.new(:my_backup, 'My Backup') do
    #       archive :my_archive do |archive|
    #         archive.root '~/my_data'
    #         archive.add 'path/to/archive'
    #         archive.add '/another/path/to/archive'
    #         archive.exclude 'path/to/exclude'
    #         archive.exclude '/another/path/to/exclude'
    #       end
    #     end
    #
    # This directs `tar` to change directories to the `root` path to create
    # the archive. Unless paths were given as absolute, the paths within the
    # archive will be relative to the `root` path.
    #
    #     path/to/archive/...
    #     /another/path/to/archive/...
    #
    # For absolute paths added to this archive, the leading `/` will be
    # preserved. Take note that when archives are extracted, leading `/` are
    # stripped by default, so care must be taken when extracting archives with
    # mixed relative/absolute paths.
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

      # server options
      self.server_host = @options[:server_host]
      ssh_options = {}
      v = @options[:server_ssh_user]
      ssh_options[:user] = v if v

      v = @options[:server_ssh_password]
      ssh_options[:password] = v if v

      v = @options[:server_ssh_key]
      ssh_options[:key] = v if v

      v = @options[:server_ssh_port]
      ssh_options[:port] = v if v


      self.server_ssh_options = ssh_options
    end

    def perform!
      Logger.info "Creating Archive '#{ name }'..."

      #
      path = File.join(Config.tmp_path, @model.trigger, 'archives')
      FileUtils.mkdir_p(path)


      #
      remote = Backup::Remote::Command.new

      pipeline = Pipeline.new
      with_files_from(paths_to_package) do |files_from|
        # upload to server
        res_upload = remote.ssh_upload_file(server_host, server_ssh_options, files_from, files_from)

        if res_upload[:res]==0
          raise "Cannot upload file to server - #{files_from}"
        end

        #
        pipeline.add(
          "#{ tar_command } #{ tar_options } -cPf -#{ tar_root } " +
          "#{ paths_to_exclude } -T '#{ files_from }'",
          tar_success_codes
        )

        extension = 'tar'
        @model.compressor.compress_with do |command, ext|
          pipeline << command
          extension << ext
        end if @model.compressor

        #
        archive_file = File.join(path, "#{ name }.#{ extension }")
        remote_archive_file = File.join('/tmp', "#{ name }.#{ extension }")
        pipeline << "#{ utility(:cat) } > '#{ remote_archive_file }'"


        #pipeline.run

        # generate backup on remote server
        cmd_remote = pipeline.commands.join(" | ")

        #puts "remote cmd: #{cmd_remote}"
        #exit


        res_generate = remote.run_ssh_cmd(server_host, server_ssh_options, cmd_remote)

        if res_generate[:res]==0
          raise 'Cannot create backup on server'
        end

        # download backup
        res_download = remote.ssh_download_file(server_host, server_ssh_options, remote_archive_file, archive_file)

        #puts "res: #{res_download}"

        if res_download[:res]==0
          raise 'Cannot download file from server'
        end

        # delete archive on server
        res_delete = remote.run_ssh_cmd(server_host, server_ssh_options, "rm #{remote_archive_file}")

      end

      Logger.info "Archive '#{ name }' Complete!"

      #if pipeline.success?
      #  Logger.info "Archive '#{ name }' Complete!"
      #else
      #  raise Error, "Failed to Create Archive '#{ name }'\n" + pipeline.error_messages
      #end
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

      def server_ssh_port=(val = true)
        @options[:server_ssh_port] = val
      end

      def server_ssh_user=(val = true)
        @options[:server_ssh_user] = val
      end
      def server_ssh_password=(val = true)
        @options[:server_ssh_password] = val
      end
      def server_ssh_key=(val = true)
        @options[:server_ssh_key] = val
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
