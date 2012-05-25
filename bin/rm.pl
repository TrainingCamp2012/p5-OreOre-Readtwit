#!/usr/bin/perl
 
use strict;
my $flag = shift;
 
my @rsses = do {
    glob("/tmp/RSS/*.rss.bak");
};
 
if ( defined $flag ){
    print $_ for @rsses;
} else {
    unlink @rsses;
}
