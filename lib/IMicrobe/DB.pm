package IMicrobe::DB;

use namespace::autoclean;
use Moose;

has dbh => (
    is         => 'rw',
    isa        => 'DBI::db',
    lazy_build => 1,
);

# ----------------------------------------------------------------
sub _build_dbh {
    my $self = shift;
    my $dbh  = DBI->connect(
        'dbi:mysql:imicrobe', 'kclark', '', { RaiseError => 1}
    );
    return $dbh;
}

1;
