# bind9_dns_named.sh

## What it does

### General

This script uses gets an ip address from a public source and then does an find and replace of the previous ip address of domains listed in the configuration **[DOMAINS]** section.

### Executing

When the configuration file is properly set up running the script is straight forward:

```sh
bash ~/myscripts/bind9_dns_named.sh
```

Whereas *myscripts* the path you have installed this script.

This script does testing of hosts configuration files along the way. Before a hosts file is updated it is checked to see if it currently valid using `named-checkzone` command.  
If the zone is not currently valid the it will be skipped.  
If the zone is not valid after update the failure is outputed to *stdout*.

After all the listed domain(s) are updated a test is done using `named-checkconf` of the main hosts file provided in the **ZONE_MAIN** setting. If the test is successful then bind9 will automatically be reloaded to have the new ip take effect.  
**Note:** bind9 will not automatically be reloaded when restore is performed.

### Backup

This script will backup the files that are set to have their ip address changed in. The default location is `/tmp/bind9_dns_named/` directory.
**Important** the default backup directory will likely be deleted on each reboot. This is due to its location in the tmp folder. The backup directoy can be changed by changing the **BACKUP_DIR_NAMED** location of the configuration file under the **[GENERAL]** section.

### Restore

If for any reason after this script is run and you want to restore the previous file(s) you can run the command: `bash bind9_dns_named.sh -r`

This will copy the files from the **BACKUP_DIR** if they exist and over write the existing files.

When restoring files from back Bind9 will **not** automatically be restarted and the restored files will not automatically be checked.

To Manually test overall configuration of bind9 you may run the followg command:

```sh
named-checkconf /etc/bind/named.conf && [[ $? -eq 0 ]] && echo 'All Good' || echo 'Failed'
```

To test bind Status the following command:

```sh
systemctl status bind9
```

To reload bind9 (necessary after restore to load the restored files):

```sh
systemctl reload bind9
```

## Configuration

### Configuration file

Script will use a configuration file to read setting from. This is the recommended way to configure for this script.

A configuration file could to be created manually at: `~/.bind9/config.cfg`  
This configuration file would be read by this script.

Sample `~/.bind9/config.cfg` file:

```ini
[GENERAL]
IP_URL=https://checkip.amazonaws.com/
MAX_IP_AGE=5
BACKUP_DIR_NAMED=/tmp/bind9_dns_named
TMP_IP_FILE=/tmp/current_ip_address

[BIND_CONF]
ZONE_LOCAL=/etc/bind/named.conf.local
ZONE_MAIN=/etc/bind/named.conf

[DOMAINS]
www.domain.tld
sales.othdomain.tld
mydomain.tld
```

#### [GENERAL]

| Setting          | Default                        | Descripton                                                 |
|------------------|--------------------------------|------------------------------------------------------------|
| IP_URL           | https://checkip.amazonaws.com/ | The URL used to get public Ip address from                 |
| MAX_IP_AGE       | 5                              | The amount of time in minutes to cache public url          |
| BACKUP_DIR_NAMED | /tmp/bind9_dns_named           | The directory used to backup the previous bind hosts files |
| TMP_IP_FILE      | /tmp/current_ip_address        | The file to cache the current public addres in             |

#### [BIND_CONF]

| Setting          | Default                    | Descripton                                                                                                                                   |
|------------------|----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| ZONE_MAIN        | /etc/bind/named.conf       | The file path to bind named.conf                                                                                                             |
| ZONE_LOCAL       | /etc/bind/named.conf.local | The file path to named.conf.local. This is the conf file that contains information about domains and their paths to corresponding zone files |

### Command Line

```txt
-d  Comma seperated domain name(s) such as www.domain.tld,lib.domain.tld,sales.domain.tld
-l  The full path to named.conf.local file. Default: /etc/bind/named.conf.local
-m  The full path to named.conf file. Default: /etc/bind/named.conf
-i  The ip address to be used. Default the the ip address provided by: https://checkip.amazonaws.com/
-u  The url that will be used to query IP address. Default is https://checkip.amazonaws.com/
-t  The amount of time the IP address is cached in minutes. Default is 5
-r  Restore files from backup if existing
-v  Display version info
-h  Display help.
```

* `-d` overrides values of the [DOMAINS] section
* `-l` overrides `ZONE_LOCAL` of the [BIND_CONF] section
* `-m` overrides `ZONE_MAIN` of the [BIND_CONF] section
* `-u` overrides `IP_URL` of the [GENERAL] section
* `-t` overrides `MAX_IP_AGE` of the [GENERAL] section