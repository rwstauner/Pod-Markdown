# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use Test::More;
use Pod::Markdown;

my $pod_prefix = $Pod::Markdown::URL_PREFIXES{pod};
my $man_prefix = $Pod::Markdown::URL_PREFIXES{man};

my $parser = Pod::Markdown->new;

my @tests = (
  [I => q<italic>,          q{_italic_}],
  [B => q<bold>,            q{__bold__}],
  [C => q<code>,            q{`code`}],

  # links tested extensively in t/links.t
  [L => q<link>,             "[link](${pod_prefix}link)"],

  [E => q<lt>,              q{<}],
  [E => q<gt>,              q{>}],
  [E => q<verbar>,          q{|}],
  [E => q<sol>,             q{/}],

  [E => q<eacute>,          q{&eacute;}],
  [E => q<0x201E>,          q{&#x201E;},  'E hex'],
  [E => q<075>,             q{&#61;},     'E octal'],
  [E => q<181>,             q{&#181;},    'E decimal'],

  # legacy charnames specifically mentioned by perlpodspec
  [E => q<lchevron>,        q{&laquo;}],
  [E => q<rchevron>,        q{&raquo;}],
  [E => q<zchevron>,        q{&zchevron;}],
  [E => q<rchevrony>,       q{&rchevrony;}],

  [F => q<file.ext>,        q{`file.ext`}],
  [S => q<$x ? $y : $z>,    q{$x&nbsp;?&nbsp;$y&nbsp;:&nbsp;$z}],
  [X => q<index>,           q{}],
  [Z => q<null>,            q{}],

  [Q => q<unknown>,         q{Q<unknown>}, 'uknown code (Q<>)' ],
);

plan tests => scalar @tests * 2;

foreach my $test ( @tests ){
  my ($code, $text, $exp, $desc) = @$test;
  $desc ||= "$code<$text>";

    # explicitly test interior_sequence (which is what we've defined)
    is $parser->interior_sequence($code => $text), $exp, $desc . ' (interior_sequence)';
    # also test parsing it as pod
    is $parser->interpolate("$code<<< $text >>>"), $exp, $desc . ' (interpolate)';
}
