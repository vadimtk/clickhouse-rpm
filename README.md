# clickhouse-rpm
Build ClickHouse RPMs

# Ready-to-use RPMs
In case you'd like to just get ready RPMs look into [this repo](https://packagecloud.io/Altinity/clickhouse)

# Build RPMs

Run `builder` on any RHEL 6 or RHEL 7 based distribution and get ClickHouse source and binary RPM packages as an output.

```bash
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

./builder repo --publish --packagecloud=<packagecloud USER ID>
		publish packages on packagecloud as USER
./builder repo --delete  --packagecloud=<packagecloud USER ID> file1_URL [file2_URL ...]
		delete packages (specified as URL to file) on packagecloud as USER
		URL to file to be deleted can be copy+pasted from packagecloud.io site and is expected as:
		https://packagecloud.io/Altinity/clickhouse/packages/el/7/clickhouse-test-19.4.3.1-1.el7.x86_64.rpm

./builder src --download
		just download sources
Tests launched in Docker honor CH_TEST_NAMES env var which is a regexp to choose what tests to run
CH_TEST_NAMES='^(?!00700_decimal_math).*$' in case you'd like to skip problematic decimal math test
It is actulally run as clickhouse-test $CH_TEST_NAMES so check for more info with clickhouse-test
This env var is recognized by: './builder all --test' and './builder test --docker'
```

In most cases just run `./builder all`

