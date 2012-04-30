# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use Test::More;
use Test::Differences;
use Pod::Markdown;

use File::Temp qw{ tempfile }; # core
use File::Spec::Functions; # core
use IPC::Open2 'open2'; # core

my ($lib, $bin) = scalar(grep { /\bblib\Wlib$/ } @INC)
  ? ('blib/lib', 'blib/script')
  : ('lib',      'bin');

my $script = catfile($bin, qw(pod2markdown));

my ($tmp_in,   $infile) = tempfile( 'pod2markdown-in.XXXXXX',  TMPDIR => 1, UNLINK => 1 );
print $tmp_in "=head1 Temp\n\nI<File>\n";
close $tmp_in;

my ($tmp_out, $outfile) = tempfile( 'pod2markdown-out.XXXXXX', TMPDIR => 1, UNLINK => 1 );
print $tmp_out "overwrite me\n";
close $tmp_out;

foreach my $test (
  ['no args'],
  ['both dashes', ('-') x 2],
){
  my $desc = shift @$test;
  pod2markdown(@$test, sub {
    my ($in_fh, $out_fh) = @_;
    print $in_fh "=head1 P2M\n";
    close $in_fh;
    is slurp_fh($out_fh), "# P2M\n", "$desc: stdin/stdout";
  });
}

  pod2markdown($infile, sub {
    my ($in_fh, $out_fh) = @_;
    close $in_fh;
    is slurp_fh($out_fh), "# Temp\n\n_File_\n", "input file, stdout";
  });

    is slurp_file($outfile), "overwrite me\n", "output file not used yet";

  pod2markdown($infile, $outfile, sub {
    close $_ for @_;
  });

    is slurp_file($outfile), "# Temp\n\n_File_\n", "input file, output file";

  pod2markdown('-', $outfile, sub {
    my ($in_fh, $out_fh) = @_;
    print $in_fh "=head1 P2M\n";
    close $in_fh;
    close $out_fh;
  });
    # after the sub
    is slurp_file($outfile), "# P2M\n", "stdin, output file";

done_testing;

sub pod2markdown {
  my $func = pop;
  my ($in, $out);
  my $pid = open2($out, $in, $^X, "-I$lib", $script, @_);
  $func->($in, $out);
  waitpid $pid, 0;
}

sub slurp_file {
  my $path = shift;
  open(my $fh, '<', $path)
    or die "Failed to open $path: $!";
  slurp_fh($fh)
}
sub slurp_fh { my $fh = shift; local $/; <$fh>; }
