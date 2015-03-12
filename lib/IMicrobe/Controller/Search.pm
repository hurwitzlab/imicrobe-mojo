package IMicrobe::Controller::Search;

use IMicrobe::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;
use MongoDB;

# ----------------------------------------------------------------------
sub info {
    my $self = shift;

    $self->respond_to(
        json => sub {
            $self->render(json => { 
                search => {
                    params => {
                        query => {
                            type => 'str',
                            desc  => 'a string to search',
                            required => 'true',
                        }
                    },
                    results => 'a list of matching documents',
                }
            });
        },
    );

}

# ----------------------------------------------------------------------
sub results2 {
    my $self    = shift;
    my $req     = $self->req;
    my $session = $self->session;
    my $ip      = $self->session('ip')
               || $self->req->headers->header('X-Forwarded-For');
    my $id      = $self->session('user_id') || _make_id( $ip );
    my $query   = $req->param('query') || '';
    my $db      = IMicrobe::DB->new;
    my $dbh     = $db->dbh;
    my $mongo   = MongoDB::MongoClient->new(host => 'localhost', port => 27017);
    my $mdb     = $mongo->get_database('imicrobe');

    $self->session(user_id => $id);
    $self->session(ip => $ip);

    my @results;
    my %types;
    if ($query) {
        my @data;
        my @colls = qw(
            assembly combined_assembly project project_page publication sample
        );

        for my $coll_name (@colls) {
            my $coll   = $mdb->get_collection($coll_name);
            my $cursor = $coll->query({ "text" => { '$regex' => qr/$query/i }});
            while (my $rec = $cursor->next) {
                $rec->{'table_name'}  = $coll_name;
                push @data, $rec;
            }
        }

        for my $r (@data) {
            $types{ $r->{'table_name'} }++;

            my $sql = sprintf('select * from %s where %s=?', 
                $r->{'table_name'}, $r->{'table_name'} . '_id'
            );

            my $sth = $dbh->prepare($sql);
            $sth->execute($r->{'primary_key'});
            $r->{'object'} = $sth->fetchrow_hashref();
            $r->{'url'}    = join '/', 
                '', $r->{'table_name'}, 'view', $r->{'primary_key'};

            push @results, $r;
        }

        $db->schema->resultset('QueryLog')->create({
            ip        => $ip,
            user_id   => $session->{'user_id'},
            query     => $query,
            num_found => scalar @results,
        });
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
                title   => "Search results for $query",
                results => \@results,
                query   => $query,
                types   => \%types
            );
        },

        txt => sub {
            $self->render( text => dump(\@results) );
        },

        tab => sub {
            my $text = '';

            if (@results) {
                my @flds = sort keys %{ $results[0] };
                my @data = (join "\t", @flds);
                for my $res (@results) {
                    push @data, join "\t", 
                        map { ref $res->{$_} ? '-' : $res->{$_} // '' } 
                        @flds;
                }
                $text = join "\n", @data;
            }

            $self->render( text => $text );
        },
    );
}

# ----------------------------------------------------------------------
sub results {
    my $self    = shift;
    my $req     = $self->req;
    my $session = $self->session;
    my $ip      = $self->session('ip')
               || $self->req->headers->header('X-Forwarded-For');
    my $id      = $self->session('user_id') || _make_id( $ip );
    my $query   = $req->param('query') || '';
    my $db      = IMicrobe::DB->new;
    my $dbh     = $db->dbh;

    $self->session(user_id => $id);
    $self->session(ip => $ip);

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
            $r->{'url'}    = join '/', 
                '', $r->{'table_name'}, 'view', $r->{'primary_key'};

            push @results, $r;
        }

        $db->schema->resultset('QueryLog')->create({
            ip        => $ip,
            user_id   => $session->{'user_id'},
            query     => $query,
            num_found => scalar @results,
        });
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
                title   => "Search results for $query",
                results => \@results,
                query   => $query,
                types   => \%types
            );
        },

        txt => sub {
            $self->render( text => dump(\@results) );
        },

        tab => sub {
            my $text = '';

            if (@results) {
                my @flds = sort keys %{ $results[0] };
                my @data = (join "\t", @flds);
                for my $res (@results) {
                    push @data, join "\t", 
                        map { ref $res->{$_} ? '-' : $res->{$_} // '' } 
                        @flds;
                }
                $text = join "\n", @data;
            }

            $self->render( text => $text );
        },
    );
}

# ----------------------------------------------------------------------
sub _make_id {
    my ($c, $ip) = @_;
    my $md5  = Digest::MD5->new;
    my $id   = $md5->md5_base64( time, $$, $ip, int(rand(10)) );

    $id =~ tr|+/=|-_.|;  # Make non-word chars URL-friendly

    return $id;
}

1;
