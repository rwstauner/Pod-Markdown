# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use 5.008;
use strict;
use warnings;

package Pod::Markdown;
# ABSTRACT: Convert POD to Markdown

use Pod::Parser 1.51 ();
use parent qw(Pod::Parser);
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
Alters the man page urls that are created from C<< L<> >> codes.

The default is C<http://man.he.net/man>.

* C<perldoc_url_prefix>
Alters the perldoc urls that are created from C<< L<> >> codes.
Can be:

=for :list
* C<metacpan> (shortcut for C<https://metacpan.org/pod/>)
* C<sco> (shortcut for C<http://search.cpan.org/perldoc?>)
* any url

The default is C<metacpan>.

    Pod::Markdown->new(perldoc_url_prefix => 'http://localhost/perl/pod');

* C<perldoc_fragment_format>
Alters the format of the url fragment for any C<< L<> >> links
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
Alters the format of the url fragment for any C<< L<> >> links
that point to an internal section of this document (C<< L</section> >>).

Unfortunately the format of the id attributes produced
by whatever system translates the markdown into html is unknown at the time
the markdown is generated so we do some simple clean up.

B<Note:> C<markdown_fragment_format> and C<perldoc_fragment_format> accept
the same values: a (shortcut to a) method name or a code ref.

=end :list

=cut

# new() is provided by Pod::Parser (which calls initialize()).

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);

    for my $type ( qw( perldoc man ) ){
        my $attr  = $type . '_url_prefix';
        # Use provided argument or default alias.
        my $url = $self->{ $attr } || $type;
        # Expand alias if defined (otherwise use url as is).
        $self->{ $attr } = $URL_PREFIXES{ $url } || $url;
    }

    $self->_prepare_fragment_formats;

    $self->_private;
    $self;
}

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

{
  no strict 'refs';
  foreach my $attr ( @attr ){
    *$attr = sub { return $_[0]->{ $attr } };
  }
}

