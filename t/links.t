#!/usr/bin/env perl
use warnings;
use strict;
use Test::More;
use Test::Differences;
use Pod::Markdown;

my $pod_prefix = 'http://search.cpan.org/perldoc?';
my $man_prefix = 'http://man.he.net/man';

my $parser = Pod::Markdown->new;

my @tests = (
# in order of L<> examples in perlpod:
['name',                         q<name>,                   qq^[name](${pod_prefix}name)^],
['other module',                 q<Other::Pod>,             qq^[Other::Pod](${pod_prefix}Other::Pod)^],

['section in other module',      q<Other::Pod/sec>,         qq^["sec" in Other::Pod](${pod_prefix}Other::Pod#sec)^],
['quoted section in other doc',  q<perlsyn/"For Loops">,    qq^["For Loops" in perlsyn](${pod_prefix}perlsyn#For Loops)^],

['section in this doc',          q</sec>,                   qq^["sec"](#sec)^],
['quoted section in this doc',   q</"sec">,                 qq^["sec"](#sec)^],

['other module, alternate text', q<other-pod|Other::Pod>,   qq^[other-pod](${pod_prefix}Other::Pod)^],
['other module, empty text',     q<|Other::Pod>,            qq^[Other::Pod](${pod_prefix}Other::Pod)^],

['sec in other mod, alt text',   q<x-sec|Other::Pod/sec>,   qq^[x-sec](${pod_prefix}Other::Pod#sec)^],
['"sec" in other mod, alt text', q<x-sec|Other::Pod/"sec">, qq^[x-sec](${pod_prefix}Other::Pod#sec)^],

['/"sec" in this doc, alt text', q<other-sec|/"sec">,       qq^[other-sec](#sec)^],
['/sec in this doc, alt text',   q<other-sec|/sec>,         qq^[other-sec](#sec)^],
['"sec" in this doc, alt text',  q<other-sec|"sec">,        qq^[other-sec](#sec)^],

['external ftp',                 q<ftp://server>,           qq^[ftp://server](ftp://server)^],
['external http',                q<http://website>,         qq^[http://website](http://website)^],
['http, alt text (perl 5.12)',   q<web|http://website>,     qq^[web](http://website)^],

['embedded codes',               q^the docs on C<$.>|perlvar/"$."^, qq^[the docs on C<\$.>](${pod_prefix}perlvar#\$.)^],

# perlpodspec examples:
['name',                         q<Foo::Bar>,               qq^[Foo::Bar](${pod_prefix}Foo::Bar)^],
['alt|pod/sec', q<Perlport's section on NL's|perlport/Newlines>, qq^[Perlport's section on NL's](${pod_prefix}perlport#Newlines)^],
['pod/sec',                      q<perlport/Newlines>,      qq^["Newlines" in perlport](${pod_prefix}perlport#Newlines)^],
['man/sec',               q<crontab(5)/"DESCRIPTION">,      qq^["DESCRIPTION" in crontab(5)](${man_prefix}5/crontab)^],
['/section name',                q</Object Attributes>,     qq^["Object Attributes"](#Object Attributes)^],
['http',                         q<http://www.perl.org/>,   qq^[http://www.perl.org/](http://www.perl.org/)^],
['text|http',             q<Perl.org|http://www.perl.org/>, qq^[Perl.org](http://www.perl.org/)^],
);

plan tests => scalar @tests;

foreach my $test ( @tests ){
  my ($desc, $pod, $mkdn) = @$test;
  is $parser->interior_sequence(L => $pod), $mkdn, $desc;
}
