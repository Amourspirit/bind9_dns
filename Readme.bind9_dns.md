# bind9_dns.sh

## What it does

### General

This script uses gets an ip address from a public source and then does an find and replace of the previous ip address of file(s) listed in the configuration **[BIND_FILES]** section.

### Executing

When the configuration file is properly set up running the script is straight forward:

```sh
bash ~/myscripts/bind9_dns.sh
```

Whereas *myscripts* the path you have installed this script.

When this script sucessfully changes the ip address in the hosts files it will test the configuration of the main hosts file provided in the **ZONE_MAIN** setting. If the test is successful then bind9 will automatically be reloaded to have the new ip take effect.  
**Note:** bind9 will not automatically be reloaded when restore is performed.

### Backup

This script will backup the files that are set to have their ip address changed in. The default location is `/tmp/bind9_dns/` directory.
**Important** the default backup directory will likely be deleted on each reboot. This is due to its location in the tmp folder. The backup directoy can be changed by changing the **BACKUP_DIR** location of the configuration file under the **[GENERAL]** section.

### Restore

If for any reason after this script is run and you want to restore the previous file you can run the command: `bash bind9_dns.sh -r`

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

The *required* configuration file would need to be created manually at: `~/.bind9/config.cfg`

The **[BIND_FILES]** section is the only required part of the configuration for this script.

The **[BIND_CONF]** section is required unless overriden by the `-m` command line switch.

The **[DOMAIN]** section is required unless overriden by the `-d` command line switch.

Sample `~/.bind9/config.cfg` file:

```ini
[GENERAL]
IP_URL=https://checkip.amazonaws.com/
MAX_IP_AGE=5
BACKUP_DIR=/tmp/bind9_dns
TMP_IP_FILE=/tmp/current_ip_address

[BIND_CONF]
ZONE_MAIN=/etc/bind/named.conf

[BIND_FILES]
/var/lib/bind/www.domain.tld.hosts
/var/lib/bind/sales.othdomain.tld.hosts
/var/lib/bind/mydomain.tld.com.hosts

[DOMAIN]
LOOKUP=www.domain.tld
```

#### [GENERAL]

| Setting    | Default                        | Description                                                 |
|------------|--------------------------------|-------------------------------------------------------------|
| IP_URL     | https://checkip.amazonaws.com/ | The URL used to get public Ip address from                  |
| MAX_IP_AGE | 5                              | The amount of time in minutes to cache public url           |
| BACKUP_DIR | /tmp/bind9_dns                 | The directory used to backup the previous bind hosts files  |
| TMP_IP_FILE| /tmp/current_ip_address        | The file to cache the current public addres in              |

#### [BIND_CONF]

| Setting    | Default              | Descripton                       |
|------------|----------------------|----------------------------------|
| ZONE_MAIN  | /etc/bind/named.conf | The file path to bind named.conf |

### Command line

```txt
-d  The domain used to get the current local ip address from
-m  The full path to named.conf file. Default: /etc/bind/named.conf
-i  The ip address to be used. Default the the ip address provided by: https://checkip.amazonaws.com/
-u  The url that will be used to query IP address. Default is https://checkip.amazonaws.com/
-t  The amount of thime the IP address is cached in minutes. Default is 5
-r  Restore files from backup if existing
-v  Display version info
-h  Display help.
```

* `-d` overrides `LOOKUP` in [DOMAIN] section.
* `-m` overrides `ZONE_MAIN` in [BIND_CONF] section.
* `-i` passes in the ip address to update and overrides the public ip address that is read from `IP_URL` or `-u`
* `-u` overrides `IP_URL` in [GENERAL] section.
* `-t` overrides `MAX_IP_AGE` in [GENERAL] section.
