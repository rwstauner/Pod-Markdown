# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use lib 't/lib';
use MarkdownTests;

# TODO: Test everything beneath a numbered list and inside a blockquote.

convert_ok(
  <<'POD',
=over

=item 1.

lizard

=item 2.

bird

=over

=item 1.

duck

=item 2.

penguin

=item 3.

turkey

gobble
gobble.

=item 4.

eagle

=back

=item 3.

bear

=over

=item 1.

grizzly

=item 2.

polar

=over

=item 1.

angry

=item 2.

sleepy

=back

=back

=back
POD
  <<'MKDN',
1. lizard
2. bird
    1. duck
    2. penguin
    3. turkey

        gobble
        gobble.

    4. eagle
3. bear
    1. grizzly
    2. polar
        1. angry
        2. sleepy
MKDN
  'indent content of numbered list items',
);

done_testing;
