#!/bin/bash

/usr/bin/clickhouse-server --config=/etc/clickhouse-server/config.xml 2>/dev/null &
/usr/bin/clickhouse-test "$CH_TEST_NAMES" > /clickhouse/result/out.txt
echo $? > /clickhouse/result/out.code.txt