sub _prepare_fragment_formats {
  my ($self) = @_;

  foreach my $attr ( @attr ){
    next unless $attr =~ /^(\w+)_fragment_format/;
    my $type = $1;
    my $format = $self->{ $attr };

    # If one was provided.
    if( $format ){
      # If the attribute is a coderef just use it.
      next if ref($format) eq 'CODE';
    }
    # Else determine a default.
    else {
      if( $type eq 'perldoc' ){
        # Choose a default that matches the destination url.
        my $target = $self->{perldoc_url_prefix};
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
    $self->{ $attr } = $format;
  }

  return;
}

sub _private {
    my $self = shift;
    $self->{_MyParser} ||= {
        Text      => [],       # final text
        Indent    => 0,        # list indent levels counter
        ListType  => '-',      # character on every item
        searching => ''   ,    # what are we searching for? (title, author etc.)
        sstack    => [] ,      # Stack for searching, needed for nested list
        Title     => undef,    # page title
        Author    => undef,    # page author
    };
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

# $prelisthead:
#   undef    : not list head
#   ''       : list head not huddled
#   otherwise: list head huddled
sub _save {
    my ($parser, $text, $prelisthead) = @_;
    my $data = $parser->_private;
    $text = $parser->_indent_text($text, defined($prelisthead));
    $text = $prelisthead."\n".$text if defined $prelisthead && $prelisthead ne '';
    push @{ $data->{Text} }, $text;
    return;
}

sub _unsave {
    my $parser = shift;
    my $data = $parser->_private;
    return pop @{ $data->{Text} };
}

sub _indent_text {
    my ($parser, $text, $listhead) = @_;
    my $data   = $parser->_private;
    my $level  = $data->{Indent};
    --$level if $listhead;
    my $indent = undef;
    $indent = ' ' x ($level * 4);
    my @lines = map { $indent . $_; } split(/\n/, $text);
    return wantarray ? @lines : join("\n", @lines);
}

sub _clean_text {
    my $text    = $_[1];
    my @trimmed = grep { $_; } split(/\n/, $text);

    return wantarray ? @trimmed : join("\n", @trimmed);
}

# Backslash escape markdown characters to avoid having them interpreted.
sub _escape {
    local $_ = $_[1];

    # do inline characters first
    s/([][\\`*_#])/\\$1/g;

    # escape unordered lists and blockquotes
    s/^([-+*>])/\\$1/mg;

    # escape dots that would wrongfully create numbered lists
    s/^( (?:>\s+)? \d+ ) (\.\x20)/$1\\$2/xgm;

    return $_;
}

# Formats a header according to the given level.
sub format_header {
    my ($self, $level, $paragraph) = @_;
    # TODO: put a name="" if $self->{embed_anchor_tags}; ?
    # https://rt.cpan.org/Ticket/Display.html?id=57776
    sprintf '%s %s', '#' x $level, $paragraph;
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
        # this strips the POD list head; the searching=listhead will insert markdown's
        # FIXME: this does not account for named lists

        # Assuming that POD is correctly wrtitten, we just use POD list head as markdown's
        $data->{ListType} = '-'; # Default
        if($paragraph =~ m{^[ \t]* \* [ \t]*}xms) {
            $paragraph =~ s{^[ \t]* \* [ \t]*}{}xms;
        } elsif($paragraph =~ m{^[ \t]* (\d+)\.? [ \t]*}xms) {
            $data->{ListType} = $1.'.'; # For numbered list only
            $paragraph =~ s{^[ \t]* \d+\.? [ \t]*}{}xms;
        }

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

# Handles verbatim text.
sub verbatim {
    my ($parser, $paragraph) = @_;

    # NOTE: perlpodspec says parsers should expand tabs by default
    # NOTE: Apparently Pod::Parser does not.  should we?
    # NOTE: this might be s/^\t/" " x 8/e, but what about tabs inside the para?

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
        # leave tabs alone
        $paragraph = join "\n", map { /^\t/ ? $_ : $indent . $_ } @lines;
    }

    # FIXME: Checking _PREVIOUS is breaking Pod::Parser encapsulation
    # but helps solve the extraneous extra blank line b/t verbatim blocks.
    # We could probably keep track ourselves if need be.
    # NOTE: This requires Pod::Parser 1.50.
    # This is another reason to switch to Pod::Simple.
    my $previous_was_verbatim =
        $parser->{_PREVIOUS} && $parser->{_PREVIOUS} eq 'verbatim';

    if($previous_was_verbatim && $parser->_private->{Text}->[-1] =~ /[ \t]+$/){
        $paragraph = $parser->_unsave . "\n" . $paragraph;
    }

    $parser->_save($paragraph);
}

sub _escape_and_interpolate {
    my ($parser, $paragraph, $line_num) = @_;

    # escape markdown characters in text sequences except for inline code
    $paragraph = join '', $parser->parse_text(
        { -expand_text => '_escape_non_code' },
        $paragraph, $line_num
    )->raw_text;

    # interpolate the paragraph for embedded sequences
    $paragraph = $parser->interpolate($paragraph, $line_num);

    return $paragraph;
}

sub _escape_non_code {
    my ($parser, $text, $ptree) = @_;

    if ($ptree->isa('Pod::InteriorSequence') && $ptree->cmd_name =~ /\A[CFL]\z/) {
        return $text;
    }
    return $parser->_escape($text);
}

# Handles normal blocks of POD.
sub textblock {
    my ($parser, $paragraph, $line_num) = @_;
    my $data = $parser->_private;
    my $prelisthead;

    $paragraph = $parser->_escape_and_interpolate($paragraph, $line_num);

    # clean the empty lines
    $paragraph = $parser->_clean_text($paragraph);

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

# An interior sequence is an embedded command
# within a block of text which appears as a command name - usually a single
# uppercase character - followed immediately by a string of text which is
# enclosed in angle brackets.
sub interior_sequence {
    my ($self, $seq_command, $seq_argument, $pod_seq) = @_;

    # nested links are not allowed
    return sprintf '%s<%s>', $seq_command, $seq_argument
        if $seq_command eq 'L' && $self->_private->{InsideLink};

    my $i = 2;
    my %interiors = (
        'I' => sub { return '_'  . $_[$i] . '_'  },      # italic
        'B' => sub { return '__' . $_[$i] . '__' },      # bold
        'C' => \&_wrap_code_span,                        # monospace
        'F' => \&_wrap_code_span,                        # system path
        # non-breaking space
        'S' => sub {
            (my $s = $_[$i]) =~ s/ /&nbsp;/g;
            return $s;
        },
        'E' => sub {
            my $charname = $_[$i];
            return '<' if $charname eq 'lt';
            return '>' if $charname eq 'gt';
            return '|' if $charname eq 'verbar';
            return '/' if $charname eq 'sol';

            # convert legacy charnames to more modern ones (see perlpodspec)
            $charname =~ s/\A([lr])chevron\z/${1}aquo/;

            return "&#$1;" if $charname =~ /^0(x[0-9a-fA-Z]+)$/;

            $charname = oct($charname) if $charname =~ /^0\d+$/;

            return "&#$charname;"      if $charname =~ /^\d+$/;

            return "&$charname;";
        },
        'L' => \&_resolv_link,
        # TODO: create `a name=` if configured?
        'X' => sub { '' },
        'Z' => sub { '' },
    );
    if (exists $interiors{$seq_command}) {
        my $code = $interiors{$seq_command};
        return $code->($self, $seq_command, $seq_argument, $pod_seq);
    } else {
        return sprintf '%s<%s>', $seq_command, $seq_argument;
    }
}

sub _resolv_link {
    my ($self, $cmd, $arg) = @_;

    local $self->_private->{InsideLink} = 1;

    my ($text, $inferred, $name, $section, $type) =
      # perlpodspec says formatting codes can occur in all parts of an L<>
      map { $_ && $self->interpolate($_, 1) }
      Pod::ParseLink::parselink($arg);
    my $url = '';

    if ($type eq 'url') {
        $url = $name;
    } elsif ($type eq 'man') {
        $url = $self->format_man_url($name);
    } else {
        $url = $self->format_perldoc_url($name, $section);
    }

    # if we don't know how to handle the url just print the pod back out
    if (!$url) {
        return sprintf '%s<%s>', $cmd, $arg;
    }

    # TODO: put unescaped section into link title? [a](b "c")
    return sprintf '[%s](%s)', ($text || $inferred), $url;
}

# A code span can be delimited by multiple backticks (and a space)
# similar to pod codes (C<< code >>), so ensure we use a big enough
# delimiter to not have it broken by embedded backticks.
sub _wrap_code_span {
  my ($self, $cmd, $arg) = @_;
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

=for Pod::Coverage
format_header
initialize
command interior_sequence textblock verbatim

=head1 SYNOPSIS

    my $parser = Pod::Markdown->new;
    $parser->parse_from_filehandle(\*STDIN);
    print $parser->as_markdown;

=head1 DESCRIPTION

This module subclasses L<Pod::Parser> and converts POD to Markdown.

Literal characters in Pod that are special in Markdown
(like *asterisks*) are backslash-escaped when appropriate.

=head1 SEE ALSO

=for :list
* L<pod2markdown> - script included for command line usage
