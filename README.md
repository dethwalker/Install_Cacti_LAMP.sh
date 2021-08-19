# Install_Cacti_LAMP.sh
Install script for Cacti on CentOS Stream 8

What does this script do?

1) Install Apache and configure it for Cacti
2) Install PHP and configure it for Cacti
3) Install MariaDB and configure it for Cacti
4) Install snmpd on host machine for Cacti
5) Change SELinux policy so that Cacti can run in "enforcing mode"



Requirements:

1) Must be root
2) MAKE SURE YOU CONFIGURE YOUR TIMEZONE BEFORE RUNNING THIS SCRIPT!
3) Clean fresh install of CentOS Stream 8 with no GUI


Warning:

I am not a specialist in bash scripting. This script may not be perfect. This script has only been tested on a fresh server install of CentOS Stream 8 with no GUI. Do not run this script on a machine that is running other important processes because it will mess things up!


Info:

This script follows the installation guidelines from here https://www.server-world.info/en/note?os=CentOS_Stream_8&p=cacti&f=1
