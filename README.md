# clickhouse-rpm
ClickHouse DBMS build script for RHEL based distributions

Run build_packages.sh on any RHEL 6 or RHEL 7 based distribution and it shall produce ClickHouse source and binary RPM packages for your system.



# CH
cmake3 .. -DCMAKE_CXX_COMPILER=/opt/rh/devtoolset-6/root/usr/bin/g++ -DCMAKE_C_COMPILER=/opt/rh/devtoolset-6/root/usr/bin/gcc -DOPENSSL_ROOT_DIR=/opt/openssl-1.1.0f

# MariaDB libmysqlclient
sources: https://downloads.mariadb.org/mariadb/10.2.10/
build instaructions: https://mariadb.com/kb/en/library/source-building-mariadb-on-centos/
mkdir build
cd build
cmake3 .. -DBUILD_CONFIG=mysql_release -DRPM=centos7 -DCMAKE_CXX_COMPILER=/opt/rh/devtoolset-6/root/usr/bin/g++ -DCMAKE_C_COMPILER=/opt/rh/devtoolset-6/root/usr/bin/gcc -DOPENSSL_ROOT_DIR=/opt/openssl-1.1.0f
make package

MariaDB-common* MariaDB-compat* MariaDB-devel* MariaDB-shared*


Installed Packages
MariaDB-common.x86_64                                                                                           10.2.10-1.el7.centos                                                                                           installed
MariaDB-devel.x86_64                                                                                            10.2.10-1.el7.centos                                                                                           installed
MariaDB-shared.x86_64                                                                                           10.2.10-1.el7.centos                                                                                           installed
[user@localhost clickhouse-rpm]$ 
Installed Packages
openssl.x86_64                                                                                                  1:1.0.2k-8.el7                                                                                      @anaconda           
openssl-altinity.x86_64                                                                                         1:1.1.0f-7.el7.centos                                                                               @altinity_clickhouse
openssl-altinity-debuginfo.x86_64                                                                               1:1.1.0f-7.el7.centos                                                                               @altinity_clickhouse
openssl-altinity-devel.x86_64                                                                                   1:1.1.0f-7.el7.centos                                                                               @altinity_clickhouse
openssl-altinity-libs.x86_64                                                                                    1:1.1.0f-7.el7.centos                                                                               @altinity_clickhouse
openssl-altinity-perl.x86_64                                                                                    1:1.1.0f-7.el7.centos                                                                               @altinity_clickhouse
openssl-altinity-static.x86_64                                                                                  1:1.1.0f-7.el7.centos                                                                               @altinity_clickhouse
openssl-libs.x86_64                                                                                             1:1.0.2k-8.el7       

All packages are available here: https://packagecloud.io/altinity/clickhouse

