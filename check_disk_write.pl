#!/usr/bin/perl -T
# nagios: -epn
#
#  Author: Hari Sekhon
#  Date: 2013-07-24 18:28:09 +0100 (Wed, 24 Jul 2013)
#
#  http://github.com/harisekhon
#
#  License: see accompanying LICENSE file
#

$DESCRIPTION = "Nagios Plugin to check a disk is writable and functioning properly by writing a tiny canary file with unique generated contents and then reading it back to make sure it was written properly.

Useful to detect I/O errors and disks that have been re-mounted read-only as often happens when I/O errors are detected by the kernel on the disk subsystem.";

$VERSION = "0.1";

use strict;
use warnings;
BEGIN {
    use File::Basename;
    use lib dirname(__FILE__) . "/lib";
}
use HariSekhonUtils;
use File::Temp;

my $dir;

%options = (
    "d|directory=s"   =>  [ \$dir,    "Directory to write the canary file to. Set this to a directory on the mount point of the disk you want to check" ],
);

get_options();

$dir = validate_directory($dir);
my $random_string = sprintf("%s %s %s", $progname, time, random_alnum(20));
vlog_options "random string", "'$random_string'\n";

set_timeout();

$status = "OK";

my $fh;
try {
    $fh = File::Temp->new(TEMPLATE => "$dir/${progname}_XXXXXXXXXX");
};
catch_quit "failed to create canary file";
my $filename = $fh->filename;
vlog_options "canary file", "'$filename'\n";

try {
    print $fh $random_string;
};
catch_quit "failed to write random string to canary file '$filename'";

try {
    seek($fh, 0, 0) or quit "CRITICAL", "failed to seek to beginning of canary file '$filename': $!";
};
catch_quit "failed to seek to beginning of canary file '$filename'";

my $contents = "";
my $bytes;
try {
    $bytes = read($fh, $contents, 100);
};
catch_quit "failed to read back from canary file '$filename'";
vlog2 "$bytes bytes read back from test file\n";
vlog3 "contents = '$contents'\n";

if($contents eq $random_string){
    vlog2 "random string written and read back contents match OK\n";
} else {
    quit "CRITICAL", "canary file I/O error (written => read contents differ: '$random_string' vs '$contents')";
}

$msg = "canary file I/O written => read back $bytes bytes successfully, unique contents verified";

quit $status, $msg;
