use inc::Module::Install;
include 'Module::AutoInstall';

name 'Pod-Markdown';
all_from 'lib/Pod/Markdown.pm';
readme_from 'lib/Pod/Markdown.pm';
readme_markdown_from 'lib/Pod/Markdown.pm';

auto_set_homepage;
auto_set_bugtracker;
auto_set_repository;

requires 'Pod::Parser';

test_requires 'Test::More' => '0.70';
test_requires 'Test::Differences';
extra_tests;

author_requires 'ShipIt';
author_requires 'ShipIt::Step::DistClean';
author_requires 'ShipIt::Step::DistTestExtra';
author_requires 'ShipIt::Step::Manifest';
author_requires 'ShipIt::Step::Twitter';
author_requires 'Test::Compile';
author_requires 'Test::Perl::Critic';
author_requires 'Test::Pod';
author_requires 'Test::Spelling';
author_requires 'Pod::Wordlist::hanekomu';
author_requires 'Test::Pod::Coverage';
# author_requires 'Test::Kwalitee';
author_requires 'Test::YAML::Meta';
author_requires 'Test::Portability::Files';
author_requires 'Test::Synopsis';

install_script glob('bin/*');
auto_install;
auto_include;
WriteAll;
