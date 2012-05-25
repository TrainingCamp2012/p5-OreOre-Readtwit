#!/usr/bin/perl

use strict;
use utf8;
use List::Util qw/shuffle/;
use List::MoreUtils qw/before/;
use XML::FeedPP;

my $count = 0;
my @rsses = before { ++$count > 50 } shuffle glob("/tmp/RSS/*.rss");

my $date = localtime;
my $feed = XML::FeedPP::RSS->new(
    title => 'grep { $_->{tweets} =~ URL} qw/User Stream/',
    pubDate => $date,
);

foreach (@rsses) {
    $feed->merge ( $_ ) if ( -s $_ );
    rename($_, $_.".bak");
}

print $feed->to_string();
