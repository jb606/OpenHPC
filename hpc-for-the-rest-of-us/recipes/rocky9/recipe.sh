#!/bin/bash
# -----------------------------------------------------------------------------------------
#  The following installation script is based on recipes from Intel, installation
#  guides from Warewulf, and installation processes from the Stanford HPC Center.
#
#  This script uses inputs that describe local hardware characteristics, desired
#  network settings, and other customizations specific to the Stanford High 
#  Performance Computing Center Teaching Clusters.
#
# -----------------------------------------------------------------------------------------

date

sms_name=`hostname -s`
sms_ip="10.10.111.1"
sms_network="10.10.111.0"
sms_netmask="255.255.255.0"
sms_startip="10.10.111.101"
sms_endip="10.10.111.199"
ntp_server="172.16.161.1"
sms_eth_internal="ens19"
ww_version="4.4.1"
ohpc_version="3"
ohpc_rev="1"
hostname `hostname -s`

hostnamectl set-hostname `hostname -s`



echo "Setting up repos"
dnf config-manager --set-enabled crb
yum update -y


dnf -y install http://repos.openhpc.community/OpenHPC/$ohpc_version/EL_9/x86_64/ohpc-release-$ohpc_version-$ohpc_rev.el9.x86_64.rpm


dnf -y install ohpc-base wget curl gpgme-devel libassuan-devel

dnf -y install tftp-server nfs-utils dhcp-server

groupadd -r warewulf
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

dnf -y install golang rpmdevtools

rpmdev-setuptree

wget https://github.com/hpcng/warewulf/archive/refs/tags/v$ww_version.zip

unzip v$ww_version.zip

tar -zcf /root/rpmbuild/SOURCES/warewulf-$ww_version.tar.gz warewulf-$ww_version

cd warewulf-$ww_version

make config

cp warewulf.spec /root/rpmbuild/SPECS/

cd ..

rpmbuild -bb /root/rpmbuild/SPECS/warewulf.spec
fi
dnf -y install /root/rpmbuild/RPMS/x86_64/warewulf-$ww_version-1.el9.x86_64.rpm

systemctl daemon-reload

systemctl enable warewulfd --now
perl -pi -e "s/192.168.200.1/$sms_ip/" /etc/warewulf/warewulf.conf
perl -pi -e "s/255.255.255.0/$sms_netmask/" /etc/warewulf/warewulf.conf
perl -pi -e "s/192.168.200.0/$sms_network/" /etc/warewulf/warewulf.conf
perl -pi -e "s/host overlay: false/host overlay: true/" /etc/warewulf/warewulf.conf
perl -pi -e "s/template: default/template: static/" /etc/warewulf/warewulf.conf
perl -pi -e "s/192.168.200.50/$sms_startip/" /etc/warewulf/warewulf.conf
perl -pi -e "s/192.168.200.99/$sms_endip/" /etc/warewulf/warewulf.conf
perl -pi -e "s/mount: false/mount: true/" /etc/warewulf/warewulf.conf
perl -pi -e "s/mount options: \"\"/mount options: defaults/" /etc/warewulf/warewulf.conf

wwctl profile set -y default --netdev eth0 --netmask $sms_netmask --gateway $sms_ip --type ethernet --onboot yes

wwctl configure --all

dnf -y install gcc

dnf -y install gnu9-compilers-ohpc

dnf -y install gnu12-compilers-ohpc

perl -pi -e "s/family \"compiler\"//" /opt/ohpc/pub/modulefiles/gnu9/9.4.0

perl -pi -e "s/family\(\"compiler\"\)//" /opt/ohpc/pub/modulefiles/gnu12/12.2.0.lua


# singularity fix

dnf install -y apptainer


dnf -y install dmidecode numactl-libs numactl-devel mlocate rpm-build wget

#wwctl container import docker://warewulf/rocky:8 rocky-9 --setdefault
wwctl container import docker://ghcr.io/hpcng/warewulf-rockylinux:9 rocky-9

echo export CHROOT=/var/lib/warewulf/chroots/rocky-9/rootfs >> /root/.bash_profile

. /root/.bash_profile

useradd labadm

echo password | passwd --stdin secret

wwctl container syncuser --write rocky-9

dnf --installroot=$CHROOT config-manager --setopt="install_weak_deps=False" --save

dnf --installroot=$CHROOT config-manager --set-enabled powertools

#dnf -y --installroot=$CHROOT install http://repos.openhpc.community/OpenHPC/2/EL_8/x86_64/ohpc-release-2-1.el8.x86_64.rpm

# dnf --installroot=$CHROOT config-manager --add-repo http://yum.repos.intel.com/hpc-platform/el8/setup/intel-hpc-platform.repo

