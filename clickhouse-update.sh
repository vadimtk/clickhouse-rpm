#!/bin/bash

# settings
TARGET_VERSION="${TARGET_VERSION:-18.14.15}"

CH_PACKAGES="clickhouse-common-static clickhouse-server-common clickhouse-server clickhouse-client clickhouse-test clickhouse-debuginfo"

# check whether ClickHouse is installed at all
if ! yum list installed 'clickhouse*'; then
	echo "No ClickHouse packages installed"
	echo "Nothing to do. Exit"
	exit 0
fi

# ensure Altinity clickhouse repo is installed
if [ $(yum repolist | grep -i altinity_clickhouse | wc -l) -gt 0 ]; then
	# already installed, nothing to do here
	echo "Altinity ClickHouse repo already installed."
else
	echo "Can not find Altinity ClickHouse repo installed. Need to install it"
	curl -s https://packagecloud.io/install/repositories/Altinity/clickhouse/script.rpm.sh | sudo bash
fi


set -e

UPDATE_PACKAGES_CMD=""
for p in $CH_PACKAGES; do
        rpm -q $p >/dev/null 2>/dev/null || continue
	UPDATE_PACKAGES_CMD="${UPDATE_PACKAGES_CMD} ${p}-${TARGET_VERSION}"
done
echo "Updating ${UPDATE_PACKAGES_CMD}"
set -x
sudo yum update-to $UPDATE_PACKAGES_CMD

