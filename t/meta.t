# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use lib 't/lib';
use MarkdownTests;

my @tests;

push @tests, ['name',
<<POD,
=head1 NAME

who - cares
POD
<<MKDN];
[[meta title="who - cares"]]

# NAME

who - cares
MKDN

push @tests, ['author',
<<POD,
=head1 AUTHOR

me, myself, and i
POD
<<MKDN];
[[meta author="me, myself, and i"]]

# AUTHOR

me, myself, and i
MKDN

push @tests, ['none',
<<POD,
=head1 NAME

fooey - barish

=head1 AUTHOR

Foo Bar, Jr.

=head1 THE

end
POD
<<MKDN];
# NAME

fooey - barish

# AUTHOR

Foo Bar, Jr.

# THE

end
MKDN

{
  my (undef, $pod, $mkdn) = @{ $tests[-1] };
  $mkdn = <<MKDN . $mkdn;
[[meta title="fooey - barish"]]
[[meta author="Foo Bar, Jr."]]

MKDN

  push @tests, [ 'name, author', $pod, $mkdn ];
}

plan tests => scalar @tests;

foreach my $test ( @tests ) {
  my ($desc, $pod, $exp) = @$test;

  my $parser = Pod::Markdown->new;
  $parser->parse_from_filehandle( io_string($pod) );
  my $markdown = $parser->as_markdown(with_meta => ($desc ne 'none'));

  eq_or_diff $markdown, $exp, "meta tags: $desc";
}
