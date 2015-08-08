# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use utf8;
use strict;
use warnings;
use lib 't/lib';
use MarkdownTests;

my $pod_prefix = Pod::Markdown->new->perldoc_url_prefix;

my @tests = (
  [I => q<italic>,          q{_italic_}],
  [B => q<bold>,            q{**bold**}],
  [C => q<code>,            q{`code`}],
  [C => q<c*de>,            q{`c*de`}],

  # links tested extensively in t/links.t
  [L => q<link>,             "[link](${pod_prefix}link)"],
  [L => q<star*>,            "[star\\*](${pod_prefix}star*)"],

  # Pod::Simple handles the E<> entirely (Pod::Markdown never sees them).
  [E => q<lt>,              q{<}],
  [E => q<gt>,              q{>}],
  [E => q<verbar>,          q{|}],
  [E => q<sol>,             q{/}],

  [E => q<eacute>,          q{é}],
  [E => q<0x201E>,          q{„},  'E hex'],
  [E => q<075>,             q{=},  'E octal'],
  [E => q<181>,             q{µ},  'E decimal'],

  # legacy charnames specifically mentioned by perlpodspec
  [E => q<lchevron>,        q{«}],
  [E => q<rchevron>,        q{»}],

  [F => q<file.ext>,        q{`file.ext`}],
  [F => q<file_path.ext>,   q{`file_path.ext`}],
  [S => q<$x ? $y : $z>,    q{$x ? $y : $z}],
  [X => q<index>,           q{}],
  [Z => q<>,                q{}],

  #[Q => q<unknown>,         q{Q<unknown>}, 'uknown code (Q<>)' ],
);

plan tests => scalar @tests;

foreach my $test ( @tests ){
  my ($code, $text, $exp, $desc) = @$test;
  $desc ||= "$code<$text>";

  my $parser = Pod::Markdown->new;
  $parser->output_string(\(my $got));
  # Prefix line to avoid escaping beginning-of-line characters (like `>`).
  my $prefix = 'Code:';
  $parser->parse_string_document("=pod\n\n$prefix $code<<< $text >>>");
  chomp($got);
  is $got, "$prefix $exp", $desc;
}
