package OreOre::Readtwit;
use strict;
use warnings;
our $VERSION = '0.01';

use AnyEvent::Twitter::Stream;

sub new {
    my($class, %opt) = @_;

    my $self = bless {
        #
    }, $class;

    $self;
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
        consumer_key    => $self->{config}->{consumer_key},
        consumer_secret => $self->{config}->{consumer_secret},
        token           => $self->{config}->{access_token},
        token_secret    => $self->{config}->{access_token_secret},
        method          => 'userstream',
        timeout         => 45,
        on_tweet => sub {
            $connected = 1 unless $connected;
            $self->{on_tweet}->(@_);
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
