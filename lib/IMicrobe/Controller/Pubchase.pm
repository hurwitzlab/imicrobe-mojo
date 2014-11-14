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
            select   pubchase_id, article_id, title, journal_title, 
                     doi, authors, article_date, created_on, url
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

            $self->render( 
                pubs  => $pubs,
                title => 'Pubchase Recommendations',
            );
        },

        txt => sub {
            $self->render( text => dump($pubs) );
        },
    );
}

1;
