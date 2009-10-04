#!perl
use strict;
use warnings;
use FindBin '$Bin';
use Test::Kwalitee;
my $file = "$Bin/../../Debian_CPANTS.txt";
if (-e $file) {
    unlink $file or die "can't unlink $file: $!\n";
}
