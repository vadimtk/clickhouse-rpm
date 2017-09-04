#
# Yandex ClickHouse DBMS build script for RHEL based distributions
#
# Important notes:
#  - build requires ~35 GB of disk space
#  - each build thread requires 2 GB of RAM - for example, if you
#    have dual-core CPU with 4 threads you need 8 GB of RAM
#  - build user needs to have sudo priviledges, preferrably with NOPASSWD
#
# Tested on:
#  - CentOS 6.8
#  - CentOS 6.9
#  - CentOS 7.2
#  - CentOS 7.3
#  - Fedora 25
#
# Copyright (C) 2016 Red Soft LLC
# Copyright (C) 2017 Altinity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Git version of ClickHouse that we package
CH_VERSION="1.1.54284"

# Git tag marker (stable/testing)
#CH_TAG="stable"
CH_TAG="testing"

# Current work dir
CWD_DIR=`pwd`

# Where runtime data would be kept
RUNTIME_DIR="$CWD_DIR/runtime"

# Where additional packages would be kept
LIB_DIR="$RUNTIME_DIR/lib"

# Where RPMs would be built
RPMBUILD_DIR="$RUNTIME_DIR/rpmbuild"

# Where RPM spec file would be kept
RPMSPEC_DIR="$RUNTIME_DIR/rpmspec"

# Detect number of threads
export THREADS=$(grep -c ^processor /proc/cpuinfo)

# Build most libraries using default GCC
export PATH=${PATH/"/usr/local/bin:"/}:/usr/local/bin


##
## Print error message and exit with exit code 1
##
function os_unsupported()
{
	echo "This OS is not supported. However, you can set 'OS' and 'DISTR' ENV vars manually."
	echo "Can't continue, exit"

	exit 1
}

##
## is OS YUM-based?
##
function os_yum_based()
{
	[ "$OS" == "centos" ] || [ "$OS" == "fedora" ]
}

##
## is OS APT-based?
##
function os_apt_based()
{
	[ "$OS" == "ubuntu" ] || [ "$OS" == "linuxmint" ]
}

##
## is OS RPM-based?
##
function os_rpm_based()
{
	os_yum_based
}

##
## Detect OS. Results are written into
## $OS - string lowercased codename ex: centos, linuxmint
## $DISTR_MAJOR - int major version ex: 7 for CentOS 7.3, 18 for Linux Mint 18
## $DISTR_MINOR - int minor version ex: 3 for centos 7.3, Empty "" for Linux Mint 18
##
function os_detect()
{
	if [ -n "$OS" ] && [ -n "$DISTR_MAJOR" ]; then
		# looks like all is explicitly set
		echo "OS specified: $OS $DISTR_MAJOR $DISTR_MINOR"
		return
	fi

	# OS or DIST are NOT specified
	# let's try to figure out what exactly are we running on

	if [ -e /etc/os-release ]; then
		# nice, can simply source OS specification
		. /etc/os-release
			
		# OS=linuxmint
		OS=${ID}

		# need to parse "18.2"
		# DISTR_MAJOR=18
		# DISTR_MINOR=2
		DISTR_MAJOR=`echo ${VERSION_ID} | awk -F '.' '{ print $1 }'`
		DISTR_MINOR=`echo ${VERSION_ID} | awk -F '.' '{ print $2 }'`

	elif command -v lsb_release > /dev/null; then
		# something like Ubuntu

		# need to parse "Distributor ID:	LinuxMint"
		# OS=linuxmint
		OS=`lsb_release -i | cut -f2 | awk '{ print tolower($1) }'`

		# need to parse "Release:	18.2"
		# DISTR_MAJOR=18
		# DISTR_MINOR=2
		DISTR_MAJOR=`lsb_release -r | cut -f2 | awk -F '.' '{ print $1 }'`
		DISTR_MINOR=`lsb_release -r | cut -f2 | awk -F '.' '{ print $2 }'`

	elif [ -e /etc/centos-release ]; then
		OS='centos'

		# need to parse "CentOS release 6.9 (Final)"
		# DISTR_MAJOR=6
		# DISTR_MINOR=9
       		DISTR_MAJOR=`cat /etc/centos-release | awk '{ print $3 }' | awk -F '.' '{ print $1 }'`
       		DISTR_MINOR=`cat /etc/centos-release | awk '{ print $3 }' | awk -F '.' '{ print $2 }'`

	elif [ -e /etc/fedora-release ]; then
		OS='fedora'

		# need to parse "Fedora release 26 (Twenty Six)"
		# DISTR_MAJOR=26
		# DISTR_MINOR=""
		DISTR_MAJOR=`cut -f3 --delimiter=' ' /etc/fedora-release`
		DISTR_MINOR=""

	elif [ -e /etc/redhat-release ]; then
		# need to parse "CentOS Linux release 7.3.1611 (Core)"
		# OS=centos
		OS=`cat /etc/redhat-release  | awk '{ print tolower($1) }'`

		# need to parse "CentOS Linux release 7.3.1611 (Core)"
		# DISTR_MAJOR=7
		# DISTR_MINOR=3
       		DISTR_MAJOR=`cat /etc/redhat-release | awk '{ print $4 }' | awk -F '.' '{ print $1 }'`
       		DISTR_MINOR=`cat /etc/redhat-release | awk '{ print $4 }' | awk -F '.' '{ print $2 }'`

	else
		# do not know this OS
		os_unsupported
	fi

	echo "OS detected: $OS $DISTR_MAJOR $DISTR_MINOR"
}


