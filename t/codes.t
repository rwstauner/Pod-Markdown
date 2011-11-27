# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use Test::More;
use Test::Differences;
use Pod::Markdown;

my $pod_prefix = 'http://search.cpan.org/perldoc?';
my $man_prefix = 'http://man.he.net/man';

my $parser = Pod::Markdown->new;

my @tests = (
  [I => q<italic>,          q{_italic_}],
  [B => q<bold>,            q{__bold__}],
  [C => q<code>,            q{`code`}],
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
