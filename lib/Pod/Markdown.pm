# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use 5.008;
use strict;
use warnings;

package Pod::Markdown;
# ABSTRACT: Convert POD to Markdown

use Pod::Simple 3.14 (); # external links with text
use parent qw(Pod::Simple::Methody);

our %URL_PREFIXES = (
  sco      => 'http://search.cpan.org/perldoc?',
  metacpan => 'https://metacpan.org/pod/',
  man      => 'http://man.he.net/man',
);
$URL_PREFIXES{perldoc} = $URL_PREFIXES{metacpan};

=method new

  Pod::Markdown->new(%options);

The constructor accepts the following named arguments:

=begin :list

* C<man_url_prefix>
Alters the man page urls that are created from C<< LE<lt>E<gt> >> codes.

The default is C<http://man.he.net/man>.

* C<perldoc_url_prefix>
Alters the perldoc urls that are created from C<< LE<lt>E<gt> >> codes.
Can be:

=for :list
* C<metacpan> (shortcut for C<https://metacpan.org/pod/>)
* C<sco> (shortcut for C<http://search.cpan.org/perldoc?>)
* any url

The default is C<metacpan>.

    Pod::Markdown->new(perldoc_url_prefix => 'http://localhost/perl/pod');

* C<perldoc_fragment_format>
Alters the format of the url fragment for any C<< LE<lt>E<gt> >> links
that point to a section of an external document (C<< L<name/section> >>).
The default will be chosen according to the destination L</perldoc_url_prefix>.
Alternatively you can specify one of the following:

=for :list
* C<metacpan>
* C<sco>
* C<pod_simple_xhtml>
* C<pod_simple_html>
* A code ref

The code ref can expect to receive two arguments:
the parser object (C<$self>) and the section text.
For convenience the topic variable (C<$_>) is also set to the section text:

  perldoc_fragment_format => sub { s/\W+/-/g; }

* C<markdown_fragment_format>
Alters the format of the url fragment for any C<< LE<lt>E<gt> >> links
that point to an internal section of this document (C<< L</section> >>).

Unfortunately the format of the id attributes produced
by whatever system translates the markdown into html is unknown at the time
the markdown is generated so we do some simple clean up.

B<Note:> C<markdown_fragment_format> and C<perldoc_fragment_format> accept
the same values: a (shortcut to a) method name or a code ref.

* C<include_meta_tags>
Specifies whether or not to print author/title meta tags at the top of the document.
Default is false.

=end :list

=cut

sub new {
  my $class = shift;
  my %args = @_;

  my $self = $class->SUPER::new();
  $self->preserve_whitespace(1);
  $self->accept_targets(qw( markdown html ));

  my $data = $self->_private;
  while( my ($attr, $val) = each %args ){
    $data->{ $attr } = $val;
  }

    for my $type ( qw( perldoc man ) ){
        my $attr  = $type . '_url_prefix';
        # Use provided argument or default alias.
        my $url = $self->$attr || $type;
        # Expand alias if defined (otherwise use url as is).
        $data->{ $attr } = $URL_PREFIXES{ $url } || $url;
    }

    $self->_prepare_fragment_formats;

  return $self;
}

## Attribute accessors ##

=method man_url_prefix

Returns the url prefix in use for man pages.

=method perldoc_url_prefix

Returns the url prefix in use (after resolving shortcuts to urls).

=method perldoc_fragment_format

Returns the coderef or format name used to format a url fragment
to a section in an external document.

=method markdown_fragment_format

Returns the coderef or format name used to format a url fragment
to an internal section in this document.

=method include_meta_tags

Returns the boolean value indicating
whether or not meta tags will be printed.

=cut

my @attr = qw(
  man_url_prefix
  perldoc_url_prefix
  perldoc_fragment_format
  markdown_fragment_format
  include_meta_tags
);

{
  no strict 'refs'; ## no critic
  foreach my $attr ( @attr ){
    *$attr = sub { return $_[0]->_private->{ $attr } };
  }
}

sub _prepare_fragment_formats {
  my ($self) = @_;

  foreach my $attr ( @attr ){
    next unless $attr =~ /^(\w+)_fragment_format/;
    my $type = $1;
    my $format = $self->$attr;

    # If one was provided.
    if( $format ){
      # If the attribute is a coderef just use it.
      next if ref($format) eq 'CODE';
    }
    # Else determine a default.
    else {
      if( $type eq 'perldoc' ){
        # Choose a default that matches the destination url.
        my $target = $self->perldoc_url_prefix;
        foreach my $alias ( qw( metacpan sco ) ){
          if( $target eq $URL_PREFIXES{ $alias } ){
            $format = $alias;
          }
        }
        # This seems like a reasonable fallback.
        $format ||= 'pod_simple_xhtml';
      }
      else {
        $format = $type;
      }
    }

    # The short name should become a method name with the prefix prepended.
    my $prefix = 'format_fragment_';
    $format =~ s/^$prefix//;
    die "Unknown fragment format '$format'"
      unless $self->can($prefix . $format);

    # Save it.
    $self->_private->{ $attr } = $format;
  }

  return;
}

## Backward compatible API ##

# For backward compatibility (previously based on Pod::Parser):
# While Pod::Simple provides a parse_from_file() method
# it's primarily for Pod::Parser compatibility.
# When called without an output handle it will print to STDOUT
# but the old Pod::Markdown never printed to a handle
# so we don't want to start now.
sub parse_from_file {
  my ($self, $file) = @_;
  $self->output_string(\($self->{_as_markdown_}));
  $self->parse_file($file);
}

# Likewise, though Pod::Simple doesn't define this method at all.
sub parse_from_filehandle { shift->parse_from_file(@_) }

=for Pod::Coverage
parse_from_file
parse_from_filehandle

=cut

## Document state ##

sub _private {
  my ($self) = @_;
  $self->{_Pod_Markdown_} ||= {
    indent      => 0,
    stacks      => [],
    states      => [{}],
    link        => [],
  };
}

sub _increase_indent {
  ++$_[0]->_private->{indent} >= 1
    or die 'Invalid state: indent < 0';
}
sub _decrease_indent {
  --$_[0]->_private->{indent} >= 0
    or die 'Invalid state: indent < 0';
}

sub _new_stack {
  push @{ $_[0]->_private->{stacks} }, [];
  push @{ $_[0]->_private->{states} }, {};
}

sub _last_string {
  $_[0]->_private->{stacks}->[-1][-1];
}

sub _pop_stack_text {
  $_[0]->_private->{last_state} = pop @{ $_[0]->_private->{states} };
  join '', @{ pop @{ $_[0]->_private->{stacks} } };
}

sub _stack_state {
  $_[0]->_private->{states}->[-1];
}

sub _save {
  my ($self, $text) = @_;
  push @{ $self->_private->{stacks}->[-1] }, $text;
  # return $text; # DEBUG
}

sub _save_line {
  my ($self, $text) = @_;
  $self->_save($text . $/);
}

# For paragraphs, etc.
sub _save_block {
  my ($self, $text) = @_;

  $self->_stack_state->{blocks}++;

  $self->_save_line($self->_indent($text) . $/);
}

## Formatting ##

sub _chomp_all {
  my ($self, $text) = @_;
  1 while chomp $text;
  return $text;
}

sub _indent {
  my ($self, $text) = @_;
  my $level = $self->_private->{indent};

  if( $level ){
    my $indent = ' ' x ($level * 4);

    # Capture text on the line so that we don't indent blank lines (/^\x20{4}$/).
    $text =~ s/^(.+)/$indent$1/mg;
  }

  return $text;
}

=method as_markdown

Returns the parsed POD as Markdown. Takes named arguments. If the C<with_meta>
argument is given a positive value, meta tags are generated as well.

=cut

sub as_markdown {
    my ($parser, %args) = @_;
    my @header;
    # Don't add meta tags again if we've already done it.
    if( $args{with_meta} && !$parser->include_meta_tags ){
        @header = $parser->_build_markdown_head;
    }
    return join("\n" x 2, @header, $parser->{_as_markdown_});
}

sub _build_markdown_head {
    my $parser    = shift;
    my $data      = $parser->_private;
    return join "\n",
        map  { qq![[meta \l$_="$data->{$_}"]]! }
        grep { defined $data->{$_} }
        qw( Title Author );
}

## Escaping ##

# http://daringfireball.net/projects/markdown/syntax#backslash
# Markdown provides backslash escapes for the following characters:
#
# \   backslash
# `   backtick
# *   asterisk
# _   underscore
# {}  curly braces
# []  square brackets
# ()  parentheses
# #   hash mark
# +   plus sign
# -   minus sign (hyphen)
# .   dot
# !   exclamation mark

# However some of those only need to be escaped in certain places:
# * Backslashes *do* need to be escaped or they may be swallowed by markdown.
# * Word-surrounding characters (/[`*_]/) *do* need to be escaped mid-word
# because the markdown spec explicitly allows mid-word em*pha*sis.
# * I don't actually see anything that curly braces are used for.
# * Escaping square brackets is enough to avoid accidentally
# creating links and images (so we don't need to escape plain parentheses
# or exclamation points as that would generate a lot of unnecesary noise).
# Parentheses will be escaped in urls (&end_L) to avoid premature termination.
# * We don't need a backslash for every hash mark or every hyphen found mid-word,
# just the ones that start a line (likewise for plus and dot).
# (Those will all be handled by _escape_paragraph_markdown).

# Backslash escape markdown characters to avoid having them interpreted.
sub _escape_inline_markdown {
  local $_ = $_[1];

# s/([\\`*_{}\[\]()#+-.!])/\\$1/g; # See comments above.
  s/([\\`*_\[\]])/\\$1/g;

  return $_;
}

# Escape markdown characters that would be interpreted
# at the start of a line.
sub _escape_paragraph_markdown {
    local $_ = $_[1];

    # Escape headings, horizontal rules, (unordered) lists, and blockquotes.
    s/^([-+*#>])/\\$1/mg;

    # Markdown doesn't support backslash escapes for equal signs
    # even though they can be used to underline a header.
    # So use html to escape them to avoid having them interpreted.
    s/^([=])/sprintf '&#x%x;', ord($1)/mge;

    # Escape the dots that would wrongfully create numbered lists.
    s/^( (?:>\s+)? \d+ ) (\.\x20)/$1\\$2/xgm;

    return $_;
}

## Parsing ##

sub handle_text {
  my ($self, $text) = @_;

  # Markdown is for html, so use html entities.
  $text =~ s/ /&nbsp;/g
    if $self->_private->{nbsp};

  # Unless we're in a code span or verbatim block.
  unless( $self->_private->{no_escape} ){

    # We could, in theory, alter what gets escaped according to context
    # (for example, escape square brackets (but not parens) inside link text).
    # The markdown produced might look slightly nicer but either way you're
    # at the whim of the markdown processor to interpret things correctly.
    # For now just escape everything.

    # Don't let literal characters be interpreted as markdown.
    $text = $self->_escape_inline_markdown($text);

  }

  $self->_save($text);
}

sub start_Document {
  my ($self) = @_;
  $self->_new_stack;
}

sub   end_Document {
  my ($self) = @_;
  $self->_check_search_header;
  my $end = pop @{ $self->_private->{stacks} };

  @{ $self->_private->{stacks} } == 0
    or die 'Document ended with stacks remaining';

  my @doc = $self->_chomp_all(join('', @$end)) . $/;

  if( $self->include_meta_tags ){
    unshift @doc, $self->_build_markdown_head, ($/ x 2);
  }

  print { $self->{output_fh} } @doc;
}

## Blocks ##

sub start_Verbatim {
  my ($self) = @_;
  $self->_new_stack;
  $self->_private->{no_escape} = 1;
}

sub end_Verbatim {
  my ($self) = @_;

  my $text = $self->_pop_stack_text;

  $text = $self->_indent_verbatim($text);

  $self->_private->{no_escape} = 0;

  # Verbatim blocks do not generate a separate "Para" event.
  $self->_save_block($text);
}

sub _indent_verbatim {
  my ($self, $paragraph) = @_;

    # NOTE: Pod::Simple expands the tabs for us (as suggested by perlpodspec).
    # Pod::Simple also has a 'strip_verbatim_indent' attribute
    # but it doesn't sound like it gains us anything over this method.

    # POD verbatim can start with any number of spaces (or tabs)
    # markdown should be 4 spaces (or a tab)
    # so indent any paragraphs so that all lines start with at least 4 spaces
    my @lines = split /\n/, $paragraph;
    my $indent = ' ' x 4;
    foreach my $line ( @lines ){
        next unless $line =~ m/^( +)/;
        # find the smallest indentation
        $indent = $1 if length($1) < length($indent);
    }
    if( (my $smallest = length($indent)) < 4 ){
        # invert to get what needs to be prepended
        $indent = ' ' x (4 - $smallest);

        # Prepend indent to each line.
        # We could check /\S/ to only indent non-blank lines,
        # but it's backward compatible to respect the whitespace.
        # Additionally, both pod and markdown say they ignore blank lines
        # so it shouldn't hurt to leave them in.
        $paragraph = join "\n", map { length($_) ? $indent . $_ : '' } @lines;
    }

  return $paragraph;
}

sub start_Para {
  $_[0]->_new_stack;
}

sub   end_Para {
  my ($self) = @_;
  my $text = $self->_pop_stack_text;

  $text = $self->_escape_paragraph_markdown($text);

  $self->_save_block($text);
}


## Headings ##

sub start_head1 { $_[0]->_start_head(1) }
sub   end_head1 { $_[0]->_end_head(1) }
sub start_head2 { $_[0]->_start_head(2) }
sub   end_head2 { $_[0]->_end_head(2) }
sub start_head3 { $_[0]->_start_head(3) }
sub   end_head3 { $_[0]->_end_head(3) }
sub start_head4 { $_[0]->_start_head(4) }
sub   end_head4 { $_[0]->_end_head(4) }

sub _check_search_header {
  my ($self) = @_;
  # Save the text since the last heading if we want it for metadata.
  if( my $last = $self->_private->{search_header} ){
    for( $self->_private->{$last} = $self->_last_string ){
      s/\A\s+//;
      s/\s+\z//;
    }
  }
}
sub _start_head {
  my ($self) = @_;
  $self->_check_search_header;
  $self->_new_stack;
}

sub   _end_head {
  my ($self, $num) = @_;
  my $h = '#' x $num;

  my $text = $self->_pop_stack_text;
  $self->_private->{search_header} =
      $text =~ /NAME/   ? 'Title'
    : $text =~ /AUTHOR/ ? 'Author'
    : undef;

  # TODO: option for $h suffix
  # TODO: put a name="" if $self->{embed_anchor_tags}; ?
  # https://rt.cpan.org/Ticket/Display.html?id=57776
  $self->_save_block(join(' ', $h, $text));
}

## Lists ##

# TODO: over_empty

sub _start_list {
  my ($self) = @_;
  $self->_new_stack;

  # Nest again b/c start_item will pop this to look for preceding content.
  $self->_increase_indent;
  $self->_new_stack;
}

sub   _end_list {
  my ($self) = @_;
  $self->_handle_between_item_content;

  # Finish the list.

  # All the child elements should be blocks,
  # but don't end with a double newline.
  my $text = $self->_chomp_all($self->_pop_stack_text);

  # FIXME:
  $_[0]->_save_line($text . $/);
}

sub _handle_between_item_content {
  my ($self) = @_;

  # This might be empty (if the list item had no additional content).
  if( my $text = $self->_pop_stack_text ){
    # Else it's a sub-document.
    # If there are blocks we need to separate with blank lines.
    if( $self->_private->{last_state}->{blocks} ){
      $text = $/ . $text;
    }
    # If not, we can condense the text.
    # In this module's history there was a patch contributed to specifically
    # produce "huddled" lists so we'll try to maintain that functionality.
    else {
      $text = $self->_chomp_all($text) . $/;
    }
    $self->_save($text)
  }

  $self->_decrease_indent;
}

sub _start_item {
  my ($self) = @_;
  $self->_handle_between_item_content;
  $self->_new_stack;
}

sub   _end_item {
  my ($self, $marker) = @_;
  $self->_save_line($self->_indent($marker . ' ' . $self->_pop_stack_text));

  # Store any possible contents in a new stack (like a sub-document).
  $self->_increase_indent;
  $self->_new_stack;
}

sub start_over_bullet { $_[0]->_start_list }
sub   end_over_bullet { $_[0]->_end_list }

sub start_item_bullet { $_[0]->_start_item }
sub   end_item_bullet { $_[0]->_end_item('-') }

sub start_over_number { $_[0]->_start_list }
sub   end_over_number { $_[0]->_end_list }

sub start_item_number {
  $_[0]->_start_item;
  # It seems like this should be a stack,
  # but from testing it appears that the corresponding 'end' event
  # comes right after the text (it doesn't surround any embedded content).
  # See t/nested.t which shows start-item, text, end-item, para, start-item....
  $_[0]->_private->{item_number} = $_[1]->{number};
}

sub   end_item_number {
  my ($self) = @_;
  $self->_end_item($self->_private->{item_number} . '.');
}

# Markdown doesn't support definition lists
# so do regular (unordered) lists with indented paragraphs.
sub start_over_text { $_[0]->_start_list }
sub   end_over_text { $_[0]->_end_list }

sub start_item_text { $_[0]->_start_item }
sub   end_item_text { $_[0]->_end_item('-')}


# perlpodspec equates an over/back region with no items to a blockquote.
sub start_over_block {
  # NOTE: We don't actually need to indent for a blockquote.
  $_[0]->_new_stack;
}

sub   end_over_block {
  my ($self) = @_;

  # Chomp first to avoid prefixing a blank line with a `>`.
  my $text = $self->_chomp_all($self->_pop_stack_text);

  # NOTE: Paragraphs will already be escaped.

  # I don't really like either of these implementations
  # but the join/map/split seems a little better and benches a little faster.
  # You would lose the last newline but we've already chomped.
  #$text =~ s{^(.)?}{'>' . (defined($1) && length($1) ? (' ' . $1) : '')}mge;
  $text = join $/, map { length($_) ? '> ' . $_ : '>' } split qr-$/-, $text;

  $self->_save_block($text);
}

## Custom Formats ##

sub start_for {
  my ($self, $attr) = @_;
  $self->_new_stack;

  if( $attr->{target} eq 'html' ){
    # Use another stack so we can indent
    # (not syntactily necessary but seems appropriate).
    $self->_new_stack;
    $self->_increase_indent;
    $self->_private->{no_escape} = 1;
    # Mark this so we know to undo it.
    $self->_stack_state->{for_html} = 1;
  }
}

sub end_for {
  my ($self) = @_;
  # Data gets saved as a block (which will handle indents),
  # but if there was html we'll alter this, so chomp and save a block again.
  my $text = $self->_chomp_all($self->_pop_stack_text);

  if( $self->_private->{last_state}->{for_html} ){
    $self->_private->{no_escape} = 0;
    # Save it to the next stack up so we can pop it again (we made two stacks).
    $self->_save($text);
    $self->_decrease_indent;
    $text = join "\n", '<div>', $self->_chomp_all($self->_pop_stack_text), '</div>';
  }

  $self->_save_block($text);
}

# Data events will be emitted for any formatted regions that have been enabled
# (by default, `markdown` and `html`).

sub start_Data {
  my ($self) = @_;
  # TODO: limit this to what's in attr?
  $self->_private->{no_escape}++;
  $self->_new_stack;
}

sub   end_Data {
  my ($self) = @_;
  my $text = $self->_pop_stack_text;
  $self->_private->{no_escape}--;
  $self->_save_block($text);
}

## Codes ##

# TODO: change to '**' ?
sub start_B { $_[0]->_save('__') }
sub   end_B { $_[0]->start_B()   }

sub start_I { $_[0]->_save('_') }
sub   end_I { $_[0]->start_I()  }

sub start_C {
  my ($self) = @_;
  $self->_new_stack;
  $self->_private->{no_escape}++;
}

sub   end_C {
  my ($self) = @_;
  $self->_private->{no_escape}--;
  $self->_save( $self->_wrap_code_span($self->_pop_stack_text) );
}

# Use code spans for F<>.
sub start_F { shift->start_C(@_); }
sub   end_F { shift  ->end_C(@_); }

sub start_S { $_[0]->_private->{nbsp}++; }
sub   end_S { $_[0]->_private->{nbsp}--; }

sub start_L {
  my ($self, $flags) = @_;
  $self->_new_stack;
  push @{ $self->_private->{link} }, $flags;
}

sub   end_L {
  my ($self) = @_;
  my $flags = pop @{ $self->_private->{link} }
    or die 'Invalid state: link end with no link start';

  my ($type, $to, $section) = @{$flags}{qw( type to section )};

  my $url = (
    $type eq 'url' ? $to
      : $type eq 'man' ? $self->format_man_url($to, $section)
      : $type eq 'pod' ? $self->format_perldoc_url($to, $section)
      :                  undef
  );

  my $text = $self->_pop_stack_text;

  # NOTE: I don't think the perlpodspec says what to do with L<|blah>
  # but it seems like a blank link text just doesn't make sense
  if( !length($text) ){
    $text =
      $section ?
        $to ? sprintf('"%s" in %s', $section, $to)
        : ('"' . $section . '"')
      : $to;
  }

  # FIXME: What does Pod::Simple::X?HTML do for this?
  # if we don't know how to handle the url just print the pod back out
  if (!$url) {
    $self->_save(sprintf 'L<%s>', $flags->{raw});
    return;
  }

  # In the url we need to escape quotes and parentheses lest markdown
  # break the url (cut it short and/or wrongfully interpret a title).

  # Backslash escapes do not work for the space and quotes.
  # URL-encoding the space is not sufficient
  # (the quotes confuse some parsers and produce invalid html).
  # I've arbitratily chosen HTML encoding to hide them from markdown
  # while mangling the url as litle as possible.
  $url =~ s/([ '"])/sprintf '&#x%x;', ord($1)/ge;

  # We also need to double any backslashes that may be present
  # (lest they be swallowed up) and stop parens from breaking the url.
  $url =~ s/([\\()])/\\$1/g;

  # TODO: put section name in title if not the same as $text
  $self->_save('[' . $text . '](' . $url . ')');
}

sub start_X {
  $_[0]->_new_stack;
}

sub   end_X {
  my ($self) = @_;
  my $text = $self->_pop_stack_text;
  # TODO: mangle $text?
  # TODO: put <a name="$text"> if configured
}

# A code span can be delimited by multiple backticks (and a space)
# similar to pod codes (C<< code >>), so ensure we use a big enough
# delimiter to not have it broken by embedded backticks.
sub _wrap_code_span {
  my ($self, $arg) = @_;
  my $longest = 0;
  while( $arg =~ /([`]+)/g ){
    my $len = length($1);
    $longest = $len if $longest < $len;
  }
  my $delim = '`' x ($longest + 1);
  my $pad = $longest > 0 ? ' ' : '';
  return $delim . $pad . $arg . $pad . $delim;
}

## Link Formatting (TODO: Move this to another module) ##

=method format_man_url

Used internally to create a url (using L</man_url_prefix>)
from a string like C<man(1)>.

=cut

sub format_man_url {
    my ($self, $to) = @_;
    my ($page, $part) = ($to =~ /^ ([^(]+) (?: \( (\S+) \) )? /x);
    return $self->man_url_prefix . ($part || 1) . '/' . ($page || $to);
}

=method format_perldoc_url

    # With $name and section being the two parts of L<name/section>.
    my $url = $parser->format_perldoc_url($name, $section);

Used internally to create a url from
the name (of a module or script)
and a possible section (heading).

The format of the url fragment (when pointing to a section in a document)
varies depending on the destination url
so L</perldoc_fragment_format> is used (which can be customized).

If the module name portion of the link is blank
then the section is treated as an internal fragment link
(to a section of the generated markdown document)
and L</markdown_fragment_format> is used (which can be customized).

=cut

sub format_perldoc_url {
  my ($self, $name, $section) = @_;

  my $url_prefix = $self->perldoc_url_prefix;
  my $url = '';

  # If the link is to another module (external link).
  if ($name) {
    $url = $url_prefix . $name;
  }

  # See https://rt.cpan.org/Ticket/Display.html?id=57776
  # for a discussion on the need to mangle the section.
  if ($section){

    my $method = $url
      # If we already have a prefix on the url it's external.
      ? $self->perldoc_fragment_format
      # Else an internal link points to this markdown doc.
      : $self->markdown_fragment_format;

    $method = 'format_fragment_' . $method
      unless ref($method);

    {
      # Set topic to enable code refs to be simple.
      local $_ = $section;
      $section = $self->$method($section);
    }

    $url .= '#' . $section;
  }

  return $url;
}

=method format_fragment_markdown

Format url fragment for an internal link
by replacing non-word characters with dashes.

=cut

# TODO: simple, pandoc, etc?

sub format_fragment_markdown {
  my ($self, $section) = @_;

  # If this is an internal link (to another section in this doc)
  # we can't be sure what the heading id's will look like
  # (it depends on what is rendering the markdown to html)
  # but we can try to follow popular conventions.

  # http://johnmacfarlane.net/pandoc/demo/example9/pandocs-markdown.html#header-identifiers-in-html-latex-and-context
  #$section =~ s/(?![-_.])[[:punct:]]//g;
  #$section =~ s/\s+/-/g;
  $section =~ s/\W+/-/g;
  $section =~ s/-+$//;
  $section =~ s/^-+//;
  $section = lc $section;
  #$section =~ s/^[^a-z]+//;
  $section ||= 'section';

  return $section;
}

=method format_fragment_pod_simple_xhtml

Format url fragment like L<Pod::Simple::XHTML/idify>.

=cut

{
  # From Pod::Simple::XHTML 3.28.
  # The strings gets passed through encode_entities() before idify().
  # If we don't do it here the substitutions below won't operate consistently.

  # encode_entities {
    my %entities = (
      q{>} => 'gt',
      q{<} => 'lt',
      q{'} => '#39',
      q{"} => 'quot',
      q{&} => 'amp',
    );

    my
      $ents = join '', keys %entities;
  # }

  sub format_fragment_pod_simple_xhtml {
    my ($self, $t) = @_;

    # encode_entities {
      $t =~ s/([$ents])/'&' . ($entities{$1} || sprintf '#x%X', ord $1) . ';'/ge;
    # }

    # idify {
      for ($t) {
          s/<[^>]+>//g;            # Strip HTML.
          s/&[^;]+;//g;            # Strip entities.
          s/^\s+//; s/\s+$//;      # Strip white space.
          s/^([^a-zA-Z]+)$/pod$1/; # Prepend "pod" if no valid chars.
          s/^[^a-zA-Z]+//;         # First char must be a letter.
          s/[^-a-zA-Z0-9_:.]+/-/g; # All other chars must be valid.
          s/[-:.]+$//;             # Strip trailing punctuation.
      }
    # }

    return $t;
  }
}

=method format_fragment_pod_simple_html

Format url fragment like L<Pod::Simple::HTML/section_name_tidy>.

=cut

sub format_fragment_pod_simple_html {
  my ($self, $section) = @_;

  # From Pod::Simple::HTML 3.28.

  # section_name_tidy {
    $section =~ s/^\s+//;
    $section =~ s/\s+$//;
    $section =~ tr/ /_/;
    $section =~ tr/\x00-\x1F\x80-\x9F//d if 'A' eq chr(65); # drop crazy characters

    #$section = $self->unicode_escape_url($section);
      # unicode_escape_url {
      $section =~ s/([^\x00-\xFF])/'('.ord($1).')'/eg;
        #  Turn char 1234 into "(1234)"
      # }

    $section = '_' unless length $section;
    return $section;
  # }
}

=method format_fragment_metacpan

Format fragment for L<metacpan.org>
(uses L</format_fragment_pod_simple_xhtml>).

=method format_fragment_sco

Format fragment for L<search.cpan.org>
(uses L</format_fragment_pod_simple_html>).

=cut

sub format_fragment_metacpan { shift->format_fragment_pod_simple_xhtml(@_); }
sub format_fragment_sco      { shift->format_fragment_pod_simple_html(@_);  }

1;

=for stopwords
html

=for Pod::Coverage
handle_text
end_.+
start_.+

=for test_synopsis
my ($pod_file, $pod_string);

=head1 SYNOPSIS

  # Pod::Simple API is supported.

  # Parse a pod file and print to STDOUT:
  Pod::Markdown->new->filter($pod_file);

  # Work with strings:
  my $markdown;
  my $parser = Pod::Markdown->new;
  $parser->output_string(\$markdown);
  $parser->parse_string_document($pod_string);

  # See Pod::Simple docs for more.

  # Legacy (Pod::Parser-based) API is supported for backward compatibility:
  my $parser = Pod::Markdown->new;
  $parser->parse_from_filehandle(\*STDIN);
  print $parser->as_markdown;

=head1 DESCRIPTION

This module uses L<Pod::Simple> to convert POD to Markdown.

Literal characters in Pod that are special in Markdown
(like *asterisks*) are backslash-escaped when appropriate.

By default C<markdown> and C<html> formatted regions are accepted.
Regions of C<markdown> will be passed through unchanged.
Regions of C<html> will be placed inside a C<< E<lt>divE<gt> >> tag
so that markdown characters won't be processed.
Regions of C<:markdown> or C<:html> will be processed as POD and included.
To change which regions are accepted use the L<Pod::Simple> API:

  my $parser = Pod::Markdown->new;
  $parser->unaccept_targets(qw( markdown html ));

=head1 SEE ALSO

=for :list
* L<pod2markdown> - script included for command line usage
* L<Pod::Simple> - Super class that handles Pod parsing
* L<perlpod> - For writing POD
* L<perlpodspec> - For parsing POD
* L<http://daringfireball.net/projects/markdown/syntax> - Markdown spec
