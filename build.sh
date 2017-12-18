#!/bin/bash
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
#  - CentOS 6: 6.8, 6.9
#  - CentOS 7: 7.2, 7.3, 7.4
#  - RHEL 7: 7.4
#  - Fedora: 25, 26
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
CH_VERSION="${CH_VERSION:-1.1.54318}"

# Git tag marker (stable/testing)
CH_TAG="${CH_TAG:-stable}"
#CH_TAG="${CH_TAG:-testing}"

# What sources are we going to compile - either download ready release file OR use 'git clone'
#USE_SOURCES_FROM="releasefile"
USE_SOURCES_FROM="git"

# Hostname of the server used to publish packages
SSH_REPO_SERVER="${SSH_REPO_SERVER:-10.81.1.162}"

# SSH username used to publish packages
SSH_REPO_USER="${SSH_REPO_USER:-clickhouse}"

# Root directory for repositories on the server used to publish packages
SSH_REPO_ROOT="${SSH_REPO_ROOT:-/var/www/html/repos/clickhouse}"

# Current work dir
CWD_DIR=$(pwd)

# Source files dir
SRC_DIR="$CWD_DIR/src"

# Where RPMs would be built
RPMBUILD_DIR="$CWD_DIR/rpmbuild"

# Where build RPM files would be kept
RPMS_DIR="$RPMBUILD_DIR/RPMS/x86_64"

# Where built SRPM files would be kept
SRPMS_DIR="$RPMBUILD_DIR/SRPMS"

# Where RPM spec file would be kept
SPECS_DIR="$RPMBUILD_DIR/SPECS"

# Where temp files would be kept
TMP_DIR="$RPMBUILD_DIR/TMP"

# Detect number of threads to run 'make' command
export THREADS=$(grep -c ^processor /proc/cpuinfo)

# Build most libraries using default GCC
export PATH=${PATH/"/usr/local/bin:"/}:/usr/local/bin

# Source libraries
. ./src/os.lib.sh
. ./src/publish_packagecloud.lib.sh
. ./src/publish_ssh.lib.sh

##
##
##
function install_general_dependencies()
{
	echo "####################################"
	echo "### Install general dependencies ###"
	echo "####################################"

	sudo yum install -y git wget curl zip unzip sed
}

##
##
##
function install_rpm_dependencies()
{
	echo "##############################"
        echo "### RPM build dependencies ###"
	echo "##############################"

	sudo yum install -y rpm-build redhat-rpm-config createrepo
}

##
##
##
function install_mysql_libs()
{
	echo "####################################"
	echo "### Install MySQL client library ###"
	echo "####################################"

	# which repo should be used
	# http://yum.mariadb.org/10.2/fedora26-amd64
	# http://yum.mariadb.org/10.2/centos6-amd64
	# http://yum.mariadb.org/10.2/centos7-amd64
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
}

##
##
##
function install_build_process_dependencies()
{
	echo "###########################"
	echo "### Install build tools ###"
	echo "###########################"

	sudo yum install -y m4 make

	if os_centos; then
		sudo yum install -y centos-release-scl
		sudo yum install -y devtoolset-7

		sudo yum install -y epel-release
		sudo yum install -y cmake3
	else
		sudo yum install gcc-c++ cmake
	fi

	echo "###################################"
	echo "### Install CH dev dependencies ###"
	echo "###################################"

	# libicu-devel -  ICU (support for collations and charset conversion functions
	# libtool-ltdl-devel - cooperate with dynamic libs
	sudo yum install -y zlib-devel openssl-devel libicu-devel libtool-ltdl-devel unixODBC-devel readline-devel
}

##
##
##
function install_workarounds()
{
	echo "###########################"
	echo "### Install workarounds ###"
	echo "###########################"

	if [ $DISTR_MAJOR == 7 ]; then
		# CH wants to see openssl .h files in /usr/local/opt/openssl/include (hardcoded inside?)
		# make it happy, so it puts it like the following in cmake3 output 
		# -- Using openssl=1: /usr/local/opt/openssl/include : /usr/lib64/libssl.so;/usr/lib64/libcrypto.so
		# create /usr/local/opt/openssl foler and put inside it a link to /usr/include/openssl called /usr/local/opt/openssl/include
		sudo mkdir -p /usr/local/opt/openssl
		sudo ln -s /usr/include/openssl /usr/local/opt/openssl/include
	fi
}

