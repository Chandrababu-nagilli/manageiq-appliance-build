#version=RHEL9

### See CHANGEME lines and adjust as needed ###

ignoredisk --only-use=sda
zerombr
clearpart --all --initlabel --drives=sda
partition /boot --ondisk=sda --asprimary --size=1024 --fstype=xfs
partition pv.1 --ondisk=sda --asprimary --size=10240 --grow
volgroup kegerator9 pv.1
logvol swap --vgname=kegerator9 --name=swap --size=8192
logvol / --vgname=kegerator9 --name=root --size=20480 --fstype=xfs
logvol /build --vgname=kegerator9 --name=build --size=20480 --fstype=xfs --grow

bootloader --append="rhgb quiet net.ifnames=0 biosdevname=0 crashkernel=auto" --driveorder="sda" --boot-drive=sda

# Reboot after installation
reboot

# Use graphical install
graphical

# Use network installation
#%ifarch x86_64
#url --url="http://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/"
#repo --name="AppStream" --baseurl=http://mirror.stream.centos.org/9-stream/AppStream/x86_64/os/
#repo --name="CRB" --baseurl=http://mirror.stream.centos.org/9-stream/CRB/x86_64/os/
#repo --name="epel" --baseurl=https://download.fedoraproject.org/pub/epel/9/Everything/x86_64/
#repo --name="ManageIQ-Build" --baseurl=https://copr-be.cloud.fedoraproject.org/results/manageiq/ManageIQ-Build/epel-9-x86_64/
#%endif

#%ifarch s390x
url --url="http://mirror.stream.centos.org/9-stream/BaseOS/s390x/os/"
repo --name="BaseOS" --baseurl=http://mirror.stream.centos.org/9-stream/BaseOS/s390x/os/
repo --name="AppStream" --baseurl=http://mirror.stream.centos.org/9-stream/AppStream/s390x/os/
repo --name="CRB" --baseurl=http://mirror.stream.centos.org/9-stream/CRB/s390x/os/
repo --name="HighAvailability" --baseurl=http://mirror.stream.centos.org/9-stream/HighAvailability/s390x/os/
repo --name="ResilientStorage" --baseurl=http://mirror.stream.centos.org/9-stream/ResilientStorage/s390x/os/
repo --name="epel" --baseurl=https://download.fedoraproject.org/pub/epel/9/Everything/s390x/
#repo --name="ManageIQ-Build" --baseurl=https://copr-be.cloud.fedoraproject.org/results/manageiq/ManageIQ-Build/epel-9-s390x/
repo --name="ManageIQ-Build" --baseurl=https://<%= ENV['ARTIFACTORY_USER'] %>:<%= ENV['ARTIFACTORY_TOKEN'] %>@na.artifactory.swg-devops.com/artifactory/hyc-bluecf-team-rpm-local/s390x/infrastructure-management-master-20250820231738/
#%endif


keyboard --vckeymap=us --xlayouts='us'

lang en_US.UTF-8

# Installation logging level
logging --level=debug

# Network information
network --bootproto=dhcp --device=eth1 --onboot=off --noipv6 --no-activate # CHANGEME or remove based on your hardware
network --bootproto=static --device=eth0 --gateway=192.0.2.1 --ip=192.0.2.2 --nameserver=192.0.2.1 --netmask=255.255.252.0 --noipv6 --activate # CHANGEME
network --hostname=kegerator9.example.com # CHANGEME

# Root password: smartvm
rootpw --iscrypted $1$DZprqvCu$mhqFBjfLTH/PVvZIompVP/

# SELinux configuration
selinux --enforcing

# X Window System configuration information
xconfig  --startxonboot
firstboot --disable
systemctl set-default graphical
sed -i 's/^#WaylandEnable.*/WaylandEnable=False/' /etc/gdm/custom.conf

# System services
services --enabled="chronyd"

# System timezone
timezone America/New_York --isUtc --ntpservers=time.nist.gov # CHANGEME if needed

%post --logfile=/root/anaconda-post.log

mkdir -p /build/fileshare /build/images /build/isos /build/logs /build/storage

pushd /build
  %ifarch x86_64
  git clone https://www.github.com/ManageIQ/manageiq-appliance-build.git
  ln -s manageiq-appliance-build/bin bin
  git clone https://www.github.com/redhat-imaging/imagefactory.git
  %endif
  %ifarch s390x
  git clone https://github.com/Chandrababu-nagilli/manageiq-appliance-build.git
  ln -s manageiq-appliance-build/bin bin
  git clone https://github.com/Chandrababu-nagilli/imagefactory.git
  %endif
popd

pip3 install oauth2 cherrypy boto monotonic

pushd /build/imagefactory/scripts
  sed -i 's/python2\.7/python3\.9/' imagefactory_dev_setup.sh
  ./imagefactory_dev_setup.sh
popd

pushd /build/manageiq-appliance-build/scripts
  gem install bundler
  export PATH="/usr/local/bin:${PATH}"
  bundle install
popd

echo "export LIBGUESTFS_BACKEND=direct" >> /root/.bash_profile

# Resulting build storage
mkdir /mnt/builds

chvt 1

%end

%packages
@development
@graphical-server-environment
epel-release

# For oz/imagefactory
oz
python3-pycurl
python3-libguestfs
python3-zope-interface
python3-libxml2
python3-httplib2
python3-libs
python3-m2crypto

# For KVM/Virt
@virtualization-hypervisor
@virtualization-client
libguestfs-tools

# Ruby
ruby
ruby-devel

# VNC
tigervnc
tigervnc-server
tigervnc-server-module

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end
