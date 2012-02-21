#!/usr/bin/perl

use strict;
use utf8;
use XML::FeedPP;

my $flag = shift;
my @rsses = do {
    use File::Basename qw/ dirname /;
    my $dname  = dirname(__FILE__);
    glob("$dname/../rss/*.rss");
};

my $feed = do{
    my $date = localtime;
    #XML::FeedPP::Atom::Atom10->new(title => 'grep { $_->{tweets} =~ URLs} qw/Twitter User Stream/',pubDate => $date );
    XML::FeedPP::RSS->new(title => 'grep { $_->{tweets} =~ URLs} qw/Twitter User Stream/',pubDate => $date );
};
foreach (@rsses) {
    $feed->merge ( $_ ) if ( -s $_ );
    rename($_, $_.".bak");
}

print $feed->to_string();
