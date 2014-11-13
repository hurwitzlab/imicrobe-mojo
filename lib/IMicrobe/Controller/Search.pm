package IMicrobe::Controller::Search;

use IMicrobe::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;

# ----------------------------------------------------------------------
sub results {
    my $self  = shift;
    my $req   = $self->req;
    my $query = $req->param('query') || '';
    my $dbh   = IMicrobe::DB->new->dbh;

    my @results;
    my %types;
    if ($query) {
        my $sql = sprintf(
            "select * from search where match (search_text) against (%s)",
            $dbh->quote($query)
        );

        if (my $type = $req->param('type')) {
            $sql .= sprintf(" and table_name=%s", $dbh->quote($type));
        }

        my $data = $dbh->selectall_arrayref($sql, { Columns => {} });

        for my $r (@$data) {
            $types{ $r->{'table_name'} }++;

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
            $self->render(json => { 
                query   => $query, 
                results => \@results,
                types   => \%types,
            });
        },

        html => sub {
            $self->layout('default');

            $self->render(
                results => \@results,
                query   => $query,
                types   => \%types
            );
        },

        txt => sub {
            $self->render( text => dump(\@results) );
        },
    );
}

1;
