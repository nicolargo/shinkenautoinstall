#!/bin/bash
#
# Installation automatique de Shinken sous Debian
#
# Nicolas Hennion aka Nicolargo
# Script libre: GPLv3
#
# Syntaxe: root> ./shinkenautoinstall-debian.sh
#
#
script_version="0.651112"

#=============================================================================
### Can be modified
shinken_version="0.6.5"
thruk_version="1.1.1"
arch_version="`uname -m`" 		# May be change to: i386 | i486 | x86_64
perl_version="5.10.0" 			# `perl -e 'use Config; print $Config{version}'`
multiprocessing_version="2.6.2.1"
### /Can be modified
#=============================================================================

# Globals variables
#-----------------------------------------------------------------------------

# Get the **good** architecture name for Thruk
case $arch_version in
  "i386"|"i686")
	arch_version="i486"
	;;
esac

DATE=`date +"%Y%m%d%H%M%S"`
CMD_APT="/usr/bin/apt-get --force-yes --yes"

TEMP_FOLDER="/tmp/shinkenautoinstall.$DATE"
BACKUP_FILE="/tmp/shinken-backup-$DATE.tgz"
LOG_FILE="/tmp/shinkenautoinstall-$DATE.log"

# Functions
#-----------------------------------------------------------------------------

displaymessage() {
  echo "$*"
}

displaytitle() {
  displaymessage "------------------------------------------------------------------------------"
  displaymessage "$*"  
  displaymessage "------------------------------------------------------------------------------"

}

displayerror() {
  displaymessage "$*" >&2
}

# First parameter: ERROR CODE
# Second parameter: MESSAGE
displayerrorandexit() {
  local exitcode=$1
  shift
  displayerror "$*"
  exit $exitcode
}

# First parameter: MESSAGE
# Others parameters: COMMAND (! not |)
displayandexec() {
  local message=$1
  echo -n "[En cours] $message"
  shift
  $* >> $LOG_FILE 2>&1 
  local ret=$?
  if [ $ret -ne 0 ]; then
    echo -e "\r\e[0;31m   [ERROR]\e[0m $message"
    # echo -e "\r   [ERROR] $message"
  else
    echo -e "\r\e[0;32m      [OK]\e[0m $message"
    # echo -e "\r      [OK] $message"
  fi 
  return $ret
}

# Function: backup
backup() {
  displayandexec "Compress and archive" tar zcvf $BACKUP_FILE /etc/shinken
}