##
## Install all required components before building RPMs
##
function install_dependencies()
{
	echo "#############################"
	echo "### Install dependencies  ###"
	echo "#############################"
	
	echo "Prepare lib dir: $LIB_DIR"

	if [ ! -d "$LIB_DIR" ]; then
		echo "Make lib dir: $LIB_DIR"
		mkdir -p "$LIB_DIR"
	fi

	echo "Clean lib dir: $LIB_DIR"
	rm -rf "$LIB_DIR/"*

	echo "cd into $LIB_DIR"
	cd "$LIB_DIR"

	echo "####################################"
	echo "### Install development packages ###"
	echo "####################################"

	DISTRO_PACKAGES=""
	if [ $DISTR_MAJOR == 6 ]; then
		DISTRO_PACKAGES="scons"
	fi

	if ! sudo yum -y install $DISTRO_PACKAGES \
		m4 rpm-build redhat-rpm-config createrepo \
		make gcc-c++ \
		wget \
		subversion git \
		readline-devel glib2-devel unixODBC-devel \
		python-devel openssl-devel libicu-devel \
		zlib-devel libtool-ltdl-devel xz-devel
	then 
		echo "FAILED to install development packages"
		exit 1
	fi

	echo "##########################"
	echo "### Install Python 2.7 ###"
	echo "##########################"

	# select Python package for installation
	PYTHON_PACKAGE="python"
	if [ $DISTR_MAJOR == 25 ] || [ $DISTR_MAJOR == 26 ]; then
		PYTHON_PACKAGE="python2"
	elif [ $DISTR_MAJOR == 6 ]; then
		PYTHON_PACKAGE="python27"
	fi
	# and install Python
	sudo yum install -y $PYTHON_PACKAGE

	if [ $DISTR_MAJOR == 7 ]; then
		# Connect EPEL repository for CentOS 7 (for scons)
		wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
		sudo yum -y --nogpgcheck install epel-release-latest-7.noarch.rpm
		if ! sudo yum -y install scons; then
			echo "FAILED to install scons"
			exit 1; 
		fi
	fi

	echo "#####################"
	echo "### Install GCC 6 ###"
	echo "#####################"

	export CC=gcc
	export CXX=g++

	if [ $DISTR_MAJOR == 6 ] || [ $DISTR_MAJOR == 7 ]; then
		# CentOS 6/7
		# Install gcc 6 from compatibility packages
		sudo yum install -y centos-release-scl
		sudo yum install -y devtoolset-6-gcc*
		export CC=/opt/rh/devtoolset-6/root/usr/bin/gcc
		export CXX=/opt/rh/devtoolset-6/root/usr/bin/g++

	elif [ $DISTR_MAJOR == 25 ] || [ $DISTR_MAJOR == 26 ]; then
		# Fedora 25 already has gcc 6, no need to install
		# Fedora 26 already has gcc 7, no need to install
		# Install static libs
		sudo yum install -y libstdc++-static
	fi

	echo "#################################################"
	echo "### Install MySQL client library from MariaDB ###"
	echo "#################################################"

	# which repo should be used
	# http://yum.mariadb.org/10.2/fedora26-amd64"
	# http://yum.mariadb.org/10.2/centos6-amd64"
	# http://yum.mariadb.org/10.2/centos7-amd64"
	MARIADB_REPO_URL="http://yum.mariadb.org/10.2/${OS}${DISTR_MAJOR}-amd64"

	# create repo file
	sudo bash -c "cat << EOF > /etc/yum.repos.d/mariadb.repo
[mariadb]
name=MariaDB
baseurl=${MARIADB_REPO_URL}
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF"

	sudo yum install -y MariaDB-devel MariaDB-shared

	echo "#####################"
	echo "### Install cmake ###"
	echo "#####################"

	sudo yum install -y cmake
	#scl enable devtoolset-6 bash

	echo "Return back to dir: $CWD_DIR"
	cd $CWD_DIR
}