##
## Install all required components before building RPMs
##
function install_dependencies()
{
	echo "############################"
	echo "### Install dependencies ###"
	echo "############################"

	install_general_dependencies
	install_rpm_dependencies
	install_mysql_libs
	install_build_process_dependencies

	install_workarounds
}


##
## Install all required components before building RPMs
##
function install_dependencies_old()
{
	echo "############################"
	echo "### Install dependencies ###"
	echo "############################"
	
	echo "####################################"
	echo "### Install development packages ###"
	echo "####################################"

	DISTRO_PACKAGES=""
	if [ $DISTR_MAJOR == 6 ]; then
		DISTRO_PACKAGES="scons"
	fi

	if ! sudo yum -y install $DISTRO_PACKAGES \
		m4 rpm-build redhat-rpm-config createrepo \
		cmake make gcc-c++ \
		zip wget \
		subversion git \
		readline-devel glib2-devel unixODBC-devel \
		python-devel openssl-devel openssl-static libicu-devel \
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

	echo "###################"
	echo "### Install GCC ###"
	echo "###################"

	if [ $DISTR_MAJOR == 6 ] || [ $DISTR_MAJOR == 7 ]; then
		# CentOS 6/7
		# RHEL 6/7

		# Connect EPEL repository
		if yum list installed epel-release >/dev/null 2>&1; then
			echo "epel already installed"
		else
			if ! sudo yum -y --nogpgcheck install https://dl.fedoraproject.org/pub/epel/epel-release-latest-$DISTR_MAJOR.noarch.rpm; then
				echo "FAILED to install epel"
				exit 1
			fi
		fi

		if ! sudo yum -y install cmake3; then
			echo "FAILED to install cmake3"
			exit 1
		fi
	fi

	if [ $DISTR_MAJOR == 7 ]; then
		if ! sudo yum -y install scons; then
			echo "FAILED to install scons"
			exit 1
		fi
	fi


	if [ $DISTR_MAJOR == 6 ] || [ $DISTR_MAJOR == 7 ]; then
		# CentOS 6/7
		# RHEL 6/7
		# Install gcc 6 from compatibility packages

		# Enable Software Collections
		# https://www.softwarecollections.org/en/scls/rhscl/devtoolset-6/
		if os_centos; then
			sudo yum install -y centos-release-scl
		else
			# RHEL flavors

			# vanilla RHEL
			sudo yum-config-manager --enable rhel-server-rhscl-${DISR_MAJOR}-rpms

			# AWS-based RHEL
			sudo yum-config-manager --enable rhui-REGION-rhel-server-extras
			sudo yum-config-manager --enable rhui-REGION-rhel-server-optional
			sudo yum-config-manager --enable rhui-REGION-rhel-server-supplementary

			sudo yum-config-manager --enable rhui-REGION-rhel-server-rhscl
			sudo yum-config-manager --enable rhui-REGION-rhel-server-debug-rhscl
		fi

		# and install GCC6 provided by Software Collections
		sudo yum install -y devtoolset-6-gcc*

	elif [ $DISTR_MAJOR == 25 ] || [ $DISTR_MAJOR == 26 ]; then
		# Fedora 25 already has gcc 6, no need to install
		# Fedora 26 already has gcc 7, no need to install
		# Install static libs
		sudo yum install -y libstdc++-static
	fi

	echo "####################################"
	echo "### Install MySQL client library ###"
	echo "####################################"

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
}

