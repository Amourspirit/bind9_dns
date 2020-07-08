# Bind DNS Updaters

This project contains two scripts for updating bind9 on a local server.  
The scripts get the servers public ip address and then update the specified zones with the current public ip address.

Both can do the job of updating bind9 zone files. Only one is needed.  
The recommended way is using [bind9_dns_named.sh](bind9_dns_named.sh).
[Bind9_dns.sh](bind9_dns.sh) is included as an inferior way of accomplishing the same task if [bind9_dns_named.sh](bind9_dns_named.sh) does not work for your setup.

Both scripts preform a backup before making changes to original files.

## Scripts

### bind9_dns_named.sh

The [bind9_dns_named.sh](bind9_dns_named.sh) script uses domain names to find and update the zone records with current public ip address. This script has extra testing of the zone and conf before making and enabling changes.

### bind9_dns.sh

The [bind9_dns.sh](bind9_dns.sh) is simpler and thus not a much robust testing built in. Include just in case your server configuration does not support [bind9_dns_named.sh](bind9_dns_named.sh) script.

## Automation

### Crontab automation

Scripts only update bind9 when there is a public ip address change. This script can be automated by adding it to a *cron job.*
The example below when added to a cron job will run the script every 5 minutes.

```bash
*/5 * * * * /bin/bash $HOME/scripts/bind9/bind9_dns_named.sh >/dev/null 2>&1
```

### Advanced Automation

Starting and running script only when system reboots is sometimes all that is needed. This is the case in cloud computing such as with *AWS* when the server only gets a new IP Address when the server reboots ( if not assigned static IP Address such as *Elastic IPs* ). The issue is that the network is not ready when the system is booting up.

A solution is to run the script as a service for the system.

The following set up running this script as a system service.
**Warning** KNOW what you are doing before you attempt this.

Create a new system service named `bind9_update` by running the following command:

```bash
systemctl edit --force --full bind9_update.service
```

The above command will open the default text editor ( such as nano ). The first time you run the above command the editor will not contain any text.

```ini
[Unit]
Description=Bind9 IP update Service
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/root/scripts/scripts/bind9_dns_named.sh

[Install]
WantedBy=multi-user.target
```

Save your changes and exit your editor.

Check the newly created service

```txt
$ systemctl status bind9_update.service
● bind9_update.service - Bind9 IP update Service
   Loaded: loaded (/etc/systemd/system/bind9_update.service; disabled; vendor preset: enabled)
   Active: inactive (dead)
```

Now we can enable and test our service:

```bash
systemctl enable bind9_update.service
systemctl start bind9_update.service
```

Another status check shows the service is enabled

```bash
$ systemctl status bind9_update.service
● bind9_update.service - Bind9 IP update Service
     Loaded: loaded (/etc/systemd/system/bind9_update.service; enabled; vendor preset: enabled)
     Active: inactive (dead) since Fri 2020-06-19 19:17:57 UTC; 31min ago
    Process: 494 ExecStart=/root/scripts/bind9/bind9_dns_named.sh (code=exited, status=0/SUCCESS)
   Main PID: 494 (code=exited, status=0/SUCCESS)

```

Reboot the computer to test if the service is working.

```bash
systemctl reboot
```

You can edit the service and show it. After editing you must restart the service to take effect.

```bash
systemctl restart bind9_update.service
```

To prevent the service from running on startup you can disable it.

```bash
$ sudo systemctl disable bind9_update.service
Removed /etc/systemd/system/multi-user.target.wants/bind9_update.service.
```

One more status check to confirm disabled.

```bash
$ systemctl status bind9_update.service
● bind9_update.service - bind9_dns_named
     Loaded: loaded (/etc/systemd/system/bind9_update.service; disabled; vendor preset: enabled)
     Active: inactive (dead)
```
