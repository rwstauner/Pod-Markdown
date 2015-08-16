# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use utf8;
use strict;
use warnings;
use lib 't/lib';
use MarkdownTests;

convert_ok
  q{=head2 _Other_ *Characters* [Should](Be) `Escaped` in headers},
  q{## \_Other\_ \*Characters\* \[Should\](Be) \`Escaped\` in headers},
  'literal markdown chars escaped in headers';

convert_ok
  q{Inline C<< code _need not_ be escaped >>.},
  q{Inline `code _need not_ be escaped`.},
  'literal markdown chars allowed verbatim in code spans';

convert_ok
  q{=head3 Heading C<< code _need not_ be escaped, either >>.},
  q{### Heading `code _need not_ be escaped, either`.},
  'literal markdown chars allowed verbatim in code spans (in headings)';

convert_ok
  q{B<< Nested C<c*des> _should_ be escaped >> (but not code).},
  q{**Nested `c*des` \_should\_ be escaped** (but not code).},
  'literal markdown chars escaped in nested sequences';

convert_ok
  q{Inline F<< filename_should_not >> be escaped},
  q{Inline `filename_should_not` be escaped},
  'filenames (F<>) are code spans so no escaping needed';

convert_ok
  q{L<<< *chars* in_ `text|inside/"a link" >>>},
  q{[\*chars\* in\_ \`text](pod://inside#a&#x20;link)},
  'escape markdown characters in link text';

# Use heredoc to simplify the backslashes.
convert_ok
  <<'POD',
Inline L<< link *should* \_ be_escaped|/or\things(can)go\*wrong >>.
POD
  <<'MKDN',
Inline [link \*should\* \\\_ be\_escaped](#or\\things\(can\)go\\*wrong).
MKDN
  'link targets also escaped';

convert_ok
  <<'POD',
=head1 SYNOPSIS

    $ pod2markdown < POD_File > Markdown_File
POD
  <<'MKDN',
# SYNOPSIS

    $ pod2markdown < POD_File > Markdown_File
MKDN
  'verbatim paragraph indents and requires no escaping';

convert_ok
  <<'POD',
=head1 *Special* characters

html: < & <tag/> &entity;

    foo_bar is the result of 4 * 4

Regular characters like *asterisks* and __underscores__
should be escaped in regular text paragraphs.
Also [brackets],
lists:

+ a
+ b

- a
- b

* A line that starts with an asterisk
*should* be escaped to avoid incorrectly interpreting
the line as a list item.

# fake headings

### fake headings ###

Setext fake
===========

Another fake
------------

> Quote
> blocks
> 1. with
> 2. lists

1996. A year.

* Bird

* Magic

* List item

        `code` block

Hr's:

---

* * *

Inline `code`;
Links: [Foo] [1], [Bar](/baz)
An image: ![image](/foo)
backslash \

From http://daringfireball.net/projects/markdown/syntax:

\   backslash
`   backtick
*   asterisk
_   underscore
{}  curly braces
[]  square brackets
()  parentheses
#   hash mark
+   plus sign
-   minus sign (hyphen)
.   dot
!   exclamation mark
POD
  <<'MKDN',
# \*Special\* characters

html: < & &lt;tag/> &amp;entity;

    foo_bar is the result of 4 * 4

Regular characters like \*asterisks\* and \_\_underscores\_\_
should be escaped in regular text paragraphs.
Also \[brackets\],
lists:

\+ a
\+ b

\- a
\- b

\* A line that starts with an asterisk
\*should\* be escaped to avoid incorrectly interpreting
the line as a list item.

\# fake headings

\### fake headings ###

Setext fake
&#x3d;==========

Another fake
\------------

\> Quote
\> blocks
\> 1. with
\> 2. lists

1996\. A year.

\* Bird

\* Magic

\* List item

        `code` block

Hr's:

\---

\* \* \*

Inline \`code\`;
Links: \[Foo\] \[1\], \[Bar\](/baz)
An image: !\[image\](/foo)
backslash \\

From http://daringfireball.net/projects/markdown/syntax:

\\   backslash
\`   backtick
\*   asterisk
\_   underscore
{}  curly braces
\[\]  square brackets
()  parentheses
\#   hash mark
\+   plus sign
\-   minus sign (hyphen)
.   dot
!   exclamation mark
MKDN
  'literal markdown characters in pod escaped';

done_testing;
