# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use utf8;
use strict;
use warnings;
use lib 't/lib';
use MarkdownTests;

# Escape things that would be interpreted as inline html.

sub entity_encode_ok {
  my ($desc, $pod, $markdown, %opts) = @_;
  my $verbatim = $opts{verbatim} || $pod;

  note hex_escape $pod;

  convert_both($pod, $markdown, $verbatim, $desc);
}

sub convert_both {
  my ($pod, $markdown, $verbatim, $desc, %opts) = @_;
  convert_ok("B<< $pod >>", $markdown,  "$desc: inline html escaped", %opts);
  convert_ok("C<< $pod >>", qq{`$verbatim`}, "$desc: html not escaped in code span", %opts);
}

my %_escape   = Pod::Markdown::__escape_sequences;

# This was an actual bug report.
entity_encode_ok 'command lines args' => (
  q{--file=<filename>},
  q{**--file=&lt;filename>**},
);

# Use real html tags.
# This is a good example to copy/paste into a markdown processor
# to see how it handles the html.
# For example, github respects "\<" and "\&" but daringfireball does not.
# That's why we use html entity encoding (more portable).
entity_encode_ok 'real html' => (
  q{h&nbsp;=<hr>},
  q{**h&amp;nbsp;=&lt;hr>**},
);

# Test with 'false' values to avoid conditional bugs.
# In this case a bare zero won't trigger the need for an escape.
entity_encode_ok 'false values' => (
  q{<0 &0},
  q{**<0 &0**},
);

# Ensure that two pod "strings" still escape the < and & properly.
# Use S<> since it counts as an event (and therefore creates two separate
# "handle_text" calls) but does not produce boundary characters (the text
# inside and around the S<> will have no characters between them).
entity_encode_ok '< and & are escaped properly even as separate pod strings' => (
  q{the <S<cmp>E<gt> operator and S<&>foobar; (or S<&>fooS<bar>;) and eol &},
  q{**the &lt;cmp> operator and &amp;foobar; (or &amp;foobar;) and eol &**},
  verbatim => q{the <cmp> operator and &foobar; (or &foobar;) and eol &},
);

# Don't undo it for literal ones that happen to be at the end of strings.
entity_encode_ok 'literal entity from pod at end of string stays amp-escaped' => (
  q{literal &amp; and &lt;},
  q{**literal &amp;amp; and &amp;lt;**},
);

entity_encode_ok 'field splitting: amps at beginning and end and multiple in the middle' => (
  q{& ity &&& and &},
  q{**& ity &&& and &**},
);

entity_encode_ok 'literal occurrences of internal escape sequences are unaltered' => (
  qq[hi $_escape{amp} ($_escape{amp_code}) & $_escape{lt} ($_escape{lt_code}) < &exclam;],
  qq[**hi $_escape{amp} ($_escape{amp_code}) & $_escape{lt} ($_escape{lt_code}) < &amp;exclam;**],
);

sub so_example {
  # Test case from http://stackoverflow.com/questions/28496298/escape-angle-brackets-using-podmarkdown {
  my $str = "=head1 OPTIONS\n\n=over 4\n\n=item B<< --file=<filename> >>\n\nFile name \n\n=back\n";
  my $parser = Pod::Markdown->new;
  my $markdown;
  $parser->output_string( \$markdown );
  $parser->parse_string_document($str);
  # }
  return $markdown;
}

eq_or_diff so_example(), "# OPTIONS\n\n- **--file=&lt;filename>**\n\n    File name \n",
  'SO example properly escaped';

convert_ok(<<POD,
=head2 hi <there> &you; < &

=over

=item & some < t&e;xt

<paragraph>

=back

=over

=item 1.

item <text> < &

<para>

=back
POD
  <<MKDN,
## hi &lt;there> &amp;you; < &

- & some < t&amp;e;xt

    &lt;paragraph>

1. item &lt;text> < &

    &lt;para>
MKDN
  'escape entities in lists and items properly',
);


done_testing;
