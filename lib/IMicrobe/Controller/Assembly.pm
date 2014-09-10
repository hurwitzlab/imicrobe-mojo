package IMicrobe::Controller::Assembly;

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
    my $assemblies = $dbh->selectall_arrayref(
        q[
            select a.assembly_id, a.assembly_code, a.assembly_name,
                   a.organism, p.project_id, p.project_name
            from   assembly a, project p
            where  a.project_id=p.project_id
        ],
        { Columns => {} }
    );

    $self->respond_to(
        json => sub {
            $self->render( json => $assemblies );
        },

        html => sub {
            $self->layout('default');

            $self->render( assemblies => $assemblies );
        },

        txt => sub {
            $self->render( text => dump($assemblies) );
        },
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self = shift;
    my $assembly_id = $self->param('assembly_id') or die 'No assembly id';
    my $dbh = db();

    my $sth = $dbh->prepare(
        q[
            select a.assembly_id, a.assembly_code, a.assembly_name,
                   a.organism, p.project_id, p.project_name
            from   assembly a, project p
            where  a.assembly_id=?
            and    a.project_id=p.project_id
        ]
    );
    $sth->execute($assembly_id);
    my $assembly = $sth->fetchrow_hashref;

    $self->respond_to(
        json => sub {
            $self->render( json => $assembly );
        },

        html => sub {
            $self->layout('default');

            $self->render( assembly => $assembly );
        },

        txt => sub {
            $self->render( text => dump($assembly) );
        },
    );
}

1;
