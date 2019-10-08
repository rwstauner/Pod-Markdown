# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use utf8;
use strict;
use warnings;
use lib 't/lib';
use MarkdownTests;

my $pod_prefix = test_parser()->perldoc_url_prefix;

sub code {
  my ($pod, $exp, %opts) = @_;
  my $desc = delete $opts{desc} || $pod;
  my %args = (
    init => delete($opts{init}),
  );

  convert_code_ok($pod, $exp, $desc, {}, %args);

  if( my $ents = delete $opts{entities} ){
    # Use the same value for both if only one is specified.
    $ents->[1] = $ents->[0] if @$ents == 1;
    with_and_without_entities {
      my $e = $ents->[ $_[0] ? 0 : 1 ];
      convert_code_ok($pod, $e, $desc, {
        html_encode_chars => '^\x20-\x7e', # most chars
      }, %args);
    };
  }

  if( my $utf8 = delete $opts{utf8} ){
    convert_code_ok($pod, $utf8, $desc, { output_encoding => 'UTF-8' }, %args);
  }

  die "Invalid args: %opts" if keys %opts;
}

sub convert_code_ok {
  my ($pod, $exp, $desc, $attr, %opts) = @_;
  convert_ok($pod, $exp, $desc, %opts, attr => $attr, verbose => 1,
    # Prefix line to avoid escaping beginning-of-line characters (like `>`).
    prefix  => 'Code: ',
  );
}

code 'I<italic>',   '_italic_';
code 'B<bold>',     '**bold**';
code 'C<code>',     '`code`';
code 'C<c*de>',     '`c*de`';

# Links tested extensively in t/links.t.
code 'L<link>',     "[link](${pod_prefix}link)";
code 'L<star*>',    "[star\\*](${pod_prefix}star%2A)";

# Pod::Simple handles the E<> entirely (Pod::Markdown never sees them).
code 'E<lt>',       '<';
code 'E<gt>',       '>';
code 'E<verbar>',   '|';
code 'E<sol>',      '/';

code 'E<copy>',     '©', entities => ['&copy;'],   utf8 => "\xc2\xa9";

code 'E<eacute>',   'é', entities => ['&eacute;', '&#xE9;'], utf8 => "\xc3\xa9";

code 'E<0x201E>',   '„', entities => ['&bdquo;', '&#x201E;'],  desc => 'E hex';

code 'E<075>',      '=', desc => 'E octal';
code 'E<0241>',     '¡', entities => ['&iexcl;', '&#xA1;'],  utf8 => "\xc2\xa1", desc => 'E octal';

code 'E<181>',      'µ', entities => ['&micro;', '&#xB5;'],  desc => 'E decimal';

# Legacy charnames specifically mentioned by perlpodspec.
code 'E<lchevron>', '«', entities => ['&laquo;', '&#xAB;'],  utf8 => "\xc2\xab";
code 'E<rchevron>', '»', entities => ['&raquo;', '&#xBB;'],  utf8 => "\xc2\xbb";

# Translate F<> as code spans.
code 'F<file.ext>',        '`file.ext`';
code 'F<file_path.ext>',   '`file_path.ext`';
code 'F</weird/file`path`>',   '`` /weird/file`path` ``';

# S<> for non-breaking spaces.
code 'S<$x ? $y : $z>',    '$x ? $y : $z', # Literal NBSP chars.
  # Entity-encode nbsp (whether we have HTML::Entities or not).
  entities => ['$x&nbsp;?&nbsp;$y&nbsp;:&nbsp;$z'];

code 'S<C<$x & $y>>', '`$x & $y`', # Literal NBSP chars.
  # Amps inside code spans will get escaped, so leave nsbp bare.
  entities => ['`$x & $y`'];

code 'S<$x C<& $y>>', '$x `& $y`', # Just spaces.
  entities => ['$x `& $y`'],
  init => sub { $_[0]->nbsp_for_S(0) };

# Zero-width entries.
code 'X<index>', '';
code 'Z<>',      '';

# Pod::Simple swallows unknown codes.
#code 'Q<unknown>', 'Q<unknown>', desc => 'uknown code (Q<>)';

done_testing;
