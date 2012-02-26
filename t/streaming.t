use strict;
use warnings;
use AnyEvent::Twitter::Stream;
use JSON;
use YAML;
use Test::More;
use Test::TCP;
use Test::Requires qw(Plack::Builder Plack::Handler::Twiggy Try::Tiny);
use Test::Requires { 'Plack::Request' => '0.99' };
use Hook::LexWrap;
use FindBin;
use File::Temp;
use File::Compare;
use XML::FeedPP;

use OreOre::Readtwit;

foreach my $enable_chunked (0, 1) {
    test_tcp(
        client => sub {
            my $port = shift;

            local $AnyEvent::Twitter::Stream::STREAMING_SERVER  = "127.0.0.1:$port";
            local $AnyEvent::Twitter::Stream::USERSTREAM_SERVER = "127.0.0.1:$port";
            local $AnyEvent::Twitter::Stream::US_PROTOCOL       = "http";
            local $AnyEvent::Twitter::Stream::PROTOCOL          = 'http'; # real world API uses https

            my $item = {
                method => 'userstream',
                option => {},
            };
            my $destroyed;
            my $received = 0;
            my $count_max = 5;
            my ($deleted, $event) = (0, 0);

            note("try $item->{method}");

            my @filenames;
            wrap 'File::Temp::tempfile',
                post => sub {
                    push @filenames,$_[-1]->[1];
            };
            my $readtwit = OreOre::Readtwit->new(
                config => "$FindBin::Bin/config.yml",
            );

            ok( $readtwit->run(),"readtwit run");
            my $reference_file = "$FindBin::Bin/sample.rss";
            ok( compare($filenames[0],$reference_file) == 0);

            my $output = XML::FeedPP::RSS->new($filenames[0]);
            ok( $output->link, "http://instagr.am/p/MuW67/", "expanded url");

            $reference->
            note("delete temp files");
            unlink $_ for @filenames;


        },
        server => sub {
            my $port = shift;

            run_streaming_server($port, $enable_chunked);
        },
    );
}

done_testing();

sub run_streaming_server {
    my ($port, $enable_chunked) = @_;

    my $user_stream = sub {
        my $env = shift;
        my $req = Plack::Request->new($env);

        return sub {
            my $respond = shift;

            my $writer = $respond->([200, [
                'Content-Type' => 'application/json',
                'Server' => 'Jetty(6.1.17)',
            ]]);
            $writer->write(encode_json({
                friends => [qw/1 2 3/],
            }) . "\x0D\x0A");

            my $t; $t = AE::timer(0, 0.2, sub {
                    try {
                        $writer->write(encode_json({
                                    created_at => "Sat Sep 10 22:23:38 +0000 2011",
                                    entities => {
                                        hashtags => [
                                            {
                                                indices => [
                                                    32,
                                                    42
                                                ],
                                                text => "tcdisrupt"
                                            }
                                        ],
                                        urls => [
                                            {
                                                display_url => "instagr.am/p/MuW67/",
                                                expanded_url => "http://instagr.am/p/MuW67/",
                                                indices => [
                                                    67,
                                                    86
                                                ],
                                                url => "http://t.co/6J2EgYM"
                                            }
                                        ],
                                    },
                                    source => "<a href=\"http://instagr.am\" rel=\"nofollow\">Instagram</a>",
                                    text => "\@twitter meets \@seepicturely at #tcdisrupt cc.\@boscomonkey \@episod http://t.co/6J2EgYM",
                                    user => {
                                        name => "Eoin McMillan ",
                                        screen_name => "imeoin",
                                    }
                                }) . "\x0D\x0A");
                }catch{
                    undef $t;
                };
                $writer->close if rand > 0.8;
            });
        };
    };

    my $app = builder {
        enable 'Chunked' if $enable_chunked;

        mount '/2/' => $user_stream;
    };

    my $server = Plack::Handler::Twiggy->new(
        host => '127.0.0.1',
        port => $port,
    )->run($app);
}
