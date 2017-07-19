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
#  - CentOS 7.2
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
CH_VERSION="1.1.54245"

# Git tag marker (stable/testing)
CH_TAG="stable"

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

# Determine RHEL major version
RHEL_VERSION=`rpm -qa --queryformat '%{VERSION}\n' '(redhat|sl|slf|centos|oraclelinux|goslinux)-release(|-server|-workstation|-client|-computenode)'`

# Check whether we build for fedora
if [ -e "/etc/fedora-release" ]; then
	# Extract numbers from fedora-relase string, which is: "Fedora release 26 (Twenty Six)"
	RHEL_VERSION=`cat /etc/fedora-release|sed 's/[^0-9]*//g'`
fi


function prepare_dependencies {

	if [ ! -d "$LIB_DIR" ]; then
		echo "Make lib dir: $LIB_DIR"
		mkdir -p "$LIB_DIR"
	fi

	echo "Clean lib dir: $LIB_DIR"
	rm -rf "$LIB_DIR/"*

	echo "cd into $LIB_DIR"
	cd "$LIB_DIR"

	#
	# Install development packages
	#

	if [ $RHEL_VERSION == 6 ]; then
		DISTRO_PACKAGES="scons"
	fi

	if [ $RHEL_VERSION == 7 ]; then
		DISTRO_PACKAGES=""
	fi

	if ! sudo yum -y install $DISTRO_PACKAGES \
		make rpm-build redhat-rpm-config gcc-c++ readline-devel \
		unixODBC-devel subversion python-devel git wget openssl-devel \
		m4 createrepo glib2-devel \
		libicu-devel zlib-devel libtool-ltdl-devel openssl-devel xz-devel
	then 
		echo "FAILED to install development packages"
		exit 1
	fi

	#
	# Install Python 2.7
	#

	if [ $RHEL_VERSION == 25 ] || [ $RHEL_VERSION == 26 ]; then
		sudo yum install -y python2
	else
		sudo yum install -y python27
	fi

	if [ $RHEL_VERSION == 7 ]; then
		# Connect EPEL repository for CentOS 7 (for scons)
		wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
		sudo yum -y --nogpgcheck install epel-release-latest-7.noarch.rpm
		if ! sudo yum -y install scons; then
			echo "FAILED to install scons"
			exit 1; 
		fi
	fi

	#
	# Install GCC 6
	# Fedora 25 already has gcc 6, no need to install
	#

	export CC=gcc
	export CXX=g++

	if [ $RHEL_VERSION == 6 ] || [ $RHEL_VERSION == 7 ]; then
		# CentOS 6/7
		# Install gcc 6 from compatibility packages
		sudo yum install -y centos-release-scl
		sudo yum install -y devtoolset-6-gcc*
		export CC=/opt/rh/devtoolset-6/root/usr/bin/gcc
		export CXX=/opt/rh/devtoolset-6/root/usr/bin/g++

	elif [ $RHEL_VERSION == 26 ]; then
		# FC26

		# Download gcc from https://gcc.gnu.org/mirrors.html
		wget ftp://ftp.fu-berlin.de/unix/languages/gcc/releases/gcc-6.2.0/gcc-6.2.0.tar.bz2
		tar xf gcc-6.2.0.tar.bz2

		cd gcc-6.2.0
		./contrib/download_prerequisites
		cd ..

		mkdir gcc-build
		cd gcc-build
		../gcc-6.2.0/configure --enable-languages=c,c++ --disable-multilib --enable-linker-build-id --with-default-libstdcxx-abi=gcc4-compatible
		make -j $THREADS
		sudo make install

		# /usr/local/bin/ should be in $PATH
		hash gcc g++
		gcc --version

		sudo ln -s /usr/local/bin/gcc /usr/local/bin/gcc-6
		sudo ln -s /usr/local/bin/g++ /usr/local/bin/g++-6
		sudo ln -s /usr/local/bin/gcc /usr/local/bin/cc
		sudo ln -s /usr/local/bin/g++ /usr/local/bin/c++
		export CC=/usr/local/bin/gcc-6
		export CXX=/usr/local/bin/g++-6

	else
		# RH, FC
		# Install static libs
		sudo yum install -y libstdc++-static
	fi

	#
	# Install MySQL client library from MariaDB
	#

	if [ $RHEL_VERSION == 6 ] || [ $RHEL_VERSION == 7 ]; then
		# CentOS 6/7
		sudo bash -c "cat << EOF > /etc/yum.repos.d/mariadb.repo
[mariadb]
name=MariaDB
baseurl=http://yum.mariadb.org/5.5/centos${RHEL_VERSION}-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF"
	else
		# RH, FC
		sudo bash -c "cat << EOF > /etc/yum.repos.d/mariadb.repo
[mariadb]
name=MariaDB
baseurl=http://yum.mariadb.org/10.1/fedora25-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF"
	fi

	sudo yum -y install MariaDB-devel
	sudo ln -s /usr/lib64/mysql/libmysqlclient.a /usr/lib64/libmysqlclient.a

	#
	# Install cmake
	#

	sudo yum install -y cmake
	#scl enable devtoolset-6 bash

	echo "Return back to dir: $CWD_DIR"
	cd $CWD_DIR
}

