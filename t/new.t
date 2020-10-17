# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use lib 't/lib';
use MarkdownTests;

sub test_args {
  my $desc = pop;
  my $args = shift || {};
  my %exp = (
    man_url_prefix           => $Pod::Markdown::URL_PREFIXES{man},
    perldoc_url_prefix       => $Pod::Markdown::URL_PREFIXES{metacpan},
    perldoc_fragment_format  => 'metacpan',
    markdown_fragment_format => 'markdown',
    @_ ? %{ $_[0] } : ()
  );
  my $parser = Pod::Markdown->new(%$args);

  foreach my $attr ( sort keys %exp ){
    is $parser->$attr, $exp{$attr}, "$desc: $attr";
  }
}

test_args 'Default attributes';

foreach my $site ( qw( metacpan sco ) ){
  test_args
    { perldoc_url_prefix => $site },
    {
      perldoc_url_prefix => $Pod::Markdown::URL_PREFIXES{$site},
      perldoc_fragment_format => $site,
    },
    "Set perldoc_url_prefix to $site; get matching fragment format";
}

foreach my $format ( map { 'pod_simple_' . $_ } qw( xhtml html ) ){
  test_args
    { perldoc_fragment_format => $format },
    { perldoc_fragment_format => $format },
    "Explicit format $format";
}

foreach my $fragtype ( map { $_ . '_fragment_format' } qw( perldoc markdown ) ){
  my $sub = sub { 'blah' };
  test_args
    { $fragtype => $sub },
    { $fragtype => $sub },
    "Pass a code ref for $fragtype";
}

test_args
  {
    markdown_fragment_format => 'pod_simple_html',
    perldoc_fragment_format  => 'markdown',
  },
  {
    markdown_fragment_format => 'pod_simple_html',
    perldoc_fragment_format  => 'markdown',
  },
  'Values are interchangeable';


# TODO: Change this to an error after a sufficient amount of time.
like warning { Pod::Markdown->new(unknown_arg => 1); },
  qr/unknown_arg/, 'unknown arg throws a warning';

like warning { Pod::Markdown->new(encoding => 'oops'); },
  qr/encoding/, 'method that is not a rw attribute throws a warning';

like warning { Pod::Markdown->new(local_module_url_prefix => '', escape_url => 0) },
  qr/turning escape_url with an empty local_module_url_prefix is not recommended as relative URLs could be confused for IPv6 addresses/,
  'use empty url prefix and do not escape url';

done_testing;
