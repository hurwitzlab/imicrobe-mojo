package IMicrobe::Controller::Publication;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;

# ----------------------------------------------------------------------
sub db {
    DBI->connect('dbi:mysql:imicrobe', 'kclark', '', {RaiseError=>1} );
}

# ----------------------------------------------------------------------
sub list {
    my $self = shift;
    my $dbh  = db();
    my $pubs = $dbh->selectall_arrayref(
        q[
            select pub_id, pub_code, journal, author, title
            from   pub
        ],
        { Columns => {} }
    );

    $self->respond_to(
        json => sub {
            $self->render( json => $pubs );
        },

        html => sub {
            $self->layout('default');

            $self->render( pubs => $pubs );
        },

        txt => sub {
            $self->render( text => dump($pubs) );
        },
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self = shift;
    my $pub_id = $self->param('pub_id') or die 'No pub id';
    my $dbh = db();

    my $sth = $dbh->prepare('select * from pub where pub_id=?');
    $sth->execute($pub_id);
    my $pub = $sth->fetchrow_hashref;

    $self->respond_to(
        json => sub {
            $self->render( json => $pub );
        },

        html => sub {
            $self->layout('default');

            $self->render( pub => $pub );
        },

        txt => sub {
            $self->render( text => dump($pub) );
        },
    );
}

1;
