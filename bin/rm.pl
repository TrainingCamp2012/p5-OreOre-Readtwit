#!/usr/bin/perl
 
use strict;
my $flag = shift;
 
my @rsses = do {
    use File::Basename qw/ dirname /;
    my $dname  = dirname(__FILE__);
    glob("$dname/../rss/*.rss.bak");
};
 
if ( defined $flag ){
    print $_ for @rsses;
} else {
    unlink @rsses;
}
