package OreOre::Readtwit;
use strict;
use warnings;
our $VERSION = '0.01';

use YAML;
use AnyEvent::Twitter::Stream;
use Regexp::Assemble;
use Regexp::Common;
use File::Temp qw(tempfile);
use FindBin::libs;
use OreOre::Readtwit::Util::ShortUrlExpand;

sub new {
    my($class, %opt) = @_;

    my $self = bless {
        conf => {},
    }, $class;

    #プラグインにしましょう
    my $yaml = YAML::LoadFile($opt{config});
    my $http = '^https?://(www.)?';
    my $expander = OreOre::Readtwit::Util::ShortUrlExpand->new(%{$yaml->{expander}});
    $self->{conf} = +{
        deny_id => Regexp::Assemble->new()->track->add( @{ delete $yaml->{id} } ),
        deny_hashtag => Regexp::Assemble->new()->track->add( map { "^$_\$" } @{ delete $yaml->{hashtag} } ),
        deny_client => Regexp::Assemble->new()->track->add( @{ $yaml->{client} }),
        deny_url => Regexp::Assemble->new()->track->add( map { qq{$http$_} }  @{ delete $yaml->{url} }),
        oauth => $opt{pit} || delete $yaml->{oauth},
        %{$yaml},
    };
    $self->{conf}->{expander} = $expander;

    $self;
}

sub ignore {
    my($self,$tweet) = @_;
    return 1 if !defined $tweet->{entities}{urls};
    return 1 if defined $self->conf->{deny_id}->match($tweet->{user}{screen_name});
    foreach (@{$tweet->{entries}{hashtags}}) {
        return 1 if $self->conf->{deny_hashtag}->match($_->{text});
    }
    return 0;
}
sub on_tweet {
    my($self, $tweet) = @_;
    return if $self->ignore($tweet);

    $self->feedgen($tweet);
}

use XML::FeedPP;
use URI;
use POSIX qw/setlocale LC_TIME/;
use Time::Piece;

sub feedgen {
    my($self, $tweet) = @_;

    #$tweet->{text} =~ s/$RE{URI}{HTTP}/$self->conf->{expander}->expand($&)/ge ;

    my $pubdate = do {
        my $time = $tweet->{created_at};
        my $ffmt = '%Y-%m-%dT%H:%M:%S%z';
        my $pfmt = '%a %b %d %H:%M:%S %z %Y';
        my $old_locale = setlocale(LC_TIME);
        setlocale(LC_TIME,"C");
        my $t = Time::Piece->strptime($time, $pfmt)->strftime($ffmt);
        setlocale(LC_TIME,$old_locale);
        $t;
    };
    my $feed   = XML::FeedPP::RSS->new(
        language => 'ja',
        pubDate  => $pubdate,
    );

    my @urls = map {
        defined $_->{expanded_url} ? $_->{expanded_url} : $_->{url}
    } @{$tweet->{entities}{urls}} ;

    foreach (@urls) {
        my $url = URI->new($self->conf->{expander}->expand($_));
        next if ($url =~ $self->conf->{deny_url}->re);
        $feed->add_item(
            link        => "$url",
            title       => $tweet->{user}{screen_name},
            description => \$tweet->{text},
            pubDate     => $pubdate,
            author      => \$tweet->{user}{screen_name},
        );
    }

    if ($feed->get_item()) {
        (undef, my $filename) = tempfile(
            "twitterXXXXX",
            DIR    => $self->conf->{dir},
            SUFFIX => ".rss",
        );
        $feed->to_file($filename);
    }
}

sub conf {
    my $self = shift;
    $self->{conf};
}

sub bootstrap {
    my $class = shift;
    my $self = $class->new(@_);
    $self->run();
    $self;
}

sub run {
    my $self = shift;
    my $done = AE::cv;
    my $connected;
    my $streamer; $streamer = AnyEvent::Twitter::Stream->new(
        consumer_key    => $self->conf->{oauth}->{consumer_key},
        consumer_secret => $self->conf->{oauth}->{consumer_secret},
        token           => $self->conf->{oauth}->{access_token},
        token_secret    => $self->conf->{oauth}->{access_token_secret},
        method          => 'userstream',
        timeout         => 45,
        on_tweet => sub {
            $connected = 1 unless $connected;
            $self->on_tweet(@_);
        },
        on_error => sub {
            my $error = shift;
            $self->log(warn => "$error");
            $done->send;
        },
        on_eof => sub {
            $self->log(info => "Catch a EOF");
            $done->send;
        },
        on_keepalive => sub {
            $self->log(info => "Catch a KeepAlive");
            $connected = 1 unless $connected;
        },
    );

    $done->recv;
    undef $streamer;

    my $wait = $connected ? 0 : 2;

    my $wait_cv = AE::cv;
    my $wait_t = AE::timer $wait, 0, $wait_cv;
    $wait_cv->recv;

}

sub log {
    my($self, $level, $msg, %opt) = @_;

    return unless $self->should_log($level);

    chomp($msg);

    warn "[$level] $msg\n";
}

my %levels = (
    debug => 0,
    warn  => 1,
    info  => 2,
    error => 3,
);

sub should_log {
    my($self, $level) = @_;
    $levels{$level} >= $levels{$self->conf->{log}->{level}};
}
1;
__END__

=head1 NAME

OreOre::Readtwit -

=head1 SYNOPSIS

  use OreOre::Readtwit;

=head1 DESCRIPTION

OreOre::Readtwit is

=head1 AUTHOR

Tor Ozaki E<lt>tor.ozaki@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
