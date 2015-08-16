use strict;
use warnings;

package # no_index
  MarkdownTests;

use Test::More 0.88;  # done_testing
use Test::Differences;
use Pod::Markdown ();

use Exporter ();
our @ISA = qw(Exporter);
our @EXPORT = (
  qw(
    convert_ok
    hex_escape
    io_string
    eq_or_diff
    slurp_file
    test_parser
    warning
    with_and_without_entities
  ),
  @Test::More::EXPORT
);

sub import {
  my $class = shift;
  Test::More::plan(@_) if @_;
  @_ = ($class);
  strict->import;
  warnings->import;
  goto &Exporter::import;
}

sub hex_escape {
  local $_ = $_[0];
  s/([^\x20-\x7e])/sprintf "\\x{%x}", ord $1/ge;
  return $_;
}

sub diag_xml {
  diag_with('Pod::Simple::DumpAsXML', @_);
}

sub diag_text {
  diag_with('Pod::Simple::DumpAsText', @_);
}

sub diag_with {
  my ($class, $pod) = @_;
  $class =~ /[^a-zA-Z0-9:]/ and die "Invalid class name '$class'";
  eval "require $class" or die $@;
  my $parser = $class->new;
  $parser->output_string(\(my $got));
  $parser->parse_string_document("=pod\n\n$pod\n");
  diag $got;
}

sub hash_string {
  my $h = $_[0];
  return join ', ', map { "$_: $h->{$_}" } sort keys %$h;
}

sub convert_ok {
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  my ($pod, $exp, $desc, %opts) = @_;
  my %attr   = %{ $opts{attr} || {} };
  my $parser = test_parser(%attr);
  my $prefix = $opts{prefix} || '';
  my $podenc = ($opts{encoding} ? "=encoding $opts{encoding}\n\n" : '');

  if( $opts{verbose} ){
    $desc .= " \t" . hex_escape "($pod => $exp)";
    $desc .= join ' ', ' (', hash_string(\%attr), ')' if keys %attr;
    $desc .= " =encoding $opts{encoding}" if $podenc;
  }

  diag_xml($pod)  if $opts{diag_xml};
  diag_text($pod) if $opts{diag_text};

  $opts{init}->($parser) if $opts{init};

  $parser->output_string(\(my $got));
  $parser->parse_string_document("$podenc=pod\n\n$prefix$pod\n\n=cut\n");

  # Chomp both ends.
  for ($got, $exp) {
    s/^\n+//;
    s/\n+$//;
  }

  eq_or_diff($got, $prefix.$exp, $desc);
}

sub test_parser {
  Pod::Markdown->new(
    # Default to very simple values for simple tests.
    perldoc_url_prefix       => 'pod://',
    # Just return the raw fragment so we know that it isn't unexpectedly mangled.
    perldoc_fragment_format  => sub { $_ },
    markdown_fragment_format => sub { $_ },
    @_
  );
}

{ package # no_index
    MarkdownTests::IOString;
  use Symbol ();
  sub new {
    my $class = ref($_[0]) || $_[0];
    my $s = $_[1];
    my $self = Symbol::gensym;
    tie *$self, $class, $self;
    *$self->{lines} = [map { "$_\n" } split /\n/, $s ];
    $self;
  }
  sub READLINE { shift @{ *{$_[0]}->{lines} } }
  sub TIEHANDLE {
    my ($class, $s) = @_;
    bless $s, $class;
  }
  { no warnings 'once'; *getline = \&READLINE; }
}

sub io_string {
  MarkdownTests::IOString->new(@_);
}

sub slurp_file {
  my $path = shift;
  open(my $fh, '<', $path)
    or die "Failed to open $path: $!";
  slurp_fh($fh)
}
sub slurp_fh { my $fh = shift; local $/; <$fh>; }

# Similar interface to Test::Fatal;
sub warning (&) { ## no critic (Prototypes)
  my @warnings;
  local $SIG{__WARN__} = sub { push @warnings, $_[0] };
  $_[0]->();
  pop @warnings;
}

sub with_and_without_entities (&) { ## no critic (Prototypes)
  SKIP: for my $ents ( 0, 1 ){
    if( $ents && ! $Pod::Markdown::HAS_HTML_ENTITIES ){
      skip 'HTML::Entities required for this test', 1;
    }
    local $Pod::Markdown::HAS_HTML_ENTITIES = $ents;
    $_[0]->($ents);
  }
}

1;
