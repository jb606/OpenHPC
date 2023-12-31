#!/bin/bash


if [ -f "openhpc.conf" ]; then
	. openhpc.conf
elif [ -f "/data/openhpc.conf" ]; then
	. /data/openhpc.conf
else
	echo "Unable to find ./openhpc.conf exiting"
	exit 1
fi


if [ ! -f "$HOME/rpmbuild/RPMS/x86_64/warewulf-$ww_version-1.el9.x86_64.rpm" ]; then


  if [ -d "$HOME/rpmbuild" ]; then
    rm -fr $HOME/rpmbuild
  fi
  if [ -f "$PWD/v$ww_version.zip" ]; then
    rm -f $PWD/v$ww_version.zip
  fi
  if [ -d "$PWD/warewulf-$ww_version" ]; then
    rm -fr $PWD/warewulf-$ww_version
  fi
  rm /etc/yum.repos.d/*.repo
  cp /data/repos/*.repo /etc/yum.repos.d/
  yum clean all
  dnf install 'dnf-command(config-manager)' -y
  dnf config-manager --set-enabled crb
  yum update -y
  dnf -y install golang rpmdevtools gpgme-devel libassuan-devel wget firewalld-filesystem systemd git

  rpmdev-setuptree

  wget https://github.com/hpcng/warewulf/archive/refs/tags/v$ww_version.zip

  unzip v$ww_version.zip

  tar -zcf /root/rpmbuild/SOURCES/warewulf-$ww_version.tar.gz warewulf-$ww_version

  cd warewulf-$ww_version

  make config

  cp warewulf.spec /root/rpmbuild/SPECS/

  cd ..

  rpmbuild -bb /root/rpmbuild/SPECS/warewulf.spec
  cp /root/rpmbuild/RPMS/x86_64/warewulf-$ww_version-1.el9.x86_64.rpm /data/

  echo "warewulf-$ww_version-1.el9.x86_64.rpm can be found in $PWD"
else
  echo "Warewulf already compliled in $HOME/rpmbuild/RPMS/x86_64/"
  echo 
  echo "run rm -f $HOME/rpmbuild/RPMS/x86_64/warewulf-$ww_version-1.el9.x86_64.rpm to rebuild"
  echo
  exit 0
fi
