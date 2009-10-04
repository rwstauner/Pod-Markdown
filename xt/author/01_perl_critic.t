#!perl -w
use strict;
use warnings;
use FindBin '$Bin';
use File::Spec;
use UNIVERSAL::require;
use Test::More;
my %opt;
my $rc_file = File::Spec->catfile($Bin, 'perlcriticrc');
$opt{'-profile'} = $rc_file if -r $rc_file;

if (   Perl::Critic->require('1.078')
    && Test::Perl::Critic->require
    && Test::Perl::Critic->import(%opt)) {
    all_critic_ok("lib");
} else {
    fail('install Perl::Critic and Test::Perl::Critic');
}