# rpm --root=$CHROOT --import http://yum.repos.intel.com/hpc-platform/el8/setup/PUBLIC_KEY.PUB

dnf -y --installroot=$CHROOT update

dnf -y --installroot=$CHROOT install kernel-modules

dnf -y --installroot=$CHROOT remove --oldinstallonly

dnf -y --installroot=$CHROOT install apptainer

dnf -y --installroot=$CHROOT install ohpc-base-compute

# dnf -y --installroot=$CHROOT install "intel-hpc-platform-*"

dnf -y --installroot=$CHROOT install dmidecode parted grub2 numactl chrony

systemctl --root=$CHROOT enable chronyd.service

perl -pi -e "s/pool 2.rocky.pool.ntp.org iburst/server $sms_ip/" $CHROOT/etc/chrony.conf 

#dnf -y --installroot=$CHROOT install lua lua-filesystem lua-posix

wwctl overlay mkdir generic /etc/profile.d

wwctl overlay import generic /etc/profile.d/lmod.sh

wwctl overlay import generic /etc/profile.d/lmod.csh

dnf -y --installroot=$CHROOT install gcc libstdc++-devel cmake

#yum -y groupinstall "InfiniBand Support"

#yum -y --installroot=$CHROOT groupinstall "InfiniBand Support"

perl -pi -e 's/# End of file/\* soft memlock unlimited\n$&/s' /etc/security/limits.conf
perl -pi -e 's/# End of file/\* hard memlock unlimited\n$&/s' /etc/security/limits.conf
perl -pi -e 's/# End of file/\* soft memlock unlimited\n$&/s' ${CHROOT}/etc/security/limits.conf
perl -pi -e 's/# End of file/\* hard memlock unlimited\n$&/s' ${CHROOT}/etc/security/limits.conf

#dnf -y install pmix-ohpc

dnf -y install ohpc-slurm-server

dnf -y --installroot=$CHROOT install ohpc-slurm-client

cp /etc/slurm/slurm.conf.ohpc /etc/slurm/slurm.conf

cp /etc/slurm/cgroup.conf.example /etc/slurm/cgroup.conf

perl -pi -e "s/SlurmctldHost=\S+/SlurmctldHost=`hostname -s`/" /etc/slurm/slurm.conf

perl -pi -e "s/JobCompType\=jobcomp\/filetxt/\\#JobCompType\=jobcomp\/filetxt/" /etc/slurm/slurm.conf
sed -i '59s/TaskPlugin\=task\/affinity/\#TaskPlugin\=task\/affinity/g' /etc/slurm/slurm.conf

perl -pi -e "s/^NodeName=(\S+)/NodeName=n[1-9]/" /etc/slurm/slurm.conf

perl -pi -e "s/^PartitionName=normal Nodes=(\S+)/PartitionName=normal Nodes=n[1-9]/" /etc/slurm/slurm.conf

perl -pi -e "s/ Nodes=c\S+ / Nodes=ALL /" /etc/slurm/slurm.conf

perl -pi -e "s/ReturnToService=1/ReturnToService=2/" /etc/slurm/slurm.conf

chroot $CHROOT systemctl enable munge

chroot $CHROOT systemctl enable slurmd

echo SLURMD_OPTIONS="--conf-server `hostname -s`" > $CHROOT/etc/sysconfig/slurmd

cp /etc/munge/munge.key $CHROOT/etc/munge/

chroot $CHROOT chown munge.munge /etc/munge/munge.key

systemctl enable munge
systemctl start munge
systemctl enable slurmctld
systemctl start slurmctld

#dnf -y install opensm
#systemctl enable opensm
#systemctl start opensm

cat << EOT >> $CHROOT/etc/warewulf/excludes
/opt/*
/home/*
/tmp/*
/var/log/*
/var/run/*
EOT

# ----------------------------
# Updates to recipe.sh for HPC for the rest of us! tutorials
# ----------------------------

# added for paraview
#yum -y --installroot=$CHROOT install mesa-libGLU

#wwctl container build rocky-9

#wwctl node add compute-1-1 -n cluster -I 10.10.1.1 -H ${mac_address}

#wwctl node set -y compute-1-1 -A "quiet crashkernel=no vga=791 rootfstype=ramfs"

#wwctl configure --all

#wwctl overlay build

#wwctl server restart

#ipmitool -H 10.2.2.2 -U USERID -P PASSW0RD chassis power cycle

# dnf -y install intel-oneapi-toolkit-release-ohpc

# dnf -y install intel-hpckit

# dnf -y install intel-compilers-devel-ohpc intel-mpi-devel-ohpc

date
