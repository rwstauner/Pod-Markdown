# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use lib 't/lib';
use MarkdownTests tests => 1;

my $parser = Pod::Markdown->new(
  perldoc_url_prefix => 'pod:',
);

$parser->output_string(\my $markdown);
$parser->parse_file(\*DATA);

# TODO: Verify this list behavior in html and perlpod(spec).
my $expect = <<'EOMARKDOWN';
# Lists

## Unordered

- This
- is
- a

    basic

- bulleted

    item

- list
- test
- and _Italics_, **Bold**, `Code`, and [Links](pod:Links) should work in list item

    and _in_ **paragraph** `after` [item](pod:item)

- verbatim paragraphs

        need double-indent inside lists

## Unordered nested list

**Note:** Markdown does not support definition lists (word => text), just bullets or numbers

- Head1

    Paragraph should be indented.
    \* And escaped.

    - Head2

        Paragraph should be indented.

- Head1

    Paragraph should be indented.

## Unordered nested huddled list

- This is a list head.
- This is a list head, too.
    - Again, this is a list head.
- Finally, this is also a list head.

And

- A list item
\\with a line that starts with a markdown char.
- item 2

## Ordered

1. B
2. D

## Ordered without dot

1. B
2. D

## No text after number

1.

        verbatim item
EOMARKDOWN

# check out Pod::IkiWiki (or something like that)...
# the code looks very similar to some of the code in this module
# but it appears to have some list processing methods...

{
  eq_or_diff $markdown, $expect, "this file's POD as markdown";
}

__DATA__
=head1 Lists

=head2 Unordered

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

and I<in> B<paragraph> C<after> L<item>

=item * verbatim paragraphs

  need double-indent inside lists

=back

=head2 Unordered nested list

B<Note:> Markdown does not support definition lists (word => text), just bullets or numbers

=over 4

=item Head1

Paragraph should be indented.
* And escaped.

=over 4

=item Head2

Paragraph should be indented.

=back

=item Head1

Paragraph should be indented.

=back

=head2 Unordered nested huddled list

=over 4

=item *

This is a list head.

=item *

This is a list head, too.

=over 4

=item *

Again, this is a list head.

=back

=item *

Finally, this is also a list head.

=back

And

=over

=item *

A list item
\with a line that starts with a markdown char.

=item *

item 2

=back

=head2 Ordered

=over

=item 1.

B

=item 2.

D

=back

=head2 Ordered without dot

=over

=item 1

B

=item 2

D

=back

=head2 No text after number

=over

=item 1

  verbatim item

=back

=cut
