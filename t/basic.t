# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use lib 't/lib';
use MarkdownTests tests => 1;

# Test a small, easy section of pod just to show when the parser
# is working.  We'll test more of the details in other scripts.

my $parser = Pod::Markdown->new(
);

$parser->output_string(\my $markdown);
$parser->parse_file(\*DATA);

my $expect = <<EOMARKDOWN;
# POD

One line.

## MORE

One paragraph.
Another line.

    verbatim `text`

Another paragraph.

- Bullet
- Again

`ode`
**old**
_talic_
EOMARKDOWN

eq_or_diff $markdown, $expect, 'convert some basic pod into markdown';

__DATA__
=head1 POD

One line.

=head2 MORE

One paragraph.
Another line.

  verbatim `text`

Another paragraph.

=over

=item *

Bullet

=item *

Again

=back

C<ode>
B<old>
I<talic>

=cut
