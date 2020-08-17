# clickhouse-rpm
This is an RPM builder and it is used to install all required dependencies and build ClickHouse RPMs for CentOS 6, 7 and Amazon Linux.

# Ready-to-use RPMs
In case you'd like to just install ready-to-use RPMs, and are not interested in building your own hand-made RPMs, there is [detailed explanation](https://github.com/Altinity/clickhouse-rpm-install) on how to use Altinity's [RPM repository](https://packagecloud.io/Altinity/clickhouse)

# Build RPMs

Run `builder` on any RHEL 6 or RHEL 7 based distribution and get ClickHouse source and binary RPM packages as an output.

```console
Usage:

./builder version
		display default version to build

./builder all [--debuginfo=no] [--cmake-build-type=Debug]
		install build deps, download sources, build RPMs
./builder all --test [--debuginfo=no]
		install build+test deps, download sources, build+test and test RPMs

./builder install --build-deps
		install build dependencies
./builder install --test-deps
		install test dependencies
./builder install --deps
		install all dependencies (both build and test)
./builder install --rpms [--from-sources]
		install RPMs, if available (do not build RPMs)

./builder build --spec
		just create SPEC file
		do not download sources, do not build RPMs
./builder build --rpms [--debuginfo=no] [--cmake-build-type=Debug] [--test] [--no-version-check]
		download sources, build SPEC file, build RPMs
		do not install dependencies
./builder build --download-sources
		just download sources into $RPMBUILD_ROOT_DIR/SOURCES/ClickHouse-$CH_VERSION-$CH_TAG folder
		(do not create SPEC file, do not install dependencies, do not build)
./builder build --rpms --from-sources-in-BUILD-dir [--debuginfo=no] [--cmake-build-type=Debug] [--test]
		just build RPMs from unpacked sources - most likely you have modified them
		sources are in $RPMBUILD_ROOT_DIR/BUILD/ClickHouse-$CH_VERSION-$CH_TAG folder
		(do not download sources, do not create SPEC file, do not install dependencies)
./builder build --rpms --from-sources-in-SOURCES-dir [--debuginfo=no] [--cmake-build-type=Debug] [--test]
		just build RPMs from unpacked sources - most likely you have modified them
		sources are in $RPMBUILD_ROOT_DIR/SOURCES/ClickHouse-$CH_VERSION-$CH_TAG folder
		(do not download sources, do not create SPEC file, do not install dependencies)
./builder build --rpms --from-archive [--debuginfo=no] [--cmake-build-type=Debug] [--test]
		just build RPMs from $RPMBUILD_ROOT_DIR/SOURCES/ClickHouse-$CH_VERSION-$CH_TAG folder.zip sources
		(do not download sources, do not create SPEC file, do not install dependencies)
./builder build --rpms --from-sources [--debuginfo=no] [--cmake-build-type=Debug] [--test]
		build from source codes

./builder test --docker [--from-sources]
		build Docker image and install produced RPM files in it. Run clickhouse-test
./builder test --local
		install required dependencies and run clickhouse-test on locally installed ClickHouse
./builder test --local-sql
		run several SQL queries on locally installed ClickHouse

./builder repo --publish --packagecloud=<packagecloud USER ID> [FILE 1] [FILE 2] [FILE N]
		publish packages on packagecloud as USER. In case no files(s) provided, rpmbuild/RPMS/x86_64/*.rpm would be used
./builder repo --delete  --packagecloud=<packagecloud USER ID> file1_URL [file2_URL ...]
		delete packages (specified as URL to file) on packagecloud as USER
		URL to file to be deleted can be copy+pasted from packagecloud.io site and is expected as:
		https://packagecloud.io/Altinity/clickhouse/packages/el/7/clickhouse-test-19.4.3.1-1.el7.x86_64.rpm

		OS=centos DISTR_MAJOR=7 DISTR_MINOR=5 ./builder repo --publish --packagecloud=XYZ [file(s)]
		OS=centos DISTR_MAJOR=7 DISTR_MINOR=5 ./builder repo --publish --path=altinity/clickhouse-altinity-stable --packagecloud=XYZ [file(s)]
		./builder repo --delete URL1 URL2 URL3
./builder repo --download [--path=altinity/clickhouse-altinity-stable] <VERSION>

./builder list --rpms
		list available RPMs

./builder src --download
		just download sources
```

In most cases just run `./builder all`

