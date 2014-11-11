package IMicrobe::Controller::Pubchase;

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
            select   pubchase_id, article_id, title, journal_title, doi,
                     list_of_authors, article_date, created_on, url
            from     pubchase
            order by article_date desc, title
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
