Model.new(:backup, 'Backup files') do

  remote_archive :files do |archive|
    archive.server_host = ENV['HOST']
    archive.server_ssh_user = ENV['USER']
    archive.server_ssh_password = ENV['PASSWORD']
    archive.server_ssh_key = ENV['KEY']
    archive.add(ENV['FILE_PATH'])
  end

end

