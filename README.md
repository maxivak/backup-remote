Backup Remote
===========
Backup-remote gem extends [Backup gem](https://github.com/backup/backup) to perform backups on remote servers.

If you use backup gem you should run `backup perform` on the machine where resources (files, databases) are located.

This gem adds support for models to perform backups on a remote server.

This gem realizes pull strategy when the backup files are pulled from the remote server to the backup server and then backup files are distributed to backup storages. 
Backup gem realizes as push strategy when the backup files are created and pushed from remote server to backup storages from the server itself.

It means that for using backup-remote gem you don't need to setup additional software on the remote server (like ruby, gems, etc) to perform backups.
Only ssh access is needed for the remote server.


Backup is a system utility for Linux and Mac OS X, distributed as a RubyGem, that allows you to easily perform backup
operations. It provides an elegant DSL in Ruby for _modeling_ your backups. 
Backup has built-in support for various databases, storage protocols/services, syncers, compressors, encryptors and notifiers which you can mix and match. 

The gem adds the following model components:
* Remote Archive
* Remote MySQL database
* Remote data




# How it works

Backup process:

* specify server connection options in your model

```ruby
Model.new(:my_backup, 'My Backup') do
  database RemoteMySQL do |db|
    # options for server
    db.server_host = "server1.com"
    db.server_ssh_user = "username"
    db.server_ssh_password = "mypwd"
    db.server_ssh_key = "/path/to/ssh/key"
    
    # other options for resource
    ...
    
  end
  ...    
end
````

* perform backup - run script `backup peform` from the backup server
```bash
backup-remote perform -t my_backup
```

* it will connect to the remote server by SSH and run command remotely which creates a backup file
* then it downloads the archive file from the remote server to the backup server
* finally, it performs all operations with backup file, like storing file to storages, etc. as gem backup does.




It uses SSHKit to connect to server by SSH.



# Options

Options for SSH connection:
* server_host - host name or IP
* server_ssh_user - user name to connect by SSH
* server_ssh_password - not used if server_ssh-key is provided
* server_ssh_key - (optional) - path to ssh key
* temp_dir_path - (optional) - specify temporary directory path where backup files will be downloaded. By default, it is '/tmp'



# Archives

## Archive files on a remote server

* Use remote_archive in your model


```ruby

Model.new(:my_server_files_backup, 'Backup files') do

  remote_archive :files do |archive|
    archive.server_host = "myserver.com"
    archive.server_ssh_user = "user"
    archive.server_ssh_password = "pwd"


    # archive options - the same options as for archive
    # see  http://backup.github.io/backup/v4/archives/


  end
  
  ...
  
end  
    
```


# Databases

## Backup database on a remote server

* Now it is implemented the following databases:
* RemoteMySQL


### Remote MySQL Database

```ruby
Model.new(:my_backup, 'My Backup') do
  database RemoteMySQL do |db|
    # options for server
    db.server_host = "server1.com"
    db.server_ssh_user = "username"
    db.server_ssh_password = "mypwd"
    db.server_ssh_key = "/path/to/ssh/key"
    
    ### options for MySQL 
    # see http://backup.github.io/backup/v4/database-mysql/
    
    ...
  end
  ..
end

````



# Custom data on remote server

* Run custom command on the remote server to create a backup archive

* Specify command (or script) to run to generate archive file on the remote server

* This command should create an archive file with filename specified in server_path option.


```ruby
Model.new(:my_server_data_backup, 'Backup data') do

  remote_data :mydata do |archive|
    archive.server_host = "myserver.com"
    archive.server_ssh_user = "user"
    archive.server_ssh_password = "pwd"
    
    
    archive.command = "--any command to generate backup archive file--"
    archive.script = "--path to script to copy to server and run--" 
    archive.server_path = "/path/to/backup.tar.gz"

    # example:
    # archive.command = "/tmp/backup.txt"
    # archive.command = "echo '1' > /tmp/backup.txt"
    
    
  end
  
  ...
  
end  
    
```

Options:

* command - command to run to generate backup on server. Not used if script is specified.
* script - path to script file to upload and run on server to generate backup. Script is stored locally nad is uploaded to server.
script path is relative to root-path.




### Examples
