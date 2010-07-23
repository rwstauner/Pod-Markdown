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
# NAME

pod2markdown - Convert POD text to Markdown 

# SYNOPSIS

    $ pod2markdown < POD_File > Markdown_File

# DESCRIPTION

This program uses [Pod::Markdown](http://search.cpan.org/perldoc?Pod::Markdown) to convert POD into Markdown sources. It is
a filter that expects POD on STDIN and outputs Markdown on STDOUT.

FTP is at [ftp://ftp.univie.ac.at/foo/bar](ftp://ftp.univie.ac.at/foo/bar).

HTTP is at [http://univie.ac.at/baz/](http://univie.ac.at/baz/).

# SEE ALSO

This program is strongly based on `pod2mdwn` from [Module::Build::IkiWiki](http://search.cpan.org/perldoc?Module::Build::IkiWiki).

And see [foobar](#pod_foobar) as well.
EOMARKDOWN

1 while chomp $markdown;
1 while chomp $expect;

eq_or_diff $markdown, $expect, "this file's POD as markdown";

__DATA__
=head1 NAME

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
