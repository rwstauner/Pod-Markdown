# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use utf8;
use strict;
use warnings;
use lib 't/lib';
use MarkdownTests tests => 1;

my $parser = Pod::Markdown->new(
  perldoc_url_prefix => 'pod://',
  # Just return the raw fragment so we know that it isn't unexpectedly mangled.
  perldoc_fragment_format => sub { $_ },
  markdown_fragment_format => sub { $_ },
);
my $pod_prefix = $parser->perldoc_url_prefix;

$parser->output_string(\my $markdown);
$parser->parse_file(\*DATA);

my $expect = <<'EOMARKDOWN';
# POD

pod2markdown - Convert POD text to Markdown

# SYNOPSIS

    $ pod2markdown < POD_File > Markdown_File

# DESCRIPTION

This program uses [Pod::Markdown](pod://Pod::Markdown) to convert POD into Markdown sources. It is
a filter that expects POD on STDIN and outputs Markdown on STDOUT.

FTP is at [ftp://ftp.univie.ac.at/foo/bar](ftp://ftp.univie.ac.at/foo/bar).

HTTP is at [http://univie.ac.at/baz/](http://univie.ac.at/baz/).

# SEE ALSO

This program is strongly based on `pod2mdwn` from [Module::Build::IkiWiki](pod://Module::Build::IkiWiki).

And see ["foobar"](#foobar) as well.

> Quote some poetry
> or say something special.

# MORE TESTS

## _Italics_, **Bold**, `Code`, and [Links](pod://Links) should work in headers

_Italics_, **Bold**, `Code`, and [Links](pod://Links) should work in body text.

**Nested `codes`** work, too

## \_Other\_ \*Characters\* \[Should\](Be) \`Escaped\` in headers

Inline `code _need not_ be escaped`.

Inline [link \*should\* \\\_ be\_escaped](#or\\things\(can\)go\\*wrong).

Inline `filename_should_not_be_escaped` because it is a code span.

### Heading `code _need not_ be escaped, either`.

**Nested `c*des` \_should\_ be escaped** (but not code).

non-breaking space: foo bar.

non-breaking code: `$x ? $y : $z` foo `bar` baz

    verbatim para B<with> C<< E<verbar> >> codes

A `` code span with `backticks` inside ``.

A ```` code span with triple ``` inside ````.

- This
- is
- a

    basic

- bulleted

    item

- list
- test
- and _Italics_, **Bold**, `Code`, and [Links](pod://Links) should work in list item

# Links

[Formatting `C`odes](pod://Links#L<...>)

[back \`tick](pod://inside#a&#x20;link)

# \*Special\* characters

html: < & &lt;tag/> &amp;entity;

    foo_bar is the result of 4 * 4

Regular characters like \*asterisks\* and \_\_underscores\_\_
should be escaped in regular text paragraphs.
Also \[brackets\],
lists:

\+ a
\+ b

\- a
\- b

\* A line that starts with an asterisk
\*should\* be escaped to avoid incorrectly interpreting
the line as a list item.

\# fake headings

\### fake headings ###

Setext fake
&#x3d;==========

Another fake
\------------

\> Quote
\> blocks
\> 1. with
\> 2. lists

1996\. A year.

\* Bird

\* Magic

\* List item

        `code` block

Hr's:

\---

\* \* \*

Inline \`code\`;
Links: \[Foo\] \[1\], \[Bar\](/baz)
An image: !\[image\](/foo)
backslash \\

From http://daringfireball.net/projects/markdown/syntax:

\\   backslash
\`   backtick
\*   asterisk
\_   underscore
{}  curly braces
\[\]  square brackets
()  parentheses
\#   hash mark
\+   plus sign
\-   minus sign (hyphen)
.   dot
!   exclamation mark
EOMARKDOWN

eq_or_diff $markdown, $expect, "this file's POD as markdown";

__DATA__
=head1 POD

pod2markdown - Convert POD text to Markdown

=head1 SYNOPSIS

    $ pod2markdown < POD_File > Markdown_File

=head1 DESCRIPTION

This program uses L<Pod::Markdown> to convert POD into Markdown sources. It is
a filter that expects POD on STDIN and outputs Markdown on STDOUT.

FTP is at L<ftp://ftp.univie.ac.at/foo/bar>.

HTTP is at L<http://univie.ac.at/baz/>.

=head1 SEE ALSO

This program is strongly based on C<pod2mdwn> from L<Module::Build::IkiWiki>.

And see L</foobar> as well.

=over

Quote some poetry
or say something special.

=back

=head1 MORE TESTS

=head2 I<Italics>, B<Bold>, C<Code>, and L<Links> should work in headers

I<Italics>, B<Bold>, C<Code>, and L<Links> should work in body text.

B<< Nested C<codes> >> work, too

=head2 _Other_ *Characters* [Should](Be) `Escaped` in headers

Inline C<< code _need not_ be escaped >>.

Inline L<< link *should* \_ be_escaped|/or\things(can)go\*wrong >>.

Inline F<< filename_should_not_be_escaped >> because it is a code span.

=head3 Heading C<< code _need not_ be escaped, either >>.

B<< Nested C<c*des> _should_ be escaped >> (but not code).

non-breaking space: S<foo bar>.

non-breaking code: S<C<$x ? $y : $z>> S<foo C<bar> baz>

 verbatim para B<with> C<< E<verbar> >> codes

A C<< code span with `backticks` inside >>.

A C<< code span with triple ``` inside >>.

=over 4

=item *

This

=item *	is

=item	* a

basic

=item *

bulleted

item

=item *

list

=item * test

=item * and I<Italics>, B<Bold>, C<Code>, and L<Links> should work in list item

=back

=head1 Links

L<<< FormattZ<>ing C<C>odes|Links/"LE<lt>...E<gt>" >>>

L<<< back `tick|inside/"a link" >>>

=head1 *Special* characters

html: < & <tag/> &entity;

    foo_bar is the result of 4 * 4

Regular characters like *asterisks* and __underscores__
should be escaped in regular text paragraphs.
Also [brackets],
lists:

+ a
+ b

- a
- b

* A line that starts with an asterisk
*should* be escaped to avoid incorrectly interpreting
the line as a list item.

# fake headings

### fake headings ###

Setext fake
===========

Another fake
------------

> Quote
> blocks
> 1. with
> 2. lists

1996. A year.

* Bird

* Magic

* List item

        `code` block

Hr's:

---

* * *

Inline `code`;
Links: [Foo] [1], [Bar](/baz)
An image: ![image](/foo)
backslash \

From http://daringfireball.net/projects/markdown/syntax:

\   backslash
`   backtick
*   asterisk
_   underscore
{}  curly braces
[]  square brackets
()  parentheses
#   hash mark
+   plus sign
-   minus sign (hyphen)
.   dot
!   exclamation mark
