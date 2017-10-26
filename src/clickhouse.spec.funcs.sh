#
# RPM build specification file for Yandex ClickHouse DBMS
# Common functions
#
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


CLICKHOUSE_USER=clickhouse
CLICKHOUSE_GROUP=${CLICKHOUSE_USER}
CLICKHOUSE_DATADIR=/var/lib/clickhouse
CLICKHOUSE_LOGDIR=/var/log/clickhouse-server

function create_system_user()
{
	USER=$1
	GROUP=$2
	HOMEDIR=$3

	echo "Create user ${USER}.${GROUP} with datadir ${HOMEDIR}"

	# Make sure the administrative user exists
	if ! getent passwd ${USER} > /dev/null; then
		adduser \
			--system \
			--no-create-home \
			--home ${HOMEDIR} \
			--shell /sbin/nologin \
			--comment "Clickhouse server" \
			clickhouse > /dev/null
	fi

	# if the user was created manually, make sure the group is there as well
	if ! getent group ${GROUP} > /dev/null; then
		addgroup --system ${GROUP} > /dev/null
	fi

	# make sure user is in the correct group
	if ! id -Gn ${USER} | grep -qw ${USER}; then
		adduser ${USER} ${GROUP} > /dev/null
	fi

	# check validity of user and group
	if [ "`id -u ${USER}`" -eq 0 ]; then
		echo "The ${USER} system user must not have uid 0 (root). Please fix this and reinstall this package." >&2
	        exit 1
	fi

	if [ "`id -g ${GROUP}`" -eq 0 ]; then
		echo "The ${USER} system user must not have root as primary group. Please fix this and reinstall this package." >&2
	        exit 1
	fi
}

