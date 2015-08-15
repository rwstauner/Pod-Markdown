# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use lib 't/lib';
use MarkdownTests;
use Pod::Perldoc::ToMarkdown;

use File::Temp qw{ tempfile }; # core
use File::Spec::Functions qw( catfile ); # core

my ($tmp_out, $outfile) = tempfile( 'pod2markdown-out.XXXXXX', TMPDIR => 1, UNLINK => 1 );
print $tmp_out "overwrite me\n";
close $tmp_out;

sub corpus {
  catfile( corpus => $_[0] );
}

Pod::Perldoc::ToMarkdown->parse_from_file( corpus('copy.pod'), $outfile);

like slurp_file($outfile), qr/# cr\n\n\{ \\`\xc2\xa9\\` \}/,
  'ToMarkdown class for perldoc';

done_testing;
