#!/usr/bin/env perl
use warnings;
use strict;
use Test::More tests => 1;
use Test::Differences;
use Pod::Markdown;

my $parser = Pod::Markdown->new;
my $input = 'bin/pod2markdown';
open my $fh, $input or die "can't open $input: $!\n";
$parser->parse_from_filehandle($fh);
close $fh or die "can't close $input: $!\n";
my $markdown = $parser->as_markdown;
my $expect = do { local $/; <DATA> };

1 while chomp $markdown;
1 while chomp $expect;

eq_or_diff $markdown, $expect, "markdown from $input";

__DATA__
# NAME

pod2markdown - Convert POD text to Markdown 

# SYNOPSIS

    $ pod2markdown < POD_File > Markdown_File

# DESCRIPTION

This program uses [Pod::Markdown](http://search.cpan.org/perldoc?Pod::Markdown) to convert POD into Markdown sources. It is
a filter that expects POD on STDIN and outputs Markdown on STDOUT.

# AUTHORS

Marcel Gr&uuml;nauer, `<marcel@cpan.org>`

Victor Moral, `<victor@taquiones.net>`

# COPYRIGHT AND LICENSE

Copyright 2009 by Marcel Gr&uuml;nauer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

This program is strongly based on `pod2mdwn` from [Module::Build::IkiWiki](http://search.cpan.org/perldoc?Module::Build::IkiWiki).
