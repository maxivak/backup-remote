Backup Remote
===========
Backup-remote gem extends [Backup gem](https://github.com/backup/backup) to perform backups on remote servers.

If you use backup gem you should run `backup perform` on the machine where resources (files, databases) are located.

This gem adds support for models to perform backups on a remote server.



Backup is a system utility for Linux and Mac OS X, distributed as a RubyGem, that allows you to easily perform backup
operations. It provides an elegant DSL in Ruby for _modeling_ your backups. 
Backup has built-in support for various databases, storage protocols/services, syncers, compressors, encryptors and notifiers which you can mix and match. 



# How it works

Backup process:

* specify server connection options in your model

```
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
```
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



# Archives

## Archive files on a remote server

* Use RemoteArchive

```
```


# Databases

## Backup database on a remote server

* Now it is implemented the following databases:
* RemoteMySQL

### RemoteMySQL

```
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

# Custom backup command

* Run custom command to create a backup archive on a remote server


# Backup gem
[Installation]:  http://backup.github.io/backup/v4/installation
[Release Notes]: http://backup.github.io/backup/v4/release-notes
[Documentation]: http://backup.github.io/backup/v4
