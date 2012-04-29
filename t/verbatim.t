# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use Test::More tests => 1;
use Test::Differences;
use Pod::Markdown;

my $parser = Pod::Markdown->new;
$parser->parse_from_filehandle(\*DATA);
my $markdown = $parser->as_markdown;
my $expect = <<'EOMARKDOWN';
# SYNOPSIS

    # 4 spaces
    # should come out the same

# TABS

	These tabs
	can be left alone

# 3 SPACES

    3 spaces should be converted to 4.
    Here, too

And also

    here.

# MIXED (You don't really want to do that, though, do you?)

Mixed paragraphs should all get the same indentation added
to preserve the formatting:

      4 spaces (+ 2 = 6)
	a tab
     3 spaces (+ 2 = 5)
    2 spaces (+ 2 = 4) (the minimum)

# 5 spaces

     Because you can
     if you want to

# 1 space

    a little short, but valid

# THAT'S ENOUGH
EOMARKDOWN

eq_or_diff $markdown, $expect,
  'preserve verbatim paragraphs of various initial whitespace combinations';

__DATA__
=head1 SYNOPSIS

    # 4 spaces
    # should come out the same

=head1 TABS

	These tabs
	can be left alone

=head1 3 SPACES

   3 spaces should be converted to 4.
   Here, too

And also

   here.

=head1 MIXED (You don't really want to do that, though, do you?)

Mixed paragraphs should all get the same indentation added
to preserve the formatting:

    4 spaces (+ 2 = 6)
	a tab
   3 spaces (+ 2 = 5)
  2 spaces (+ 2 = 4) (the minimum)

=head1 5 spaces

     Because you can
     if you want to

=head1 1 space

 a little short, but valid

=head1 THAT'S ENOUGH

=cut
