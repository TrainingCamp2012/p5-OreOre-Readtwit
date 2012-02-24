use strict;
use warnings;
use AnyEvent;
use AnyEvent::Twitter::Stream;
use AnyEvent::Util qw(guard);
use Data::Dumper;
use JSON;
use Test::More;
use Test::TCP;
use Test::Requires qw(Plack::Builder Plack::Handler::Twiggy Try::Tiny);
use Test::Requires { 'Plack::Request' => '0.99' };


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

            {
                my $done = AE::cv;
                my $streamer = AnyEvent::Twitter::Stream->new(
                    username => 'test',
                    password => 's3cr3t',
                    method => $item->{method},
                    timeout => 2,
                    on_tweet => sub {
                        my $tweet = shift;

                        #if ($tweet->{hello}) {
                        #    note(Dumper $tweet);
                        #    is($tweet->{user}, 'test');
                        #    is($tweet->{path}, "/1/statuses/$item->{method}.json");
                        #    is_deeply($tweet->{param}, $item->{option});

                        #    if (%{$item->{option}}) {
                        #        is($tweet->{request_method}, 'POST');
                        #    } else {
                        #        is($tweet->{request_method}, 'GET');
                        #    }
                        #} else {
                        $done->send, return if $tweet->{count} > $count_max;
                        #}

                        $received++;
                    },
                    on_delete => sub {
                        my ($tweet_id, $user_id) = @_;
                        $deleted++;
                        $received++;
                    },
                    on_friends => sub {
                        my $friends = shift;
                        is_deeply($friends, [qw/1 2 3/]);
                    },
                    on_event => sub {
                        $event++;
                        $done->send;
                    },
                    on_error => sub {
                        my $msg = $_[2] || $_[0];
                        fail("on_error: $msg");
                        $done->send;
                    },
                    %{$item->{option}},
                );
                $streamer->{_guard_for_testing} = guard { $destroyed = 1 };

                $done->recv;
            }

            is $deleted, 0, 'deleted no tweet';

            is $event, 1, 'got one event';
            is $destroyed, 1, 'destroyed';
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
                        event => {foo => 'bar'},
                    }) . "\x0D\x0A");
                }catch{
                    undef $t;
                };
            });
        };
    };

    my $app = builder {
        enable 'Auth::Basic', realm => 'Firehose', authenticator => sub {
            my ($user, $pass) = @_;

            return $user eq 'test' && $pass eq 's3cr3t';
        };
        enable 'Chunked' if $enable_chunked;

        mount '/2/' => $user_stream;
    };

    my $server = Plack::Handler::Twiggy->new(
        host => '127.0.0.1',
        port => $port,
    )->run($app);
}