##
##
##
function build_dependencies()
{
	echo "##########################"
	echo "### Build dependencies ###"
	echo "##########################"
	
	if [[ $EUID -ne 0 ]]; then
		echo "You must be a root user" 2>&1
		exit 1
	fi

	if [ ! -d dependencies ]; then
		mkdir dependencies
	fi

	rm -rf dependencies/*

	cd dependencies

	echo "####################################"
	echo "### Install development packages ###"
	echo "####################################"

	# Build process support requirements
	yum -y install rpm-build redhat-rpm-config gcc-c++ \
		subversion python-devel git wget m4 createrepo

	# CH dependencies

	# libicu-devel -  ICU (support for collations and charset conversion functions
	# libtool-ltdl-devel - cooperate with dynamic libs
	yum -y zlib-devel openssl-devel libicu-devel libtool-ltdl-devel unixODBC-devel readline-devel

	echo "####################################"
	echo "### Install MySQL client library ###"
	echo "####################################"

	if ! rpm --query mysql57-community-release; then
		yum -y --nogpgcheck install http://dev.mysql.com/get/mysql57-community-release-el${DISTR_MAJOR}-9.noarch.rpm
	fi

	yum -y install mysql-community-devel
	if [ ! -e /usr/lib64/libmysqlclient.a ]; then
		ln -s /usr/lib64/mysql/libmysqlclient.a /usr/lib64/libmysqlclient.a
	fi

	echo "###################"
	echo "### Build cmake ###"
	echo "###################"

	wget https://cmake.org/files/v3.9/cmake-3.9.3.tar.gz
	tar xf cmake-3.9.3.tar.gz
	cd cmake-3.9.3
	./configure
	make -j $THREADS
	make install
	cd ..

	echo "###################"
	echo "### Build GCC 7 ###"
	echo "###################"

	wget http://mirror.linux-ia64.org/gnu/gcc/releases/gcc-7.2.0/gcc-7.2.0.tar.gz
	tar xf gcc-7.2.0.tar.gz
	cd gcc-7.2.0
	./contrib/download_prerequisites
	cd ..
	mkdir gcc-build
	cd gcc-build
	../gcc-7.2.0/configure --enable-languages=c,c++ --enable-linker-build-id --with-default-libstdcxx-abi=gcc4-compatible --disable-multilib
	make -j $THREADS
	make install
	hash gcc g++
	gcc --version
	ln -f -s /usr/local/bin/gcc /usr/local/bin/gcc-7
	ln -f -s /usr/local/bin/g++ /usr/local/bin/g++-7
	ln -f -s /usr/local/bin/gcc /usr/local/bin/cc
	ln -f -s /usr/local/bin/g++ /usr/local/bin/c++
	cd ..

	# Use GCC 7 for builds
	export CC=gcc-7
	export CXX=g++-7

	# Install Boost
	wget http://downloads.sourceforge.net/project/boost/boost/1.65.1/boost_1_65_1.tar.bz2
	tar xf boost_1_65_1.tar.bz2
	cd boost_1_65_1
	./bootstrap.sh
	./b2 --toolset=gcc-7 -j $THREADS
	PATH=$PATH ./b2 install --toolset=gcc-7 -j $THREADS
	cd ..

	# Clang requires Python27
	rpm -ivh http://dl.iuscommunity.org/pub/ius/stable/Redhat/6/x86_64/epel-release-6-5.noarch.rpm
	rpm -ivh http://dl.iuscommunity.org/pub/ius/stable/Redhat/6/x86_64/ius-release-1.0-14.ius.el6.noarch.rpm
	yum clean all
	yum install python27

	echo "###################"
	echo "### Build Clang ###"
	echo "###################"

	mkdir llvm
	cd llvm
	svn co http://llvm.org/svn/llvm-project/llvm/tags/RELEASE_500/final llvm
	cd llvm/tools
	svn co http://llvm.org/svn/llvm-project/cfe/tags/RELEASE_500/final clang
	cd ../projects/
	svn co http://llvm.org/svn/llvm-project/compiler-rt/tags/RELEASE_500/final compiler-rt
	cd ../..
	mkdir build
	cd build/
	cmake -D CMAKE_BUILD_TYPE:STRING=Release ../llvm -DCMAKE_CXX_LINK_FLAGS="-Wl,-rpath,/usr/local/lib64 -L/usr/local/lib64"
	make -j $THREADS
	make install
	hash clang
	cd ../../..
}

##
##
##
function list_RPMs()
{
	echo "######################################################"
	echo "### Looking for RPMs at                            ###"
	echo "### $RPMS_DIR/clickhouse*.rpm                      ###"
	echo "######################################################"

	ls -l "$RPMS_DIR"/clickhouse*.rpm

	echo "######################################################"
}

##
##
##
function list_SRPMs()
{
	echo "######################################################"
	echo "### Looking for sRPMs at                           ###"
	echo "### $SRPMS_DIR/clickhouse*                         ###"
	echo "######################################################"

	ls -l "$SRPMS_DIR"/clickhouse*

	echo "######################################################"
}


##
## Prepare $RPMBUILD_DIR/SOURCES/ClickHouse-$CH_VERSION-$CH_TAG.zip file
##
function prepare_sources()
{
	if [ "$USE_SOURCES_FROM" == "releasefile" ]; then
		echo "Downloading ClickHouse source archive v$CH_VERSION-$CH_TAG.zip"
		wget --progress=dot:giga "https://github.com/yandex/ClickHouse/archive/v$CH_VERSION-$CH_TAG.zip" --output-document="$RPMBUILD_DIR/SOURCES/ClickHouse-$CH_VERSION-$CH_TAG.zip"

	elif [ "$USE_SOURCES_FROM" == "git" ]; then
		echo "Cloning from github v$CH_VERSION-$CH_TAG into $RPMBUILD_DIR/SOURCES/ClickHouse-$CH_VERSION-$CH_TAG"
		echo "cd into $RPMBUILD_DIR/SOURCES"

		cd "$RPMBUILD_DIR/SOURCES"

		# Clone specified branch with all submodules into $RPMBUILD_DIR/SOURCES/ClickHouse-$CH_VERSION-$CH_TAG folder
		git clone --branch "v$CH_VERSION-$CH_TAG" --depth 1 --recursive "https://github.com/yandex/ClickHouse" "ClickHouse-$CH_VERSION-$CH_TAG"
		# older versions of git do not understand --single-branch option
		#git clone --branch "v$CH_VERSION-$CH_TAG" --single-branch --depth 1 --recursive "https://github.com/yandex/ClickHouse" "ClickHouse-$CH_VERSION-$CH_TAG"

		# Move files into .zip with minimal compression
		zip -r0mq "ClickHouse-$CH_VERSION-$CH_TAG.zip" "ClickHouse-$CH_VERSION-$CH_TAG"

		echo "Ensure .zip file is available"
		ls -l "ClickHouse-$CH_VERSION-$CH_TAG.zip"

		cd "$CWD_DIR"

	else
		echo "Unknows sources"
		exit 1
	fi
}

##
##
##
function build_spec_file()
{
	mkdir -p "$SPECS_DIR"

	# Create spec file from template
	cat "$SRC_DIR/clickhouse.spec.in" | sed \
		-e "s|@CH_VERSION@|$CH_VERSION|" \
		-e "s|@CH_TAG@|$CH_TAG|" \
		-e "/@CLICKHOUSE_SPEC_FUNCS_SH@/ { 
r $SRC_DIR/clickhouse.spec.funcs.sh
d }" \
		> "$SPECS_DIR/clickhouse.spec"
}


##
## Build RPMs
##
function build_RPMs()
{
	echo "########################"
	echo "### Setup RPM Macros ###"
	echo "########################"

	echo '%_topdir '"$RPMBUILD_DIR"'
%_tmppath '"$TMP_DIR"'
%_smp_mflags  -j'"$THREADS" > ~/.rpmmacros

	echo "###############################"
	echo "### Setup path to compilers ###"
	echo "###############################"

	if os_centos; then
		export CMAKE=cmake3
		export CC=/opt/rh/devtoolset-7/root/usr/bin/gcc
		export CXX=/opt/rh/devtoolset-7/root/usr/bin/g++
	else
		export CMAKE=cmake
		export CC=gcc
		export CXX=g++
	fi

	echo "CMAKE=$CMAKE"
	echo "CC=$CC"
	echo "CXX=$CXX"

	echo "cd into $CWD_DIR"
	cd "$CWD_DIR"

	echo "##################"
	echo "### Build RPMs ###"
	echo "##################"

	echo "rpmbuild $CH_VERSION-$CH_TAG"
	rpmbuild -bs "$SPECS_DIR/clickhouse.spec"
	rpmbuild -bb "$SPECS_DIR/clickhouse.spec"
	echo "rpmbuild completed $CH_VERSION-$CH_TAG"
}

##
## Build packages:
## 1. clean folders
## 2. prepare sources
## 3. build spec file
## 4. build RPMs
##
function build_packages()
{

	echo "Prepare dirs"
	mkdir -p "$RPMBUILD_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

	echo "Clean up after previous run"
	rm -f "$RPMS_DIR"/clickhouse*
	rm -f "$SRPMS_DIR"/clickhouse*
	rm -f "$SPECS_DIR"/clickhouse.spec

	echo "###########################"
	echo "### Create RPM packages ###"
	echo "###########################"
	
	# Prepare $RPMBUILD_DIR/SOURCES/ClickHouse-$CH_VERSION-$CH_TAG.zip file
	prepare_sources

	# Build $SPECS_DIR/clickhouse.spec file
	build_spec_file
 
	# Compile sources and build RPMS
	build_RPMs

	# Display results
	list_RPMs
	list_SRPMs
}

##
##
##
function usage()
{
	echo "Usage:"
	echo "./build.sh all          - most popular point of entry - the same as idep_all"
	echo ""
	echo "./build.sh idep_all     - install dependencies from RPMs, download CH sources and build RPMs"
	echo "./build.sh bdep_all     - build dependencies from sources, download CH sources and build RPMs !!! YOU MAY NEED TO UNDERSTAND INTERNALS !!!"
	echo ""
	echo "./build.sh install_deps - just install dependencies (do not download sources, do not build RPMs)"
	echo "./build.sh build_deps   - just build dependencies (do not download sources, do not build RPMs)"
	echo "./build.sh spec         - just create SPEC file (do not download sources, do not build RPMs)"
	echo "./build.sh spec_rpms    - download sources, create SPEC file and build RPMs (do not install dependencies)"
	echo "./build.sh rpms         - just build RPMs (do not download sources, do not create SPEC file, do not install dependencies)"
	echo ""
	echo "./build.sh publish packagecloud <packagecloud USER ID> - publish packages on packagecloud as USER"
	echo "./build.sh delete packagecloud <packagecloud USER ID>  - delete packages on packagecloud as USER"
	echo ""
	echo "./build.sh publish ssh - publish packages via SSH"
	
	exit 0
}


os_detect

if ! os_rpm_based; then
	echo "We need RPM-based OS in order to build RPM packages."
	exit 1
else
	echo "RPM-based OS detected, continue"
fi

if [ -z "$1" ]; then
	usage
fi

COMMAND="$1"

if [ "$COMMAND" == "all" ]; then
	install_dependencies
	build_packages

elif [ "$COMMAND" == "idep_all" ]; then
	install_dependencies
	build_packages

elif [ "$COMMAND" == "bdep_all" ]; then
	build_dependencies
	build_packages

elif [ "$COMMAND" == "install_deps" ]; then
	install_dependencies

elif [ "$COMMAND" == "build_deps" ]; then
	build_dependencies

elif [ "$COMMAND" == "spec" ]; then
	build_spec_file

elif [ "$COMMAND" == "spec_rpms" ]; then
	build_packages

elif [ "$COMMAND" == "rpms" ]; then
	build_RPMs

elif [ "$COMMAND" == "publish" ]; then
	PUBLISH_TARGET="$2"
	if [ "$PUBLISH_TARGET" == "packagecloud" ]; then
		# run publish script with all the rest of CLI params
		publish_packagecloud ${*:3}

	elif [ "$PUBLISH_TARGET" == "ssh" ]; then
		publish_ssh

	else
		echo "Unknown publish target"
		usage
	fi

elif [ "$COMMAND" == "delete" ]; then
	PUBLISH_TARGET="$2"
	if [ "$PUBLISH_TARGET" == "packagecloud" ]; then
		# run publish script with all the rest of CLI params
		publish_packagecloud_delete ${*:3}

	elif [ "$PUBLISH_TARGET" == "ssh" ]; then
		echo "Not supported yet"
	else
		echo "Unknown publish target"
		usage
	fi

else
	# unknown command
	echo "Unknown command: $COMMAND"
	usage
fi

