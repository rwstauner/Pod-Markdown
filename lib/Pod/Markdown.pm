# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use 5.008;
use strict;
use warnings;

package Pod::Markdown;
# ABSTRACT: Convert POD to Markdown

use Pod::Simple 3.14 (); # external links with text
use parent qw(Pod::Simple::Methody);
use Pod::ParseLink (); # core

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

=end :list

=cut

sub new {
  my $class = shift;
  my %args = @_;

  my $self = $class->SUPER::new();
  # Call setter for each arg passed in.
  while( my ($attr, $val) = each %args ){
    $self->$attr($val);
  }

    for my $type ( qw( perldoc man ) ){
        my $attr  = $type . '_url_prefix';
        # Use provided argument or default alias.
        my $url = $self->$attr || $type;
        # Expand alias if defined (otherwise use url as is).
        $self->$attr($URL_PREFIXES{ $url } || $url);
    }

    $self->_prepare_fragment_formats;

    $self->_private;

  return $self;
}

# Attribute getter/setters:

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

=cut

my @attr = qw(
  man_url_prefix
  perldoc_url_prefix
  perldoc_fragment_format
  markdown_fragment_format
);

# I don't think this is a documented feature of Pod::Simple.
__PACKAGE__->_accessorize(@attr);

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
    $self->$attr($format);
  }

  return;
}

## Document state ##

sub _private {
  my ($self) = @_;
  $self->{_Pod_Markdown_} ||= {
    indent      => 0,
    stacks      => [],
    states      => [{}],
  };
}

sub _new_stack {
  push @{ $_[0]->_private->{stacks} }, [];
}

sub _pop_stack_text {
  join '', @{ pop @{ $_[0]->_private->{stacks} } };
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

=method as_markdown

Returns the parsed POD as Markdown. Takes named arguments. If the C<with_meta>
argument is given a positive value, meta tags are generated as well.

=cut

sub as_markdown {
    my ($parser, %args) = @_;
    my $data  = $parser->_private;
    my $lines = $data->{Text};
    my @header;
    if ($args{with_meta}) {
        @header = $parser->_build_markdown_head;
    }
    join("\n" x 2, @header, @{$lines}) . "\n";
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

  my $doc = join('', @$end);

  print { $self->{output_fh} } $doc . $/;
}

# Handles POD command paragraphs, denoted by a line beginning with C<=>.
sub command {
    my ($parser, $command, $paragraph, $line_num) = @_;
    my $data = $parser->_private;

    # cleaning the text
    $paragraph = $parser->_clean_text($paragraph);

    # is it a header ?
    if ($command =~ m{head(\d)}xms) {
        my $level = $1;

        $paragraph = $parser->_escape_and_interpolate($paragraph, $line_num);

        # the headers never are indented
        $parser->_save($parser->format_header($level, $paragraph));
        if ($level == 1) {
            if ($paragraph =~ m{NAME}xmsi) {
                $data->{searching} = 'title';
            } elsif ($paragraph =~ m{AUTHOR}xmsi) {
                $data->{searching} = 'author';
            } else {
                $data->{searching} = '';
            }
        }
    }

    # opening a list ?
    elsif ($command =~ m{over}xms) {

        # update indent level
        $data->{Indent}++;
        push @{$data->{sstack}}, $data->{searching};

    # closing a list ?
    } elsif ($command =~ m{back}xms) {

        # decrement indent level
        $data->{Indent}--;
        $data->{searching} = pop @{$data->{sstack}};

    } elsif ($command =~ m{item}xms) {

        if ($data->{searching} eq 'listpara') {
            $data->{searching} = 'listheadhuddled';
        }
        else {
            $data->{searching} = 'listhead';
        }

        if (length $paragraph) {
            $parser->textblock($paragraph, $line_num);
        }
    }

    # ignore other commands
    return;
}

sub start_Verbatim {
  my ($self, $attr) = @_;
  $self->_new_stack;
}

sub end_Verbatim {
  my ($self) = @_;

  my $text = $self->_pop_stack_text;

  $text = $self->_indent_verbatim($text);

  $self->_save_line($text);
}

sub _indent_verbatim {
  my ($self, $paragraph) = @_;

    # NOTE: Pod::Simple expands the tabs for us (as suggested by perlpodspec).

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

  $self->_save_line($text);
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

sub _start_head {
  my ($self, $num) = @_;
  $self->_new_stack;
}

sub   _end_head {
  my ($self, $num) = @_;
  my $h = '#' x $num;

  my $text = $self->_pop_stack_text;

  # TODO: option for $h suffix
  # TODO: put a name="" if $self->{embed_anchor_tags}; ?
  # https://rt.cpan.org/Ticket/Display.html?id=57776
  $self->_save_line(join(' ', $h, $text));
}


# Handles normal blocks of POD.
sub textblock {
    my ($parser, $paragraph, $line_num) = @_;
    my $data = $parser->_private;
    my $prelisthead;

    # searching ?
    if ($data->{searching} =~ m{title|author}xms) {
        $data->{ ucfirst $data->{searching} } = $paragraph;
        $data->{searching} = '';
    } elsif ($data->{searching} =~ m{listhead(huddled)?$}xms) {
        my $is_huddled = $1;
        $paragraph = sprintf '%s %s', $data->{ListType}, $paragraph;
        if ($is_huddled) {
            # To compress into an item in order to avoid "\n\n" insertion.
            $prelisthead = $parser->_unsave();
        } else {
            $prelisthead = '';
        }
        $data->{searching} = 'listpara';
    } elsif ($data->{searching} eq 'listpara') {
        $data->{searching} = '';
    }

    # save the text
    $parser->_save($paragraph, $prelisthead);
}

## Lists ##

# TODO: over_empty

sub _start_list {
  my ($self) = @_;
  $self->_new_stack;
}

sub   _end_list {
  my ($self) = @_;
  my $text = $self->_pop_stack_text;

  # FIXME:
  $_[0]->_save_line($text . $/);
}

sub _start_item {
  my ($self) = @_;
  $self->_new_stack;
}

sub   _end_item {
  my ($self, $marker) = @_;
  $self->_save_line($self->_indent($marker . ' ' . $self->_pop_stack_text));
}

sub start_over_bullet { $_[0]->_start_list }
sub   end_over_bullet { $_[0]->_end_list }

sub start_item_bullet { $_[0]->_start_item }
sub   end_item_bullet { $_[0]->_end_item('-') }

sub start_over_number { $_[0]->_start_list }
sub   end_over_number { $_[0]->_end_list }

sub start_item_number {
  $_[0]->_start_item;
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


## Codes ##

# TODO: change to '**' ?
sub start_B { $_[0]->_save('__') }
sub   end_B { $_[0]->start_B()   }

sub start_I { $_[0]->_save('_') }
sub   end_I { $_[0]->start_I()  }

sub start_C {
  my ($self, $attr) = @_;
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

=for stopwords textblock
html

=for Pod::Coverage
format_header
initialize
command interior_sequence textblock verbatim

=head1 SYNOPSIS

    my $parser = Pod::Markdown->new;
    $parser->parse_from_filehandle(\*STDIN);
    print $parser->as_markdown;

=head1 DESCRIPTION

This module uses L<Pod::Simple> to convert POD to Markdown.

Literal characters in Pod that are special in Markdown
(like *asterisks*) are backslash-escaped when appropriate.

=head1 SEE ALSO

=for :list
* L<pod2markdown> - script included for command line usage
