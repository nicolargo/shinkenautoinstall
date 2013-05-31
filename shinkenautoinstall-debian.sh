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
script_version="1.2.0-1"

# Globals variables
#-----------------------------------------------------------------------------

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
  displayandexec "Archive current configuration" tar zcvf $BACKUP_FILE /etc/shinken
}

# Function: installation
installation() {
  displaymessage "Install Shinken - Begin"  
  curl -L http://install.shinken-monitoring.org | /bin/bash
  displaymessage "Install Shinken - End"    
}

# Fonction: Verifie si les fichiers de conf sont OK
check() {
  rm -f /tmp/shinken_checkconfig_result
  displayandexec "Check the Shinken configurations files" /etc/init.d/shinken check
}

# Fonction: Lancement de Shinken
start() {
  sleep 2
  displayandexec "Start Shinken" /etc/init.d/shinken start
}

# Fonction: Arret de Shinken
stop() {
  sleep 2
  displayandexec "Stop Shinken" /etc/init.d/shinken stop
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
  echo "Configuration file folder         : /usr/local/shinken/etc"
  echo "Log file                          : /var/log/shinken"
  echo "Shinken startup script            : /etc/init.d/shinken"
  echo "Shinken web interface URL         : http://`hostname --fqdn`:7767"
  echo "Log for the installation script   : $LOG_FILE"
  echo "Log for the Shinken config check  : /tmp/shinken_checkconfig_result"
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
 displaytitle "-- Stop current Shinken process"
 stop
 displaytitle "-- Backup the current configuration in $BACKUP_FILE"
 backup
fi
displaytitle "-- Installation"
installation
displaytitle "-- Check the Shinken configuration files"
check
displaytitle "-- Start Shinken Thruk process"
start
end

# The end...
