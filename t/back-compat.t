# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use lib 't/lib';
use MarkdownTests;
use File::Spec ();

# Explicitly test using a real file.
my $_pod_path = File::Spec->catfile(qw(corpus tinypod.txt));
my $_pod_text = "This is _pod_.";

sub compare {
  my ($got, $exp, $desc) = @_;
  chomp $got;
  eq_or_diff $got, $exp, $desc;
}

# Dist::Zilla::Plugin::ReadmeAnyFromPod
SKIP: {
  eval 'require IO::Scalar'
    or skip 'IO::Scalar not available for testing.', 1;

  my $pod = "=pod\n\nB<foo>\n";

  my $parser = Pod::Markdown->new();

  my $input_handle = IO::Scalar->new(\$pod);

  $parser->parse_from_filehandle($input_handle);
  my $content = $parser->as_markdown();

  compare $content, '**foo**',
    'parse_from_filehandle( IO::Scalar->new(\$string) )';
}

# Minilla
# Module::Build::Pluggable::ReadmeMarkdownFromPod
# Module::Install::ReadmeMarkdownFromPod
{
  my $readme_from = $_pod_path;

  my $parser = Pod::Markdown->new;
  $parser->parse_from_file($readme_from);

  my $markdown = $parser->as_markdown;

  compare $markdown, $_pod_text,
    'parse_from_file( $path )';
}

{
  my $pod = $_pod_path;

  open my $pod_fh, '<', $pod        or die "Can't read POD '$pod'";

  my $md = Pod::Markdown->new;
  $md->parse_from_filehandle($pod_fh);

  compare $md->as_markdown, $_pod_text,
    'parse_from_filehandle( open(my) )';
}

done_testing;
