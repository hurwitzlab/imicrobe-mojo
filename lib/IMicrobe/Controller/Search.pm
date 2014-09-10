package IMicrobe::Controller::Search;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;

# ----------------------------------------------------------------------
sub db {
    DBI->connect('dbi:mysql:imicrobe', 'kclark', '', {RaiseError=>1} );
}

# ----------------------------------------------------------------------
sub results {
    my $self  = shift;
    my $req   = $self->req;
    my $query = $req->param('query') || '';
    my $dbh   = db();

    my @results;
    if ($query) {
        my $sql = sprintf(
            "select * from search where match (search_text) against (%s)",
            $dbh->quote($query)
        );

        my $data = $dbh->selectall_arrayref($sql, { Columns => {} });

        for my $r (@$data) {
            my $sql = sprintf('select * from %s where %s=?', 
                $r->{'table_name'}, $r->{'table_name'} . '_id'
            );

            my $sth = $dbh->prepare($sql);
            $sth->execute($r->{'primary_key'});
            $r->{'object'} = $sth->fetchrow_hashref();

            push @results, $r;
        }
    }

    $self->respond_to(
        json => sub {
            $self->render( json => \@results );
        },

        html => sub {
            $self->layout('default');

            $self->render( results => \@results, query => $query );
        },

        txt => sub {
            $self->render( text => dump(\@results) );
        },
    );
}

1;
