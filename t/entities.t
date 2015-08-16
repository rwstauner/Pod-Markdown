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

  # Encoding some entities (but not [&<]) should produce the same as none.
  convert_both($pod, $markdown, $verbatim, "$desc (html_encode_chars => non ascii)",
    attr => {html_encode_chars => '\x80-\xff'});

  # Encoding [&<] will produce more of those chars.
  convert_both($pod, $opts{entities}, $verbatim, "$desc (html_encode_chars => 1)",
    attr => {html_encode_chars => 1}) if $opts{entities};
}

sub convert_both {
  my ($pod, $markdown, $verbatim, $desc, %opts) = @_;
  convert_ok("B<<< $pod >>>", $markdown,  "$desc: inline html escaped", %opts);
  convert_ok("C<<< $pod >>>", qq{`$verbatim`}, "$desc: html not escaped in code span", %opts);
}

my %_escape   = Pod::Markdown::__escape_sequences;
my %_e_escape = do {
  my $parser = Pod::Markdown->new(html_encode_chars => 1);
  map { ($_ => $parser->encode_entities($_escape{$_})) } keys %_escape;
};

like $_e_escape{amp}, qr/&amp;/, 'entity-encoded escape sanity check';

with_and_without_entities {
  my $char = $_[0] ? '&bull;' : '&#x2022;';
  entity_encode_ok 'sanity check' => (
    q{< & > E<0x2022>},
    q{**< & > •**},
    entities => "**&lt; &amp; &gt; ${char}**",
    verbatim => q{< & > •},
  );
};


# This was an actual bug report.
entity_encode_ok 'command lines args' => (
  q{--file=<filename>},
  q{**--file=&lt;filename>**},
  entities => q{**--file=&lt;filename&gt;**},
);

# Use real html tags.
# This is a good example to copy/paste into a markdown processor
# to see how it handles the html.
# For example, github respects "\<" and "\&" but daringfireball does not.
# That's why we use html entity encoding (more portable).
entity_encode_ok 'real html' => (
  q{h&nbsp;=<hr>},
  q{**h&amp;nbsp;=&lt;hr>**},
  entities => q{**h&amp;nbsp;=&lt;hr&gt;**},
);


# Test link text.
entity_encode_ok 'html chars in link text' => (
  q{L<< Some &amp; <thing>|http://some.where/ >>},
  q{**[Some &amp;amp; &lt;thing>](http://some.where/)**},
  entities => q{**[Some &amp;amp; &lt;thing&gt;](http://some.where/)**},
  # Markdown will print this rather than making it a link,
  # but I'm not sure what else to do about it.
  verbatim => q{[Some &amp; <thing>](http://some.where/)},
);

entity_encode_ok 'html chars in url' => (
  # This may not be a valid url but let this test demonstrate how it currently works.
  q{L<< Yo|http://some.where?a=&amp;&lt=<tag> >>},
  q{**[Yo](http://some.where?a=&amp;&lt=<tag>)**},
  # Same as above (shrug).
  verbatim => q{[Yo](http://some.where?a=&amp;&lt=<tag>)},
);


# Test with 'false' values to avoid conditional bugs.
# In this case a bare zero won't trigger the need for an escape.
entity_encode_ok 'false values' => (
  q{<0 &0},
  q{**<0 &0**},
  entities => q{**&lt;0 &amp;0**},
);

# Ensure that two pod "strings" still escape the < and & properly.
# Use S<> since it counts as an event (and therefore creates two separate
# "handle_text" calls) but does not produce boundary characters (the text
# inside and around the S<> will have no characters between them).
entity_encode_ok '< and & are escaped properly even as separate pod strings' => (
  q{the <S<cmp>E<gt> operator and S<&>foobar; (or S<&>fooS<bar>;) and eol &},
  q{**the &lt;cmp> operator and &amp;foobar; (or &amp;foobar;) and eol &**},
  entities => q{**the &lt;cmp&gt; operator and &amp;foobar; (or &amp;foobar;) and eol &amp;**},
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
  entities => q{**&amp; ity &amp;&amp;&amp; and &amp;**},
);

entity_encode_ok 'literal occurrences of internal escape sequences are unaltered' => (
  qq[hi $_escape{amp} ($_escape{amp_code}) & $_escape{lt} ($_escape{lt_code}) < &exclam;],
  qq[**hi $_escape{amp} ($_escape{amp_code}) & $_escape{lt} ($_escape{lt_code}) < &amp;exclam;**],
  entities => qq[**hi $_e_escape{amp} ($_e_escape{amp_code}) &amp; $_e_escape{lt} ($_e_escape{lt_code}) &lt; &amp;exclam;**],
);


sub so_example {
  # Test case from http://stackoverflow.com/questions/28496298/escape-angle-brackets-using-podmarkdown {
  my $str = "=head1 OPTIONS\n\n=over 4\n\n=item B<< --file=<filename> >>\n\nFile name \n\n=back\n";
  my $parser = Pod::Markdown->new(@_); # (@_) - rwstauner
  my $markdown;
  $parser->output_string( \$markdown );
  $parser->parse_string_document($str);
  # }
  return $markdown;
}

eq_or_diff so_example(), "# OPTIONS\n\n- **--file=&lt;filename>**\n\n    File name \n",
  'SO example properly escaped';

eq_or_diff so_example(html_encode_chars => 1), "# OPTIONS\n\n- **--file=&lt;filename&gt;**\n\n    File name \n",
  'SO example with additional escapes';

my $list_pod = <<POD;
=head2 hi <there> &you; < &

=over

=item & some < t&e;xt

<paragraph>

<

&

=back

=over

=item 1.

item <text> < &

<para>

=back
POD

convert_ok($list_pod, <<MKDN,
## hi &lt;there> &amp;you; < &

- & some < t&amp;e;xt

    &lt;paragraph>

    <

    &

1. item &lt;text> < &

    &lt;para>
MKDN
 'escape entities in lists and items properly',
);

convert_ok($list_pod, <<MKDN,
## hi &lt;there&gt; &amp;you; &lt; &amp;

- &amp; some &lt; t&amp;e;xt

    &lt;paragraph&gt;

    &lt;

    &amp;

1. item &lt;text&gt; &lt; &amp;

    &lt;para&gt;
MKDN
 'escape all entities in lists and items',
 attr => { html_encode_chars => 1 }
);

done_testing;
