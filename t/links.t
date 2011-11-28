# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use Test::More;
use Pod::Markdown;

my $pod_prefix = 'http://search.cpan.org/perldoc?';
my $man_prefix = 'http://man.he.net/man';

my $parser = Pod::Markdown->new;

my $alt_text_for_urls = (Pod::ParseLink->VERSION >= 1.10);

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

['embedded codes',               q^the docs on C<$.>|perlvar/"$."^, qq^[the docs on `\$.`](${pod_prefix}perlvar#\$.)^],
["don't expand nested L's",      q^perlpodspec/"About LE<lt>...E<gt> Codes"^, qq^["About L<...> Codes" in perlpodspec](${pod_prefix}perlpodspec#About L<...> Codes)^],

# perlpodspec examples:
['name',                         q<Foo::Bar>,               qq^[Foo::Bar](${pod_prefix}Foo::Bar)^],
['alt|pod/sec', q<Perlport's section on NL's|perlport/Newlines>, qq^[Perlport's section on NL's](${pod_prefix}perlport#Newlines)^],
['pod/sec',                      q<perlport/Newlines>,      qq^["Newlines" in perlport](${pod_prefix}perlport#Newlines)^],
['man/sec',               q<crontab(5)/"DESCRIPTION">,      qq^["DESCRIPTION" in crontab(5)](${man_prefix}5/crontab)^],
['/section name',                q</Object Attributes>,     qq^["Object Attributes"](#Object Attributes)^],
['http',                         q<http://www.perl.org/>,   qq^[http://www.perl.org/](http://www.perl.org/)^],
['text|http',             q<Perl.org|http://www.perl.org/>, qq^[Perl.org](http://www.perl.org/)^],

# how should these be handled?  these are unlikely/contrived occurrences and are mostly here for test coverage
['man()',                        q<crontab()>,              qq^[crontab()](${man_prefix}1/crontab)^],
['man(X)',                       q<crontab(X)>,             qq^[crontab(X)](${man_prefix}X/crontab)^],
['man(2)-page',                  q<crontab(2)-page>,        qq^[crontab(2)-page](${man_prefix}2/crontab)^],
['(X)man',                       q<(X)foo>,                 qq^[(X)foo](${man_prefix}1/(X)foo)^],
['()',                           q<()>,                     qq^[()](${man_prefix}1/())^],

# varies according to pod-to-html formatter:
['other/section name',           q<Other/Section Name>,     qq^["Section Name" in Other](${pod_prefix}Other#Section Name)^],

# is there something better to do?
['no url: empty',                q<>,                       qq^L<>^],
['no url: pipe',                 q<|>,                      qq^L<|>^],
['no url: slash',                q</>,                      qq^L</>^],
['no url: quotes',               q<"">,                     qq^L<"">^],
);

plan tests => scalar @tests * 2;

foreach my $test ( @tests ){
  my ($desc, $pod, $mkdn) = @$test;

  SKIP: {
    skip 'alt text with schemes/absolute URLs not supported until perl 5.12 / Pod::ParseLink 1.10', 1
      if !$alt_text_for_urls && $pod =~ m/\|\w+:[^:\s]\S*\z/; # /alt text \| url (not perl module)/ (regexp from perlpodspec)

    # interior_sequence is what we specifically want to test
    is $parser->interior_sequence(L => $pod), $mkdn, $desc . ' (interior_sequence)';
    # but interpolate() tests the pod parsing as a whole (which can expose recursion bugs, etc)
    is $parser->interpolate("L<<< $pod >>>"), $mkdn, $desc . ' (interpolate)';
  }
}
