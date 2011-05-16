#!/bin/sh
#
# Installation automatique de Shinken sous Debian
#
# Nicolas Hennion aka Nicolargo
# Script libre: GPLv3
#
# Syntaxe: root> ./shinkenautoinstall-debian.sh
#
#
script_version="0.45"

### Can be modified
shinken_version="0.6"				#
thruk_version="1.0.3"				#
arch_version="`uname -m`" 			# i386 | i486 | x86_64
perl_version="5.10.0" 				# `perl -e 'use Config; print $Config{version}'`
multiprocessing_version="2.6.2.1"		#
### /Can be modified

DATE=`date +"%Y%m%d%H%M%S"`
BACKUP_FILE="/tmp/shinken-backup-$DATE.tgz"

# Function: backup
backup() {
  echo "----------------------------------------------------"
  echo "Backup the current configuration"
  echo "----------------------------------------------------"
  echo ""
  tar zcvf $BACKUP_FILE /etc/shinken
}

# Function: installation
installation() {
  # Create the temporary directory
  mkdir ~/$0.$DATE

  # Pre-requisite
  echo "----------------------------------------------------"
  echo "Installation pre-requisites"
  echo " * python-dev python-setuptools pyro wget libgd2-xpm-dev nagios-plugins"
  echo " * multiprocessing version $multiprocessing_version"
  echo "----------------------------------------------------"
  aptitude install python-dev python-setuptools pyro wget libgd2-xpm-dev nagios-plugins
  cd ~/$0.$DATE
  wget http://pypi.python.org/packages/source/m/multiprocessing/multiprocessing-$multiprocessing_version.tar.gz
  if [ "$?" -ne "0" ]; then
  	echo "Download Shinken version $multiprocessing_version [ERROR]"
  	exit 1 
  fi
  tar zxvf multiprocessing-$multiprocessing_version.tar.gz
  cd multiprocessing-$multiprocessing_version/
  python setup.py install

  # echo "----------------------------------------------------"
  # echo "Install and configure Postfix"
  # echo "----------------------------------------------------"
  # aptitude install mailx postfix
  # ln -s /usr/bin/mail /bin/mail

  # Download sources
  echo "----------------------------------------------------"
  echo "Download sources"
  echo " * Shinken version $shinken_version"
  echo " * Thruk version $thruk_version"
  echo "----------------------------------------------------"
  cd ~/$0.$DATE
  wget http://shinken-monitoring.org/pub/shinken-$shinken_version.tar.gz 
  if [ "$?" -ne "0" ]; then
  	echo "Download Shinken version $shinken_version [ERROR]"
  	exit 1 
  fi
  wget http://www.thruk.org/files/Thruk-$thruk_version-$arch_version-linux-gnu-thread-multi-$perl_version.tar.gz
  if [ "$?" -ne "0" ]; then
  	echo "Try another mirror for Thruk (archives)..."
  	wget http://www.thruk.org/files/archive/Thruk-$thruk_version-$arch_version-linux-gnu-thread-multi-$perl_version.tar.gz
  if [ "$?" -ne "0" ]; then
	  echo "Download Thruk version $shinken_version [ERROR]"
	  exit 1 
	fi
  fi

  # Create shinken user and group
  if [ ! `id -u shinken` ]
  then
    echo "----------------------------------------------------"
    echo "Creation utilisateur shinken et groupe shinken"
    echo "----------------------------------------------------"
    useradd -s /bin/noshellneeded shinken
    echo "Fixer un mot de passe pour l'utilisateur shinken"
    passwd shinken
    usermod -G shinken shinken
  fi

  # Installation
  echo "----------------------------------------------------"
  echo "Configure, compile and install..."
  echo "----------------------------------------------------"
  cd ~/$0.$DATE
  tar zxvf shinken-$shinken_version.tar.gz
  cd shinken-$shinken_version
  python setup.py install --install-scripts=/usr/bin/  
  cp libexec/* /usr/lib/nagios/plugins/
  cd ~/$0.$DATE
  tar zxvf Thruk-$thruk_version-$arch_version-linux-gnu-thread-multi-$perl_version.tar.gz
  cd Thruk-$thruk_version
  wget http://svn.nicolargo.com/shinkenautoinstall/trunk/thruk_local.conf
  cd ..
  mkdir /opt/thruk
  cp -R Thruk-$thruk_version/* /opt/thruk
  chown -R shinken:shinken /opt/thruk

  echo "----------------------------------------------------"
  echo "Hack the default Shinken startup script"
  echo "----------------------------------------------------"
  sed -i 's/BIN="\/usr\/local\/shinken\/bin"/BIN="\/usr\/bin"/g' /etc/init.d/shinken
  sed -i 's/VAR="\/usr\/local\/shinken\/var"/VAR="\/var\/lib\/shinken"/g' /etc/init.d/shinken
  sed -i 's/ETC="\/usr\/local\/shinken\/etc"/ETC="\/etc\/shinken"/g' /etc/init.d/shinken
  wget -O /etc/init.d/thruk http://svn.nicolargo.com/shinkenautoinstall/trunk/thruk
  chown root:root /etc/init.d/thruk
  chmod a+rx /etc/init.d/thruk

  echo "----------------------------------------------------"
  echo "Start Shinken and Thruk on boot"
  echo "----------------------------------------------------"
  update-rc.d shinken defaults
  update-rc.d thruk defaults

  rm -rf ~/$0.$DATE
}

# Fonction: Verifie si les fichiers de conf sont OK
check() {
  echo "----------------------------------------------------"
  echo "Check the Shinken configuration"
  echo "----------------------------------------------------"
  python /usr/bin/shinken-arbiter -v -c /etc/shinken/nagios.cfg -c /etc/shinken/shinken-specific.cfg
}   

# Fonction: Lancement de Shinken
start() {
  echo "----------------------------------------------------"
  echo "Start Shinken and Thruk"
  echo "----------------------------------------------------"
  sleep 2
  /etc/init.d/shinken start
  /etc/init.d/thruk start
}

# Fonction: Arret de Shinken
stop() {
  echo "----------------------------------------------------"
  echo "Arret de Shinken et de Thruk"
  echo "----------------------------------------------------"
  sleep 2
  /etc/init.d/shinken stop
  /etc/init.d/thruk stop
}

# Fonction: Affiche le résumé de l'installation
end() {
  echo "----------------------------------------------------"
  echo "Installation is finished"
  echo "----------------------------------------------------"
  if [ -f $BACKUP_FILE ]; then
  echo "Backup configuration file         : $BACKUP_FILE"     
  fi
  echo "Configuration file folder         : /etc/shinken"
  echo "Log file                          : /var/lib/shinken/nagios.log"
  echo "Shinken startup script            : /etc/init.d/shinken"
  echo "Thruk startup script              : /etc/init.d/thruk"
  echo "Thruk web interface URL           : http://`hostname`:3000"
}

# Programme principal
if [ "$(id -u)" != "0" ]; then
	echo "This script should be run as root."
	echo "Syntaxe: sudo $0"
	exit 1
fi
if [ -d /etc/shinken ]; then	
    stop
    backup
fi
installation
check
start
end