# Function: installation
installation() {
  # Create the temporary directory
  mkdir $TEMP_FOLDER

  # Pre-requisite
  # python-dev python-setuptools pyro wget libgd2-xpm-dev nagios-plugins"
  # multiprocessing version $multiprocessing_version
  displayandexec "Install wget, nagios plugins and librairies" $CMD_APT install python-dev python-setuptools pyro wget libgd2-xpm-dev
  cd $TEMP_FOLDER
  displayandexec "Download Multiprocessing v$multiprocessing_version" wget http://pypi.python.org/packages/source/m/multiprocessing/multiprocessing-$multiprocessing_version.tar.gz
  displayandexec "Untar Multiprocessing v$multiprocessing_version"  tar zxvf multiprocessing-$multiprocessing_version.tar.gz
  cd multiprocessing-$multiprocessing_version/
  displayandexec "Install Multiprocessing v$multiprocessing_version" python setup.py install

  # echo "----------------------------------------------------"
  # echo "Install and configure Postfix"
  # echo "----------------------------------------------------"
  # aptitude install mailx postfix
  # ln -s /usr/bin/mail /bin/mail

  # Download sources
  cd $TEMP_FOLDER
  displayandexec "Download Shinken version $shinken_version" wget http://shinken-monitoring.org/pub/shinken-$shinken_version.tar.gz
  displayandexec "Download Thruk version $thruk_version" wget http://www.thruk.org/files/Thruk-$thruk_version-$arch_version-linux-gnu-thread-multi-$perl_version.tar.gz
  if [ "$?" -ne "0" ]; then
  	displayandexec "Try another mirror for Thruk..." wget http://www.thruk.org/files/archive/Thruk-$thruk_version-$arch_version-linux-gnu-thread-multi-$perl_version.tar.gz
  fi

  # Create shinken user and group
  if [ ! `id -u shinken` ]
  then
    displayandexec "Create the Shinken user" useradd -s /bin/noshellneeded shinken
    echo "Set a password for the system shinken user account:"
    passwd shinken
    displayandexec "Create the Shinken group" usermod -G shinken shinken
  fi

  # Installation
  cd $TEMP_FOLDER
  displayandexec "Untar Shinken v$shinken_version" tar zxvf shinken-$shinken_version.tar.gz
  cd shinken-$shinken_version
  displayandexec "Install Shinken v$shinken_version" python setup.py install --install-scripts=/usr/bin/
  cp libexec/* /usr/lib/nagios/plugins/
  cd $TEMP_FOLDER
  displayandexec "Untar Thruk v$thruk_version for $arch_version" tar zxvf Thruk-$thruk_version-$arch_version-linux-gnu-thread-multi-$perl_version.tar.gz
  cd Thruk-$thruk_version
  rm -f thruk_local.conf
  displayandexec "Download the default Thruk configuration for Shinken" wget --no-check-certificate https://raw.github.com/nicolargo/shinkenautoinstall/master/thruk_local.conf
  if [ ! -d /opt/thruk ]; then
    mkdir /opt/thruk
  else
    rm -rf /opt/thruk.old
    mv /opt/thruk /opt/thruk.old
    mkdir /opt/thruk
  fi
  displayandexec "Install Thruk v$thruk_version for $arch_version" cp -R * /opt/thruk
  chown -R shinken:shinken /opt/thruk

  # Hack for the i686 Linux GNU Thread Multi lib
  # Thanks to: Yann :)
  if [ -f /opt/thruk/local-lib/lib/perl5/i486-linux-gnu-thread-multi ]; then    
    displayandexec "Hack for the i686 Linux GNU Thread Multi lib" ln -s /opt/thruk/local-lib/lib/perl5/i486-linux-gnu-thread-multi /opt/thruk/local-lib/lib/perl5/i686-linux-gnu-thread-multi
  fi

  sed -i 's/BIN="\/usr\/local\/shinken\/bin"/BIN="\/usr\/bin"/g' /etc/init.d/shinken
  sed -i 's/VAR="\/usr\/local\/shinken\/var"/VAR="\/var\/lib\/shinken"/g' /etc/init.d/shinken
  sed -i 's/ETC="\/usr\/local\/shinken\/etc"/ETC="\/etc\/shinken"/g' /etc/init.d/shinken
  displayandexec "Download startup scripts" wget --no-check-certificate -O /etc/init.d/thruk https://raw.github.com/nicolargo/shinkenautoinstall/master/thruk
  chown root:root /etc/init.d/thruk
  chmod a+rx /etc/init.d/thruk
  displayandexec "Install Shinken startup script" update-rc.d shinken defaults
  displayandexec "Install Thruk startup script" update-rc.d thruk defaults

  rm -rf $TEMP_FOLDER
}

# Fonction: Verifie si les fichiers de conf sont OK
check() {
  sleep 2
  displayandexec "Check the Shinken configurations files" /usr/bin/shinken-arbiter -v -c /etc/shinken/nagios.cfg -c /etc/shinken/shinken-specific.cfg
}

# Fonction: Lancement de Shinken
start() {
  sleep 2
  displayandexec "Start Shinken" /etc/init.d/shinken start
  displayandexec "Start Thruk" /etc/init.d/thruk start
}

# Fonction: Arret de Shinken
stop() {
  sleep 2
  displayandexec "Stop Shinken" /etc/init.d/shinken stop
  displayandexec "Stop Thruk" /etc/init.d/thruk stop
}

# Fonction: Affiche le résumé de l'installation
end() {
  echo ""
  echo "=============================================================================="
  echo "Installation is finished"
  echo "=============================================================================="
  if [ -f $BACKUP_FILE ]; then
    echo "Backup configuration file         : $BACKUP_FILE"
  fi
  echo "Log for the installation script   : $LOG_FILE"
  echo "Configuration file folder         : /etc/shinken"
  echo "Log file                          : /var/lib/shinken/nagios.log"
  echo "Shinken startup script            : /etc/init.d/shinken"
  echo "Thruk startup script              : /etc/init.d/thruk"
  echo "Thruk web interface URL           : http://`hostname`:3000"
  echo "=============================================================================="
  echo ""
}

# Main program
#-----------------------------------------------------------------------------

if [ "$(id -u)" != "0" ]; then
	echo "This script should be run as root."
	echo "Syntaxe: sudo $0"
	exit 1
fi
if [ -d /etc/shinken ]; then
 displaytitle "-- Stop current Shinken and Thruk processes"
 stop
 displaytitle "-- Backup the current configuration in $BACKUP_FILE"
 backup
fi
displaytitle "-- Installation"
installation
displaytitle "-- Install Nagios Plugin (interactive)"
$CMD_APT install nagios-plugins
displaytitle "-- Start current Shinken and Thruk process"
start
end

# The end...
