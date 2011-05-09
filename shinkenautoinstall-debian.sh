#!/bin/sh
#
# Installation automatique de Shinken sous Debian
#
# Nicolas Hennion aka Nicolargo
# Script libre: GPLv3
#
# Syntaxe: root> ./shinkenautoinstall-debian.sh
#
# Version 0.3
#   MaJ de Thruk en 1.0.1
#
# Version 0.2
#   MaJ de Shinken 0.6
#   MaJ de Thruk 0.94.4
#
# Version 0.1:
#   Installation de Shinken 0.5.5
#   Installation de Thruk 0.90
#
script_version="0.3"

### A modifier
shinken_version="0.6"	#
thruk_version="1.0.1"	#
arch_version="`arch`" 	# Remplacer `arch` par i386 ou x86_64 selon votre architecture
perl_version="5.10.0" 	# perl_version=`perl -e 'use Config; print $Config{version}'`
### /A modifier

DATE=`date +"%Y%m%d%H%M%S"`
BACKUP_FILE="/tmp/shinken-backup-$DATE.tgz"

# Fonction: backup
backup() {
  echo "----------------------------------------------------"
  echo "Backup de la configuration existante"
  echo "----------------------------------------------------"
  echo ""
  tar zcvf $BACKUP_FILE
}

# Fonction: installation
installation() {
  echo "----------------------------------------------------"
  echo "Installation de:"
  echo " * Shinken version $shinken_version"
  echo " * Thruk version $thruk_version"
  echo "----------------------------------------------------"
  echo ""
  # Creation du répertoire temporaire
  mkdir ~/$0.$DATE

  # Pre-requis
  echo "----------------------------------------------------"
  echo "Installation de pre-requis"
  echo "----------------------------------------------------"
  aptitude install python-dev python-setuptools pyro wget libgd2-xpm-dev
  cd ~/$0.$DATE
  wget http://pypi.python.org/packages/source/m/multiprocessing/multiprocessing-2.6.2.1.tar.gz
  tar zxvf multiprocessing-2.6.2.1.tar.gz
  cd multiprocessing-2.6.2.1/
  python setup.py install

  # echo "----------------------------------------------------"
  # echo "Installation et configuration Postfix"
  # echo "----------------------------------------------------"
  # aptitude install mailx postfix
  # ln -s /usr/bin/mail /bin/mail

  # Creation de l'utilisateur shinken et du groupe shinken
  echo "----------------------------------------------------"
  echo "Creation utilisateur shinken et groupe shinken"
  echo "----------------------------------------------------"
  useradd -s /bin/noshellneeded shinken
  echo "Fixer un mot de passe pour l'utilisateur shinken"
  passwd shinken
  usermod -G shinken shinken

  # Téléchargement
  echo "----------------------------------------------------"
  echo "Telechargement"
  echo "----------------------------------------------------"
  cd ~/$0.$DATE
  wget http://shinken-monitoring.org/pub/shinken-$shinken_version.tar.gz  
  wget http://www.thruk.org/files/Thruk-$thruk_version-$arch_version-linux-gnu-thread-multi-$perl_version.tar.gz

  # Installation
  echo "----------------------------------------------------"
  echo "Installation"
  echo "----------------------------------------------------"
  cd ~/$0.$DATE
  tar zxvf shinken-$shinken_version.tar.gz
  cd shinken-$shinken_version
  python setup.py install --install-scripts=/usr/bin/  
  cd ~/$0.$DATE
  tar zxvf Thruk-$thruk_version-`arch`-linux-gnu-thread-multi-$perl_version.tar.gz
  cd Thruk-$thruk_version
  wget http://svn.nicolargo.com/shinkenautoinstall/trunk/thruk_local.conf
  cd ..
  cp -R Thruk-$thruk_version /opt/thruk
  chown -R shinken:shinken /opt/thruk

  echo "----------------------------------------------------"
  echo "Hack sur le script init.d de shinken"
  echo "----------------------------------------------------"
  sed -i 's/BIN="\/usr\/local\/shinken\/bin"/BIN="\/usr\/bin"/g' /etc/init.d/shinken
  sed -i 's/VAR="\/usr\/local\/shinken\/var"/VAR="\/var\/lib\/shinken"/g' /etc/init.d/shinken
  sed -i 's/ETC="\/usr\/local\/shinken\/etc"/ETC="\/etc\/shinken"/g' /etc/init.d/shinken
  wget -O /etc/init.d/thruk http://svn.nicolargo.com/shinkenautoinstall/trunk/thruk
  chown root:root /etc/init.d/thruk
  chmod a+rx /etc/init.d/thruk

  echo "----------------------------------------------------"
  echo "Automatisation du lancement au boot"
  echo "----------------------------------------------------"
  update-rc.d shinken defaults
  update-rc.d thruk defaults

  rm -rf ~/$0.$DATE
}

# Fonction: Verifie si les fichiers de conf sont OK
check() {
  echo "----------------------------------------------------"
  echo "Vérification de la configuration de Shinken"
  echo "----------------------------------------------------"
  python /usr/bin/shinken-arbiter -v -c /etc/shinken/nagios.cfg -c /etc/shinken/shinken-specific.cfg
}   

# Fonction: Lancement de Shinken
start() {
  echo "----------------------------------------------------"
  echo "Lancement de Shinken et de Thruk"
  echo "----------------------------------------------------"
  /etc/init.d/shinken start
  /etc/init.d/thruk start
}

# Fonction: Affiche le résumé de l'installation
end() {
  echo "----------------------------------------------------"
  echo "Installation terminée"
  echo "----------------------------------------------------"
  if [ -f $BACKUP_FILE ]; then
  echo "Ancienne configuration (backup)   : $BACKUP_FILE"     
  fi
  echo "Fichiers de configuration         : /etc/shinken"
  echo "Fichiers de logs                  : /var/lib/shinken/nagios.log"
  echo "Script de lancement de Shinken    : /etc/init.d/shinken"
  echo "Script de lancement de Thruk      : /etc/init.d/thruk"
  echo "Interface d'administration        : http://`hostname`:3000"
}

# Programme principal
if [ "$(id -u)" != "0" ]; then
	echo "Il faut les droits d'administration pour lancer ce script."
	echo "Syntaxe: sudo $0"
	exit 1
fi
if [ -d /etc/shinken ]; then
    backup
fi
installation
check
start
end


