package OreOre::Readtwit::Util::ShortUrlExpand;

our $VERSION = '0.01';

use Any::Moose;
use Any::Moose '::Util::TypeConstraints';
use Regexp::Assemble;
use Furl::HTTP;
use Furl::Headers;
use namespace::autoclean;

has 're' => (
    is => 'ro',
    isa => 'Regexp::Assemble',
    lazy_build => 1,
);

sub _build_re {
    my $self = shift;
    my $re = Regexp::Assemble->new;
    if($self->has_source) {
        require JSON;
        my $res = ($self->ua->get($self->source))[4]
            or die "Unabel to get ShortUrlServices: $!";
        for my $row ( @{ JSON::from_json( $res) } )
        {
            $re->add($row->{data}->{domain});
        }
    } else {
        require WebService::Wedata;
        my $wedata = WebService::Wedata->new;
        my $db = $wedata->get_database('ShortUrlServices');
        foreach my $item (@{$db->get_items}){
            $re->add($item->{data}->{domain});
        }
    }
    $re;
}

has 'ua' => (
    is => 'ro',
    isa => 'Furl::HTTP',
    default => sub { Furl::HTTP->new(
            max_redirects => 0,
            agent => "Furl/$Furl::VERSION URI::ReURL ver:$VERSION",
        ) },
);

has 'source' => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_source',
);

__PACKAGE__->meta->make_immutable();
no Any::Moose;

sub expand {
    my ($self,$url) = @_;

    while (defined ($self->re->match($url)))
    {
        my $res = ($self->ua->head($url))[3] or return $url;
        my $fh = Furl::Headers->new($res);
        last unless defined $fh->header('Location');
        $url = $fh->header('Location');
    }

    $url;
}

1;