function list_RPMs()
{
	echo "######################################################"
	echo "### Looking for RPMs at                            ###"
	echo "### $RPMBUILD_DIR/RPMS/x86_64/clickhouse*"
	echo "######################################################"

	ls -l "$RPMBUILD_DIR"/RPMS/x86_64/clickhouse*

	echo "######################################################"
}

function list_SRPMs()
{
	echo "######################################################"
	echo "### Looking for sRPMs at                           ###"
	echo "### $RPMBUILD_DIR/SRPMS/x86_64/clickhouse*"
	echo "######################################################"

	ls -l "$RPMBUILD_DIR"/SRPMS/x86_64/clickhouse*

	echo "######################################################"
}

##
## Build RPMs
##
function build_packages()
{

	echo "Prepare dirs"
	mkdir -p "$RPMBUILD_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
	mkdir -p "$RPMSPEC_DIR"

	echo "Clean up after previous run"
	rm -f "$RPMBUILD_DIR"/RPMS/x86_64/clickhouse*
	rm -f "$RPMBUILD_DIR"/SRPMS/clickhouse*
	rm -f "$RPMSPEC_DIR"/*.zip

	echo "Configure RPM build environment"
	echo '%_topdir '"$RPMBUILD_DIR"'
%_smp_mflags  -j'"$THREADS" > ~/.rpmmacros

	echo "###########################"
	echo "### Create RPM packages ###"
	echo "###########################"
	cd "$RPMSPEC_DIR"
	
	# Create spec file from template
	sed -e "s/@CH_VERSION@/$CH_VERSION/" -e "s/@CH_TAG@/$CH_TAG/" "$CWD_DIR/rpm/clickhouse.spec.in" > clickhouse.spec

	# Download ClickHouse source archive
	wget --progress=dot:giga "https://github.com/yandex/ClickHouse/archive/v$CH_VERSION-$CH_TAG.zip" --output-document="$RPMBUILD_DIR/SOURCES/ClickHouse-$CH_VERSION-$CH_TAG.zip"

	# Build RPMs
	echo "rpmbuild v$CH_VERSION-$CH_TAG"
	rpmbuild -bs clickhouse.spec
	rpmbuild -bb clickhouse.spec
	echo "rpmbuild completed v$CH_VERSION-$CH_TAG"

	# Display results
	list_RPMs
	list_SRPMs
}

function publish_packages {
  mkdir /tmp/clickhouse-repo
  rm -rf /tmp/clickhouse-repo/*
  cp $RPMBUILD_DIR/RPMS/x86_64/clickhouse*.rpm /tmp/clickhouse-repo
  if ! createrepo /tmp/clickhouse-repo; then exit 1; fi

  if ! scp -B -r /tmp/clickhouse-repo $REPO_USER@$REPO_SERVER:/tmp/clickhouse-repo; then exit 1; fi
  if ! ssh $REPO_USER@$REPO_SERVER "rm -rf $REPO_ROOT/$CH_TAG/el$DISTR_MAJOR && mv /tmp/clickhouse-repo $REPO_ROOT/$CH_TAG/el$DISTR_MAJOR"; then exit 1; fi
}

os_detect

if ! os_rpm_based; then
	echo "We need RPM-based OS in order to build RPM packages."
	exit 1
else
	echo "RPM-based OS detected, continue"
fi

if [[ "$1" != "publish_only"  && "$1" != "build_only" ]]; then
  install_dependencies
fi
if [ "$1" != "publish_only" ]; then
  build_packages
fi
if [ "$1" == "publish_only" ]; then
  publish_packages
fi

