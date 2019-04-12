#!/bin/bash
#
# OS - related functions
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

##
##
##
function set_print_commands()
{
	set -x
}

##
##
##
function banner()
{
	# disable print commands
	set +x

	# write banner

	# all params as one string
	local str="${*}"

	# str len in chars (not bytes)
	local char_len=${#str}

	# header has '## ' on the left and ' ##' on the right thus 6 chars longer that the str
	local head_len=$((char_len+6))

	# build line of required length '###########################'
	local head=""
	for i in $(seq 1 ${head_len}); do
		head="${head}#"
	done

	# build banner
	local res="${head}
## ${str} ##
${head}"

	# display banner
	echo "$res"

	# and return back print commands setting
	set_print_commands
}

##
##
##
function list_RPMs()
{
	banner "Looking for RPMs $RPMS_DIR/clickhouse*.rpm"
	ls -l "$RPMS_DIR"/clickhouse*.rpm
}

##
##
##
function list_SRPMs()
{
	banner "Looking for sRPMs at $SRPMS_DIR/clickhouse*"
	ls -l "$SRPMS_DIR"/clickhouse*
}

##
##
##
function mkdirs()
{
	banner "Prepare dirs"
	mkdir -p "$RPMBUILD_ROOT_DIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
	mkdir -p "$TMP_DIR"
}

##
##
##
function press_enter()
{
	read -p "Press enter to continue"
}

##
##
##
function press_any_key()
{
	# -n character count to stop reading
	# -s hide input
	# -r interpret string in raw - without considering backslash escapes
	read -n 1 -s -r -p "Press any key to continue"
}

