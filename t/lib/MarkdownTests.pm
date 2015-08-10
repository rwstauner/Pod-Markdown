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
    have_entities_or
    hex_escape
    io_string
    eq_or_diff
    warning
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

sub have_entities_or {
  $Pod::Markdown::HAS_HTML_ENTITIES ? $_[0] : $_[1];
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

sub convert_ok {
  my ($pod, $exp, $desc, %opts) = @_;
  my %attr   = %{ $opts{attr} || {} };
  my $parser = Pod::Markdown->new(%attr);

  if( $opts{verbose} ){
    $desc .= " \t" . hex_escape "($pod => $exp)";
    $desc .= join ' ', ' (', %attr, ')' if keys %attr;
  }

  diag_xml($pod)  if $opts{diag_xml};
  diag_text($pod) if $opts{diag_text};

  $opts{init}->($parser) if $opts{init};

  $parser->output_string(\(my $got));
  $parser->parse_string_document("=pod\n\n$pod\n\n=cut\n");

  chomp for ($got, $exp);

  eq_or_diff($got, $exp, $desc);
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

# Similar interface to Test::Fatal;
sub warning (&) { ## no critic (Prototypes)
  my @warnings;
  local $SIG{__WARN__} = sub { push @warnings, $_[0] };
  $_[0]->();
  pop @warnings;
}

1;