function make_packages {

	# Prepare dirs
	mkdir -p "$RPMBUILD_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
	mkdir -p "$RPMSPEC_DIR"

	# Clean up after previous run
	rm -f "$RPMBUILD_DIR"/RPMS/x86_64/clickhouse*
	rm -f "$RPMBUILD_DIR"/SRPMS/clickhouse*
	rm -f "$RPMSPEC_DIR"/*.zip

	# Configure RPM build environment
	echo '%_topdir '"$RPMBUILD_DIR"'
%_smp_mflags  -j'"$THREADS" > ~/.rpmmacros

	# Create RPM packages
	cd "$RPMSPEC_DIR"
	
	# Create spec file from template
	sed -e "s/@CH_VERSION@/$CH_VERSION/" -e "s/@CH_TAG@/$CH_TAG/" "$CWD_DIR/rpm/clickhouse.spec.in" > clickhouse.spec

	# Prepase ClickHouse source archive
	wget "https://github.com/yandex/ClickHouse/archive/v$CH_VERSION-$CH_TAG.zip"
	mv "v$CH_VERSION-$CH_TAG.zip" "ClickHouse-$CH_VERSION-$CH_TAG.zip"
	cp *.zip "$RPMBUILD_DIR/SOURCES"

	# build RPM
	rpmbuild -bs clickhouse.spec
	if [ $RHEL_VERSION == 6 ] || [ $RHEL_VERSION == 7 ]; then
		# CentOS 6/7
		CC=/opt/rh/devtoolset-6/root/usr/bin/gcc CXX=/opt/rh/devtoolset-6/root/usr/bin/g++ rpmbuild -bb clickhouse.spec
	elif [ $RHEL_VERSION == 26 ]; then
		# FC26
		CC=/usr/local/bin/gcc-6 CXX=/usr/local/bin/g++-6 rpmbuild -bb clickhouse.spec
	else
		rpmbuild -bb clickhouse.spec
	fi

	echo "######################################################"
	echo "######################################################"
	echo "######################################################"
	echo "######################################################"
	echo "Looking for RPMs at"
	echo "$RPMBUILD_DIR/RPMS/x86_64/"

	ls -l "$RPMBUILD_DIR"/RPMS/x86_64/clickhouse*

	echo "######################################################"
	echo "Done for version v$CH_VERSION-$CH_TAG"
}

function publish_packages {
  mkdir /tmp/clickhouse-repo
  rm -rf /tmp/clickhouse-repo/*
  cp $RPMBUILD_DIR/RPMS/x86_64/clickhouse*.rpm /tmp/clickhouse-repo
  if ! createrepo /tmp/clickhouse-repo; then exit 1; fi

  if ! scp -B -r /tmp/clickhouse-repo $REPO_USER@$REPO_SERVER:/tmp/clickhouse-repo; then exit 1; fi
  if ! ssh $REPO_USER@$REPO_SERVER "rm -rf $REPO_ROOT/$CH_TAG/el$RHEL_VERSION && mv /tmp/clickhouse-repo $REPO_ROOT/$CH_TAG/el$RHEL_VERSION"; then exit 1; fi
}

if [[ "$1" != "publish_only"  && "$1" != "build_only" ]]; then
  prepare_dependencies
fi
if [ "$1" != "publish_only" ]; then
  make_packages
fi
if [ "$1" == "publish_only" ]; then
  publish_packages
fi

