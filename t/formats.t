# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use Test::More 0.88;
use Test::Differences;
use Pod::Markdown;

sub convert_ok {
  my ($pod, $exp, $desc, $code) = @_;
  my $parser = Pod::Markdown->new;
  $code->($parser) if $code;
  $parser->output_string(\(my $got));
  $parser->parse_string_document("=pod\n\n$pod\n\n=cut\n");
  chomp for ($got, $exp);
  eq_or_diff($got, $exp, $desc);
}

convert_ok(
  <<'POD',
Some I<pod>

=for html <b>html</b>

=for markdown **mkdn**

=for something_else `ignored`
POD
  <<'MKDN',
Some _pod_
MKDN
  'disable html and markdown targets',
  sub { $_[0]->unaccept_targets(qw(markdown html)) },
);


convert_ok(
  <<'POD',
Some I<pod>

=for other no

=for html foo

=for :html bar

=for :other nope

=for markdown baz

=for :markdown qux
POD
  <<'MKDN',
Some _pod_

foo

bar

baz

qux
MKDN
  'by default accept html and markdown targets',
);


convert_ok(
  <<'POD',
Some I<pod>

=for markdown **BOLD**! B<not pod>
POD
  <<'MKDN',
Some _pod_

**BOLD**! B<not pod>
MKDN
  '=for markdown passed through',
);


convert_ok(
  <<'POD',
Some I<pod>

=begin markdown

**BOLD**! B<not pod>

=end markdown
POD
  <<'MKDN',
Some _pod_

**BOLD**! B<not pod>
MKDN
  '=begin/end markdown passed through',
);


convert_ok(
  <<'POD',
Some I<pod>

=for :markdown **BOLD**! B<real bold>

=for :other `ignored`
POD
  <<'MKDN',
Some _pod_

\*\*BOLD\*\*! __real bold__
MKDN
  '=for :markdown gets processed and escaped',
);


convert_ok(
  <<'POD',
Some I<pod>

=begin :markdown

**BOLD**! B<real bold>

=end :markdown
POD
  <<'MKDN',
Some _pod_

\*\*BOLD\*\*! __real bold__
MKDN
  '=begin/end :markdown gets processed and escaped',
);


# TODO: I haven't entirely decided if html should escape markdown characters or not.


convert_ok(
  <<'POD',
Some I<pod>

=for html <i>not</i> I<pod> *text*
POD
  <<'MKDN',
Some _pod_

<i>not</i> I<pod> *text*
MKDN
  '=for html passes through',
);


convert_ok(
  <<'POD',
Some I<pod>

=for :html <i>yes</i> I<pod> *text*
POD
  <<'MKDN',
Some _pod_

<i>yes</i> _pod_ \*text\*
MKDN
  '=for :html gets processed and escaped',
);


done_testing;
