# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use lib 't/lib';
use MarkdownTests;

# Test url aliases.
local $Pod::Markdown::URL_PREFIXES{manny} = 'http://manny.local/page/';

my %defaults = (
  # We'll test the various formats later
  # so for the first set just pass them through.
  perldoc_fragment_format  => sub { $_ },
  markdown_fragment_format => sub { $_ },
);

my ($pod_prefix, $man_prefix) =
  map { ($_->perldoc_url_prefix, $_->man_url_prefix) }
    Pod::Markdown->new;

my $alt_text_for_urls = 1; # Assume we have a sufficient Pod::Simple version.

my ($space, $quot) =
  map { sprintf '&#x%x;', ord }
    q[ ], q["];

my @tests = (

# in order of L<> examples in perlpod:
['name',                         q<name>,                   qq^[name](${pod_prefix}name)^],
['other module',                 q<Other::Pod>,             qq^[Other::Pod](${pod_prefix}Other::Pod)^],
['other module, empty text',     q<|Other::Pod>,            qq^[Other::Pod](${pod_prefix}Other::Pod)^],

['other module/sec, empty text', q<|Other::Pod/sec>,        qq^["sec" in Other::Pod](${pod_prefix}Other::Pod#sec)^],
['section in other module',      q<Other::Pod/sec>,         qq^["sec" in Other::Pod](${pod_prefix}Other::Pod#sec)^],
['quoted section in other doc',  q<perlsyn/"For Loops">,    qq^["For Loops" in perlsyn](${pod_prefix}perlsyn#For${space}Loops)^],

['section in this doc',          q</sec>,                   qq^["sec"](#sec)^],
['quoted section in this doc',   q</"sec">,                 qq^["sec"](#sec)^],
['/sec, empty text',             q<|/sec>,                  qq^["sec"](#sec)^],

['other module, alternate text', q<other-pod|Other::Pod>,   qq^[other-pod](${pod_prefix}Other::Pod)^],

['sec in other mod, alt text',   q<x-sec|Other::Pod/sec>,   qq^[x-sec](${pod_prefix}Other::Pod#sec)^],
['"sec" in other mod, alt text', q<x-sec|Other::Pod/"sec">, qq^[x-sec](${pod_prefix}Other::Pod#sec)^],

['/"sec" in this doc, alt text', q<other-sec|/"sec">,       qq^[other-sec](#sec)^],
['/sec in this doc, alt text',   q<other-sec|/sec>,         qq^[other-sec](#sec)^],
['"sec" in this doc, alt text',  q<other-sec|"sec">,        qq^[other-sec](#sec)^],

['external ftp',                 q<ftp://server>,           qq^[ftp://server](ftp://server)^],
['external http',                q<http://website>,         qq^[http://website](http://website)^],
['http, alt text (perl 5.12)',   q<web|http://website>,     qq^[web](http://website)^],

['embedded codes',               q^the docs on C<$.>|perlvar/"$."^, qq^[the docs on `\$.`](${pod_prefix}perlvar#\$.)^],
["don't expand nested L's",      q^perlpodspec/"About LE<lt>...E<gt> Codes"^, qq^["About L<...> Codes" in perlpodspec](${pod_prefix}perlpodspec#About${space}L<...>${space}Codes)^],

# perlpodspec examples:
['name',                         q<Foo::Bar>,               qq^[Foo::Bar](${pod_prefix}Foo::Bar)^],
['alt|pod/sec', q<Perlport's section on NL's|perlport/Newlines>, qq^[Perlport's section on NL's](${pod_prefix}perlport#Newlines)^],
['pod/sec',                      q<perlport/Newlines>,      qq^["Newlines" in perlport](${pod_prefix}perlport#Newlines)^],
['man/sec',               q<crontab(5)/"DESCRIPTION">,      qq^["DESCRIPTION" in crontab(5)](${man_prefix}5/crontab)^],
['/section name',                q</Object Attributes>,     qq^["Object Attributes"](#Object${space}Attributes)^],
['http',                         q<http://www.perl.org/>,   qq^[http://www.perl.org/](http://www.perl.org/)^],
['text|http',             q<Perl.org|http://www.perl.org/>, qq^[Perl.org](http://www.perl.org/)^],

# man pages
['man(1)',                       q<crontab(1)>,             qq^[crontab(1)](${man_prefix}1/crontab)^],
['man(5)',                       q<crontab(5)>,             qq^[crontab(5)](${man_prefix}5/crontab)^],

# how should these be handled?  these are unlikely/contrived occurrences and are mostly here for test coverage
#['man()',                        q<crontab()>,              qq^[crontab()](${man_prefix}1/crontab)^],
#['man(X)',                       q<crontab(X)>,             qq^[crontab(X)](${man_prefix}X/crontab)^],
#['man(2)-page',                  q<crontab(2)-page>,        qq^[crontab(2)-page](${man_prefix}2/crontab)^],
#['(X)man',                       q<(X)foo>,                 qq^[(X)foo](${man_prefix}1/(X)foo)^],
#['()',                           q<()>,                     qq^[()](${man_prefix}1/())^],

# varies according to pod-to-html formatter:
['other/section name',           q<Other/Section Name>,     qq^["Section Name" in Other](${pod_prefix}Other#Section${space}Name)^],

# Insert backslashes (to escape markdown).
['_underscore_',                 q<_underscore_>,           qq^[\\_underscore\\_](${pod_prefix}_underscore_)^],
['*asterisk*',                   q<*asterisk*>,             qq^[\\*asterisk\\*](${pod_prefix}*asterisk*)^],
['section with quotes',          q<whiskey|/Say "Cheese">,  qq^[whiskey](#Say${space}${quot}Cheese${quot})^],

# is there something better to do?
# These seem so useless I don't think I care what they do.
#['no url: empty',                q<>,                       qq^L<>^], # FIXME: Error
# These work on 3.28 but not on 3.16:
#['no url: pipe',                 q<|>,                      qq^L<|>^],
#['no url: slash',                q</>,                      qq^L</>^],
#['no url: quotes',               q<"">,                     qq^L<"">^],

['empty text: |url',             q<|http://foo>,            qq^[http://foo](http://foo)^],
['false text: 0|url',            q<0|http://foo>,           qq^[0](http://foo)^],

# Alternate parser options:
['man url',          q<crontab(1)>, qq^[crontab(1)](file:///docs/man1/crontab)^,              man_url_prefix => 'file:///docs/man'],
['man alias: manny', q<crontab(1)>, qq^[crontab(1)](http://manny.local/page/1/crontab)^,      man_url_prefix => 'manny'],
['man alias: man',   q<crontab(1)>, qq^[crontab(1)](http://man.he.net/man1/crontab)^,         man_url_prefix => 'man'],

['pod url',             q<Foo::Bar>, qq^[Foo::Bar](http://localhost/pod/Foo::Bar)^,           perldoc_url_prefix => 'http://localhost/pod/'],
['pod alias: sco',      q<Foo::Bar>, qq^[Foo::Bar](http://search.cpan.org/perldoc?Foo::Bar)^, perldoc_url_prefix => 'sco'],
['pod alias: metacpan', q<Foo::Bar>, qq^[Foo::Bar](https://metacpan.org/pod/Foo::Bar)^,       perldoc_url_prefix => 'metacpan'],
['pod alias: perldoc',  q<Foo::Bar>, qq^[Foo::Bar](https://metacpan.org/pod/Foo::Bar)^,       perldoc_url_prefix => 'perldoc'],
);

# Local Module URLs
{
  my $p = {};
  #'<,'>perldo if (s/^\[|\],$//g){ $a = [map { s/^\s+|\s+$//gr } split /,/, $_, 4]; @$a > 2 and $_ = "  test_link({$a->[3]}, $a->[1], $a->[2], $a->[0]);" }

  test_link($p, q<Local::Foo>, qq^[Local::Foo](${pod_prefix}Local::Foo)^,
    'Local::* defaults to perldoc');
  test_link($p, q<Foo_Corp::Bar>, qq^[Foo\\_Corp::Bar](${pod_prefix}Foo_Corp::Bar)^,
    'Foo_Corp::* defaults to perldoc');

  $p->{perldoc_url_prefix} = 'perldoc://';
  test_link($p, q<Local::Foo>, qq^[Local::Foo](perldoc://Local::Foo)^,
    'local module without custom url respects perldoc_url_prefix');

  $p->{local_module_url_prefix} = 'local://';
  test_link($p, q<Local::Foo>, qq^[Local::Foo](local://Local::Foo)^,
    'Local::* custom url');
  test_link($p, q<Foo_Corp::Bar>, qq^[Foo\\_Corp::Bar](local://Foo_Corp::Bar)^,
    'Foo_Corp::* custom url');

  test_link($p, q<Normal::Foo>, qq^[Normal::Foo](perldoc://Normal::Foo)^,
    'non local module');

  $p->{local_module_re} = qr/Normal/;
  test_link($p, q<Normal::Foo>,   qq^[Normal::Foo](local://Normal::Foo)^,
    'Normal::* with custom RE');
  test_link($p, q<NonLocal::Foo>, qq^[NonLocal::Foo](perldoc://NonLocal::Foo)^,
    'NonLocal* with custom RE');
  test_link($p, q<Local::Foo>, qq^[Local::Foo](perldoc://Local::Foo)^,
    'even Local::* uses perldoc when custom re does not match');
}

# Most of these examples were internal links
# so we add the perldoc name to make testing easier.

test_fragments(
  q^perlvar/$.^,
  {
    # It's unfortunate that Pod::Simple::XHTML can't do links to just symbols:
    # https://rt.cpan.org/Ticket/Display.html?id=90207
    metacpan => q^["$." in perlvar](:perlvar#pod)^,
    sco      => q^["$." in perlvar](:perlvar#$.)^,
  },
  'section with only symbols',
);

test_fragments(
  q^perlop/"IE<sol>O Operators"^,
  {
    metacpan => q^["I/O Operators" in perlop](:perlop#I-O-Operators)^,
    sco      => q^["I/O Operators" in perlop](:perlop#I/O_Operators)^,
  },
  'perlvar.pod: external section with symbols',
);

test_fragments(
  q^perlpodspec/"About LE<lt>...E<gt> Codes"^,
  {
    metacpan => q^["About L<...> Codes" in perlpodspec](:perlpodspec#About-L...-Codes)^,
    sco      => q^["About L<...> Codes" in perlpodspec](:perlpodspec#About_L<...>_Codes)^,
    markdown => q^["About L<...> Codes" in perlpodspec](:perlpodspec#about-l-codes)^,
  },
  'section with pod escapes',
);

test_fragments(
  q^perlpodspec/About Data Paragraphs and "=beginE<sol>=end" Regions^,
  {
    metacpan => q^["About Data Paragraphs and "=begin/=end" Regions" in perlpodspec](:perlpodspec#About-Data-Paragraphs-and-begin-end-Regions)^,
    sco      => qq^["About Data Paragraphs and "=begin/=end" Regions" in perlpodspec](:perlpodspec#About_Data_Paragraphs_and_${quot}=begin/=end${quot}_Regions)^,
  },
  'section with pod commands',
);

test_fragments(
  q^detach|Catalyst/"$c->detach( $action [, \@arguments ] )"^,
  {
    metacpan => q^[detach](:Catalyst#c-detach-action-arguments)^,
    sco      => q^[detach](:Catalyst#$c->detach\(_$action_[,_\\\\@arguments_]_\))^,
  },
  'section with sigils and syntax',
);

test_fragments(
  q^perlpod/"Formatting Codes"^,
  {
    metacpan => q^["Formatting Codes" in perlpod](:perlpod#Formatting-Codes)^,
    sco      => q^["Formatting Codes" in perlpod](:perlpod#Formatting_Codes)^,
  },
  'quoted section in other doc',
);


test_fragments(
  q</Some, OTHER Section!>,
  {
    markdown => q^["Some, OTHER Section!"](#some-other-section)^,
  },
  'complicated section',
);

test_fragments(
  q</"If you have a setup working, share your 'definition' with me. That would be fun!">,
  {
    markdown => qq^["If you have a setup working, share your 'definition' with me. That would be fun!"](#if-you-have-a-setup-working-share-your-definition-with-me-that-would-be-fun)^,
  },
  'extra long real life example complicated section',
);

test_fragments(
  q<A [charclass] is \\* bad|page/section with (Parens) and \\Escapes *star*>,
  {
    metacpan =>  q^[A \\[charclass\\] is \\\\\\* bad](:page#section-with-Parens-and-Escapes-star)^,
    sco      => qq^[A \\[charclass\\] is \\\\\\* bad](:page#section_with_\\(Parens\\)_and_\\\\Escapes_*star*)^,
  },
  'extra long real life example complicated section',
);

with_and_without_entities {
  my $ents = shift;
  my $exp  = $ents ? '101' : 'x65';
  test_fragments(
    q<page/section>,
    {
      metacpan => qq^["s&#${exp};ction" in pag&#${exp};](:page#section)^,
      sco      => qq^["s&#${exp};ction" in pag&#${exp};](:page#section)^,
    },
    "respect html_encode_chars in code link text but not in fragment (HTML::Entites $ents)",
    html_encode_chars => 'e',
  );
};


foreach my $test ( @tests ){
  my ($desc, $pod, $mkdn, %opts) = @$test;
  %opts = %defaults unless %opts;
  test_link(
    \%opts,
    $pod, $mkdn, $desc,
  );
}

sub test_link {
  my ($opts, $pod, $mkdn, $desc) = @_;
  my $parser = Pod::Markdown->new(%$opts);

  SKIP: {
    skip 'alt text with schemes/absolute URLs not supported until perl 5.12 / Pod::ParseLink 1.10', 1
      if !$alt_text_for_urls && $pod =~ m/\|\w+:[^:\s]\S*\z/; # /alt text \| url (not perl module)/ (regexp from perlpodspec)

    $parser->output_string(\(my $got));
    $parser->parse_string_document("=pod\n\nL<<< $pod >>>");
    chomp($got);

    is $got, $mkdn, $desc . ' (interpolate)';
  }
}

sub test_fragments {
  my ($pod, $tests, $desc, %opts) = @_;
  foreach my $format ( sort keys %$tests ){
    test_link(
      # Only some combinations of these will normally make sense
      # but it makes the function reusable.
      {
        perldoc_fragment_format => $format,
        perldoc_url_prefix      => ':', # easier
        markdown_fragment_format => $format,
        %opts,
      },
      $pod,
      $tests->{$format},
      "$desc: $format",
    );
  }
}

done_testing;
