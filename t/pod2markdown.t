# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use lib 't/lib';
use MarkdownTests;

use File::Temp qw{ tempfile }; # core
use File::Spec::Functions qw( catfile ); # core

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

# I tried this with IPC::Open2, but windows hangs waiting for more <STDIN>...

sub testp2m {
  my ($args, $desc) = @_;
  unshift @$args, $^X, "-I$lib", $script;
  {
    open(my $fh, '>', $outfile) or die "Failed to open $outfile: $!";
    print $fh "oops\n";
    close $fh;
  }
  is slurp_file($outfile), "oops\n", 'output file prepared';
  system(join ' ', map { length($_) > 1 ? qq["$_"] : $_ } @$args);
  is slurp_file($outfile), "# Temp\n\n_File_\n", $desc;
}

  testp2m(
    ['<', $infile, '>', $outfile],
    'no args: < in > out',
  );

  testp2m(
    [$infile, '>', $outfile],
    '1 arg: input file, stdout',
  );

  testp2m(
    [$infile, $outfile],
    '2 args: input file, output file',
  );

  testp2m(
    ['-', $outfile, '<', $infile],
    '2 args: - (stdin), output file',
  );

  testp2m(
    ['-', '-', '<', $infile, '>', $outfile],
    'both dashes: - (stdin) - (stdout)',
  );

done_testing;

sub slurp_file {
  my $path = shift;
  open(my $fh, '<', $path)
    or die "Failed to open $path: $!";
  slurp_fh($fh)
}
sub slurp_fh { my $fh = shift; local $/; <$fh>; }
