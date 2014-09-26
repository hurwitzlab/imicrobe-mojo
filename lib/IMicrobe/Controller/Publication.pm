package IMicrobe::Controller::Publication;

use IMicrobe::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;

# ----------------------------------------------------------------------
sub list {
    my $self = shift;
    my $dbh  = IMicrobe::DB->new->dbh;
    my $pubs = $dbh->selectall_arrayref(
        q[
            select publication_id, pub_code, pub_date, journal, 
                   author, title, pubmed_id
            from   publication
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
    my $self   = shift;
    my $pub_id = $self->param('pub_id') or die 'No pub id';
    my $dbh    = IMicrobe::DB->new->dbh;

    my $sth = $dbh->prepare('select * from publication where publication_id=?');

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
