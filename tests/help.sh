#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2015-05-25 01:38:24 +0100 (Mon, 25 May 2015)
#
#  https://github.com/harisekhon
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help improve or steer this or other code I publish
#
#  http://www.linkedin.com/in/harisekhon
#

set -eu
srcdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$srcdir/..";

export PERLBREW_ROOT="${PERLBREW_ROOT:-~/perl5/perlbrew}"

export TRAVIS_PERL_VERSION="${TRAVIS_PERL_VERSION:-*}"

# For Travis CI which installs modules locally
export PERL5LIB=$(echo \
    ${PERL5LIB:-.} \
    $PERLBREW_ROOT/perls/$TRAVIS_PERL_VERSION/lib/site_perl/$TRAVIS_PERL_VERSION.*/x86_64-linux \
    $PERLBREW_ROOT/perls/$TRAVIS_PERL_VERSION/lib/site_perl/$TRAVIS_PERL_VERSION.* \
    $PERLBREW_ROOT/perls/$TRAVIS_PERL_VERSION/lib/$TRAVIS_PERL_VERSION.*/x86_64-linux \
    $PERLBREW_ROOT/perls/$TRAVIS_PERL_VERSION/lib/$TRAVIS_PERL_VERSION.* \
    | tr '\n' ':'
)
# Taint code doesn't use PERL5LIB, use -I instead
I_lib=""
for x in $(echo "$PERL5LIB" | tr ':' ' '); do
    I_lib+="-I $x "
done

for x in $(echo *.pl *.py *.rb 2>/dev/null); do
    [[ "$x" =~ ^\* ]] && continue
    [[ "$x" = "check_puppet.rb" ]] && continue
    # Kafka module requires Perl >= 5.10, skip when running tests on 5.8 for CentOS 5 for which everything else works
    if [ "$TRAVIS_PERL_VERSION" = "5.8" ]; then
        [ "$x" = "check_kafka.pl" ] && { echo "skipping check_kafka.pl on Perl 5.8 since the Kafka CPAN module requires Perl >= 5.10"; continue; }
        [[ "$x" =~ check_mongodb_.*.pl ]] && { echo "skipping check_mongodb_*.pl on Perl 5.8 since the MongoDB module requires Type::Tiny::XS which breaks for some unknown reason"; continue; }
    fi
    set +e
    # ignore zookeeper as it may not be built
    grep -q "Net::ZooKeeper" "$x" && { echo "skipping $x due to Net::ZooKeeper dependency which may not be built"; continue; }
    commit="$(git log "$x" | head -n1 | grep 'commit')"
    if [ -z "$commit" ]; then
        continue
    fi
    optional_cmd=""
    if [[ $x =~ .*\.pl$ ]]; then
        optional_cmd="perl -T $I_lib"
    fi
    echo $optional_cmd ./$x --help
    $optional_cmd ./$x --help # >/dev/null
    status=$?
    set -e
    # quick hack for older programs
    [ "$x" = "check_dhcpd_leases.py" -o \
      "$x" = "check_linux_ram.py"    -o \
      "$x" = "check_logserver.py"    -o \
      "$x" = "check_syslog_mysql.py" -o \
      "$x" = "check_yum.py" ] && [ $status = 0 ] && { echo "allowing $x to have zero exit code"; continue; }
    [ $status = 3 ] || { echo "status code for $x --help was $status not expected 3"; exit 1; }
    echo "================================================================================"
done
echo "All Perl / Python / Ruby programs found exited with expected code 3 for --help"
