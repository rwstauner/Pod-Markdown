# vim: set ts=4 sts=4 sw=4 expandtab smarttab:
use 5.008;
use strict;
use warnings;

package Pod::Markdown;
# ABSTRACT: Convert POD to Markdown
use parent qw(Pod::Parser);
use Pod::ParseLink (); # core

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    $self->_private;
    $self;
}

sub _private {
    my $self = shift;
    $self->{_MyParser} ||= {
        Text      => [],       # final text
        Indent    => 0,        # list indent levels counter
        ListType  => '-',      # character on every item
        searching => ''   ,    # what are we searching for? (title, author etc.)
        Title     => undef,    # page title
        Author    => undef,    # page author
    };
}

sub as_markdown {
    my ($parser, %args) = @_;
    my $data  = $parser->_private;
    my $lines = $data->{Text};
    my @header;
    if ($args{with_meta}) {
        @header = $parser->_build_markdown_head;
    }
    join("\n" x 2, @header, @{$lines});
}

sub _build_markdown_head {
    my $parser    = shift;
    my $data      = $parser->_private;
    return join "\n",
        map  { qq![[meta \l$_="$data->{$_}"]]! }
        grep { defined $data->{$_} }
        qw( Title Author );
}

sub _save {
    my ($parser, $text) = @_;
    my $data = $parser->_private;
    $text = $parser->_indent_text($text);
    push @{ $data->{Text} }, $text;
    return;
}

sub _unsave {
    my $parser = shift;
    my $data = $parser->_private;
    return pop @{ $data->{Text} };
}

sub _indent_text {
    my ($parser, $text) = @_;
    my $data   = $parser->_private;
    my $level  = $data->{Indent};
    my $indent = undef;
    if ($level > 0) {
        $level--;
    }
    $indent = ' ' x ($level * 4);
    my @lines = map { $indent . $_; } split(/\n/, $text);
    return wantarray ? @lines : join("\n", @lines);
}

sub _clean_text {
    my $text    = $_[1];
    my @trimmed = grep { $_; } split(/\n/, $text);
    return wantarray ? @trimmed : join("\n", @trimmed);
}

sub command {
    my ($parser, $command, $paragraph, $line_num) = @_;
    my $data = $parser->_private;

    # cleaning the text
    $paragraph = $parser->_clean_text($paragraph);

    # is it a header ?
    if ($command =~ m{head(\d)}xms) {
        my $level = $1;

        $paragraph = $parser->interpolate($paragraph, $line_num);

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

        # closing a list ?
    } elsif ($command =~ m{back}xms) {

        # decrement indent level
        $data->{Indent}--;
        $data->{searching} = '';
    } elsif ($command =~ m{item}xms) {
        $paragraph = $parser->interpolate($paragraph, $line_num);
        $paragraph =~ s{^[ \t]* \* [ \t]*}{}xms;

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

    $parser->_save($paragraph);
}

sub textblock {
    my ($parser, $paragraph, $line_num) = @_;
    my $data = $parser->_private;

    # interpolate the paragraph for embebed sequences
    $paragraph = $parser->interpolate($paragraph, $line_num);

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
            $paragraph = $parser->_unsave() . "\n" . $paragraph;
        }
        $data->{searching} = 'listpara';
    } elsif ($data->{searching} eq 'listpara') {
        $data->{searching} = '';
    }

    # save the text
    $parser->_save($paragraph);
}

sub interior_sequence {
    my ($self, $seq_command, $seq_argument, $pod_seq) = @_;

    # nested links are not allowed
    return sprintf '%s<%s>', $seq_command, $seq_argument
        if $seq_command eq 'L' && $self->_private->{InsideLink};

    my $i = 2;
    my %interiors = (
        'I' => sub { return '_'  . $_[$i] . '_'  },      # italic
        'B' => sub { return '__' . $_[$i] . '__' },      # bold
        'C' => sub { return '`'  . $_[$i] . '`'  },      # monospace
        'F' => sub { return '`'  . $_[$i] . '`'  },      # system path
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

    # TODO: make url prefixes configurable

    if ($type eq 'url') {
        $url = $name;
    } elsif ($type eq 'man') {
        # stolen from Pod::Simple::(X)HTML
        my ($page, $part) = $name =~ /\A([^(]+)(?:[(](\S*)[)])?/;
        $url = 'http://man.he.net/man' . ($part || 1) . '/' . ($page || $name);
    } else {
        if ($name) {
            $url = 'http://search.cpan.org/perldoc?' . $name;
        }
        if ($section){
            # TODO: sites/pod formatters differ on how to transform the section
            # TODO: we could do it according to specified url prefix or pod formatter
            # TODO: or allow a coderef?
            # TODO: (Pod::Simple::XHTML:idify() for metacpan)
            # TODO: (Pod::Simple::HTML section_escape/unicode_escape_url/section_url_escape for s.c.o.)
            $url .= '#' . $section;
        }
    }

    # if we don't know how to handle the url just print the pod back out
    if (!$url) {
        return sprintf '%s<%s>', $cmd, $arg;
    }

    return sprintf '[%s](%s)', ($text || $inferred), $url;
}

sub format_header {
    my ($level, $paragraph) = @_[1,2];
    sprintf '%s %s', '#' x $level, $paragraph;
}

1;

=for stopwords textblock

=head1 SYNOPSIS

    my $parser = Pod::Markdown->new;
    $parser->parse_from_filehandle(\*STDIN);
    print $parser->as_markdown;

=head1 DESCRIPTION

This module subclasses L<Pod::Parser> and converts POD to Markdown.

=method initialize

Initializes a newly constructed object.

=method as_markdown

Returns the parsed POD as Markdown. Takes named arguments. If the C<with_meta>
argument is given a positive value, meta tags are generated as well.

=method command

Handles POD command paragraphs, denoted by a line beginning with C<=>.

=method verbatim

Handles verbatim text.

=method textblock

Handles normal blocks of POD.

=method interior_sequence

Handles interior sequences in POD. An interior sequence is an embedded command
within a block of text which appears as a command name - usually a single
uppercase character - followed immediately by a string of text which is
enclosed in angle brackets.

=method format_header

Formats a header according to the given level.

