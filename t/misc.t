# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use Test::More tests => 1;
use Test::Differences;
use Pod::Markdown;

my $pod_prefix = Pod::Markdown->new->perldoc_url_prefix;

my $parser = Pod::Markdown->new;
$parser->parse_from_filehandle(\*DATA);
my $markdown = $parser->as_markdown;
my $expect = <<EOMARKDOWN;
# POD

pod2markdown - Convert POD text to Markdown

# SYNOPSIS

    \$ pod2markdown < POD_File > Markdown_File

# DESCRIPTION

This program uses [Pod::Markdown](${pod_prefix}Pod::Markdown) to convert POD into Markdown sources. It is
a filter that expects POD on STDIN and outputs Markdown on STDOUT.

FTP is at [ftp://ftp.univie.ac.at/foo/bar](ftp://ftp.univie.ac.at/foo/bar).

HTTP is at [http://univie.ac.at/baz/](http://univie.ac.at/baz/).

# SEE ALSO

This program is strongly based on `pod2mdwn` from [Module::Build::IkiWiki](${pod_prefix}Module::Build::IkiWiki).

And see ["foobar"](#foobar) as well.

# MORE TESTS

## _Italics_, __Bold__, `Code`, and [Links](${pod_prefix}Links) should work in headers

_Italics_, __Bold__, `Code`, and [Links](${pod_prefix}Links) should work in body text.

__Nested `codes`__ work, too

## \\_Other\\_ \\*Characters\\* \\[Should\\](Be) \\`Escaped\\` in headers

Inline `code _need not_ be escaped`.

Inline [link_should_not_be_escaped](${pod_prefix}link_should_not_be_escaped).

Inline `filename_should_not_be_escaped`.

### Heading `code _need not_ be escaped, either`.

__Nested `c*des` \\_should\\_ be escaped__ (but not code).

non-breaking space: foo&nbsp;bar.

non-breaking code: `\$x&nbsp;?&nbsp;\$y&nbsp;:&nbsp;\$z` foo&nbsp;`bar`&nbsp;baz

    verbatim para B<with> C<< E<verbar> >> codes

- This
- is
- a

    basic

- bulleted

    item

- list
- test
- and _Italics_, __Bold__, `Code`, and [Links](${pod_prefix}Links) should work in list item

# Links

[Formatting `C`odes](${pod_prefix}Links#L<...>)
EOMARKDOWN
$expect .= <<'EOMARKDOWN';

# \*Special\* characters

    foo_bar is the result of 4 * 4

Regular characters like \*asterisks\* and \_\_underscores\_\_
should be escaped in regular text paragraphs.
Also \[brackets\],
lists:

\+ a
\+ b

\- a
\- b

\# fake headings
\#\#\# fake headings \#\#\#

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

=head1 MORE TESTS

=head2 I<Italics>, B<Bold>, C<Code>, and L<Links> should work in headers

I<Italics>, B<Bold>, C<Code>, and L<Links> should work in body text.

B<< Nested C<codes> >> work, too

=head2 _Other_ *Characters* [Should](Be) `Escaped` in headers

Inline C<< code _need not_ be escaped >>.

Inline L<< link_should_not_be_escaped >>.

Inline F<< filename_should_not_be_escaped >>.

=head3 Heading C<< code _need not_ be escaped, either >>.

B<< Nested C<c*des> _should_ be escaped >> (but not code).

non-breaking space: S<foo bar>.

non-breaking code: S<C<$x ? $y : $z>> S<foo C<bar> baz>

 verbatim para B<with> C<< E<verbar> >> codes

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

=head1 *Special* characters

    foo_bar is the result of 4 * 4

Regular characters like *asterisks* and __underscores__
should be escaped in regular text paragraphs.
Also [brackets],
lists:

+ a
+ b

- a
- b

# fake headings
### fake headings ###

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
