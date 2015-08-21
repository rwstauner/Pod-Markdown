use strict;
use warnings;

package Pod::Perldoc::ToMarkdown;

# ABSTRACT: Enable `perldoc -o Markdown`

use parent qw(Pod::Markdown);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    # Pod::Perldoc does not pass any options by default
    # but will call setters if attributes are passed on command line.
    # I don't know what encoding it expects, but it needs one, so default to UTF-8.
    output_encoding => 'UTF-8',
    @_,
  );
  return $self;
}

sub parse_from_file {
  my $self = shift;
  # Instantiate if called as a class method.
  $self = $self->new if !ref $self;

  # Skip over SUPER's override and go up to grandpa's method.
  $self->Pod::Simple::parse_from_file(@_);
}

# There are several other methods that we could implement that Pod::Perldoc
# finds interesting:
# * output_is_binary
# * name
# * output_extension

1;

=for test_synopsis
1;
__END__

=head1 SYNOPSIS

  perldoc -o Markdown Some::Module

=head1 DESCRIPTION

Pod::Perldoc expects a Pod::Parser compatible module,
however Pod::Markdown did not historically provide an entirely Pod::Parser
compatible interface.

This module bridges the gap.

=cut
