#!/usr/bin/env perl
use warnings;
use strict;
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

# THAT'S ENOUGH
EOMARKDOWN

1 while chomp $markdown;
1 while chomp $expect;

eq_or_diff $markdown, $expect, "this file's POD as markdown";

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

=head1 THAT'S ENOUGH

=cut
