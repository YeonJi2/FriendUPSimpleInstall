# FriendUPSimpleInstall
This script was created to help installing FriendUP(for personal use) on Raspberry Pi running Raspbian, although this may work on other debian based Linux distros.

Note that **this was designed to simplify installation**, so user won't get much control(although some things can be changed in FriendUP installer, which this script runs later for actual installation).

Also, **FriendUP source directory will be located at where you run script from,** and FriendUP files will be built and installed under (FriendUP Source directory)/build.

## Tested environment
This script was tested on Raspbian 2018/06/27 release.

## What this does
**While this mostly tells about how it works, I recommand checking out step 10, 13, and 14 if you want to install using this script.**

1. Gathers information from user, which includes MySQL/MariaDB root/database passwords, domain name, and whether user wants to use SSL/TLS or not.
2. Updates package information(```sudo apt update```).
3. Upgrades all packages(```sudo apt upgrade -y```).
4. Installs sed(if needed), MySQL server, and packages that is required to run FriendUP installer.
5. Sets MySQL/MariaDB password
6. Downloads FriendUP source code using ```git``` command.
7. Patches installer file(install.sh). Script patches two things:
 - Replaces **libmysqlclient-dev** with **libmariadbclient-dev**. Former one seems like an outdated name.
 - Removes **phpmyadmin** to prevent installing PHPMyAdmin. While this is not an issue, users who just want to get FriendUP up and running doesn't really need PHPMyAdmin. Also, It asks few things to user during installation, and I wanted to make this script as "unattended" installer as possible. While FriendUP installer also asks few things, most of them are **already set by this script.**
8. Creates FriendUP related directories.
9. Creates configuration file(cfg.ini) to tell installer the configuration you want.
10. Starts FriendUP installer. **If it says that it has detected previous installation and asks if you want to continue**, choose Yes. For other things, most of them should be set to value what you want, and only thing you have to tell installer is **MySQL/MariaDB root password**, which is required to setup FriendUP DB.
11. Stops Friend services
12. Configures apache(for stopping), and stops server.
13. **This part is optional,** but it also helps you setting up SSL/TLS using Let's Encrypt(LE) service(If you chose to use SSL/TLS). You just have to answer few more questions, and you are ready to go. Not only this step runs Certbot to help you that, **it also links your certificate files to actual path where FriendUP looks certificate files for.**
- **IMPORTANT**: Doing this automated installation disables apache2 service. If you don't want that, please configure LE manually.
```
- From commit description:
Disables apache2.service when user wants to setup ACMEv2.
Now, it's possible to tell Certbot to stop Apache and restart after it's done(Certbot runs automatically before certificate expires), but I simply don't have enough time to test that.
```
14. Installs Friend Core as systemd service and enables it(so that Friend Core will start when system boots).
