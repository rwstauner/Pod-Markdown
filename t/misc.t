# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use utf8;
use strict;
use warnings;
use lib 't/lib';
use MarkdownTests;

convert_ok
  "C<a ```code``` span>",
  "```` a ```code``` span ````",
  'code span with backticks uses more backticks as delimiter';

# This example is straight from http://daringfireball.net/projects/markdown/syntax#code.
convert_ok
  "C<`>",
  "`` ` ``",
  'multi-backtick delimiters also use spaces so that code spans can start or end with backticks';

convert_ok
  q{B<< Nested C<codes> and I<tags> >> work, too},
  q{**Nested `codes` and _tags_** work, too},
  'sequences can be nested';

convert_ok
  q{L<<< FormattZ<>ing C<C>odes|Links/"LE<lt>...E<gt>" >>>},
  q{[Formatting `C`odes](pod://Links#L<...>)},
  'pod sequences in link text';

convert_ok(
  <<POD,

=head2 I<Italics>, B<Bold>, C<Code>, and L<Links> should work in headers

I<Italics>, B<Bold>, C<Code>, and L<Links> should work in body text.

POD
  <<MKDN,

## _Italics_, **Bold**, `Code`, and [Links](pod://Links) should work in headers

_Italics_, **Bold**, `Code`, and [Links](pod://Links) should work in body text.

MKDN
  'pod sequences work in headings and paragraphs',
);


convert_ok
  <<POD,
=over

Quote some poetry
or say something special.

=back
POD
  <<MKDN,

> Quote some poetry
> or say something special.

MKDN
  'over/back becomes block quote';

convert_ok
  <<POD,
verbatim:

 para B<with> C<< E<verbar> >> codes
POD
  <<MKDN,
verbatim:

    para B<with> C<< E<verbar> >> codes
MKDN
  '';

done_testing;
