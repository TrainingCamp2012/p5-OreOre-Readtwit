use inc::Module::Install;
name 'OreOre-Readtwit';
all_from 'lib/OreOre/Readtwit.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
