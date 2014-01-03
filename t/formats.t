# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use lib 't/lib';
use MarkdownTests;

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
  init => sub { $_[0]->unaccept_targets(qw(markdown html)) },
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

<div>
    foo
</div>

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


convert_ok(
  <<'POD',
Some I<pod>

=for html <i>not</i> I<pod> *text*
POD
  <<'MKDN',
Some _pod_

<div>
    <i>not</i> I<pod> *text*
</div>
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
