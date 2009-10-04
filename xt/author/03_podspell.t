#!perl -w
use strict;
use warnings;
use Test::Spelling;
use Pod::Wordlist::hanekomu;
all_pod_files_spelling_ok('lib');
