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

plan tests => scalar @tests * 3;

foreach my $test ( @tests ) {
  as_markdown_with_meta(@$test);
  output_string_include_meta_tags(@$test);
  both(@$test);
}

sub as_markdown_with_meta {
  my ($desc, $pod, $exp, $use_attr) = @_;

  my $parser = Pod::Markdown->new;
  $parser->include_meta_tags(1) if $use_attr;
  $parser->parse_from_filehandle( io_string($pod) );
  my $markdown = $parser->as_markdown(with_meta => ($desc ne 'none'));

  my $prefix = $use_attr ? 'both' : 'with_meta';
  eq_or_diff $markdown, $exp, "${prefix}: $desc";
}

sub output_string_include_meta_tags {
  my ($desc, $pod, $exp) = @_;

  my $parser = Pod::Markdown->new;
  $parser->include_meta_tags(1) if $desc ne 'none';
  $parser->output_string(\(my $markdown));
  $parser->parse_string_document($pod);

  eq_or_diff $markdown, $exp, "include_meta_tags: $desc";
}

sub both {
  as_markdown_with_meta(@_, $_[0] ne 'none');
}
