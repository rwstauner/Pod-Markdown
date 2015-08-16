# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use lib 't/lib';
use MarkdownTests;

# NOTE: All strings in this test file are byte-strings.
no utf8;

sub test_encoding {
  my ($enc, $pod, %opts) = @_;
  my $desc = delete $opts{desc} || hex_escape $pod;

  foreach my $outenc ( keys %opts ){
    convert_encodings($pod, $opts{$outenc}, $enc, $outenc, $desc);
  }
}

sub convert_encodings {
  my ($pod, $exp, $enc, $outenc, $desc) = @_;
  convert_ok($pod, $exp, $desc,
    attr     => $outenc =~ /match(?:_(\w+))?/ ? { match_encoding => 1, output_encoding => $1||'' } : { output_encoding => $outenc },
    prefix   => ".",
    encoding => $enc,
    init     => sub {
      # Ignore errors about high-bit chars without =encoding.
      $_[0]->no_errata_section(1) if !$enc || $enc =~ /invalid/;
    },
    verbose => 1,
  );
}

# Pod::Simple defaults to cp1252 (previously latin1) without an =encoding.
with_and_without_entities {
  my $char = $_[0] ? '&Agrave;' : '&#xC0;';

  foreach my $enc ( 'latin1', 'cp1252', '' ){
    test_encoding( $enc => "\xc0",
      utf8     => "\xc3\x80",
      latin1   => "\xc0",
      ascii    => $char,
    );
  }
};

with_and_without_entities {
  my $bullet = $_[0] ? '&bull;' : '&#x2022;';

  test_encoding( cp1252 => "\x95",
    utf8     => "\xe2\x80\xa2",
    match    => "\x95",
    (map { ($_ => $bullet) } qw(latin1 ascii)),
  );
};

with_and_without_entities {
  my $currency = $_[0] ? '&curren;' : '&#xA4;';

  test_encoding( latin1 => "\xa4",
    match    => "\xa4",
    utf8     => "\xc2\xa4",
    ascii    => $currency,
  );

  test_encoding( "utf-8" => "\xc2\xa4",
    match    => "\xc2\xa4",
    latin1   => "\xa4",
    ascii    => $currency,
  );
};

foreach my $enc ( '', 'invalid' ){
  my $utf8 = "\xc2\xa9 a\xc2\xa0b";
  test_encoding( $enc => 'E<copy> S<a b>',
    match_ascii => '&copy; a&nbsp;b',
    latin1      => "\xa9 a\xa0b",
    utf8        => $utf8,
    match_utf8  => $utf8,
    match       => $utf8,
    desc        => 'ascii; ' . ($enc ? '' : 'no =encoding; ') . 'pod escapes generate non-ascii',
  );
}

{
  # Verify that output_encoding => 'ascii' (even with match_encoding) is not safe.
  # > Inside Markdown code spans and blocks, angle brackets and ampersands are always encoded automatically.
  # Therefore we cannot use html entities to encode high-bit chars; they must be output literally.
  # It is possible with pod to embed non-ascii characters in a code span without
  # using literal high-bit characters (so there will be no detected_encoding).

  my $pod = "=pod\n\nC<< a E<0x2022> bullet >>\n";

  my $test = sub {
    my $p = Pod::Markdown->new(@_);
    $p->output_string(\my $markdown);
    $p->parse_string_document($pod);
    chomp $markdown;

    ok !$p->detected_encoding, 'no encoding detected';

    return $markdown;
  };

  eq_or_diff $test->(output_encoding => 'UTF-8'),
    "`a \xe2\x80\xa2 bullet`",
    'high-bit char UTF-8 encoded in code span';

  # Without specifying encoding a character string is returned.
  eq_or_diff $test->(),
    "`a \x{2022} bullet`",
    'high-bit char embedded in code span (character string)';
}

done_testing;
