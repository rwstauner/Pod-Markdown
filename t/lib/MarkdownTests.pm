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
    io_string
    eq_or_diff
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

sub convert_ok {
  my ($pod, $exp, $desc, @args) = @_;
  my $parser = Pod::Markdown->new;
  my $after = (@args % 2 && ref($args[-1]) eq 'CODE') ? pop @args : 0;

  $after->($parser) if $after;

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

1;
