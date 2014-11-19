package IMicrobe::Controller::Assembly;

use IMicrobe::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;

# ----------------------------------------------------------------------
sub list {
    my $self       = shift;
    my $dbh        = IMicrobe::DB->new->dbh;
    my $assemblies = $dbh->selectall_arrayref(
        q[
            select a.assembly_id, a.assembly_code, a.assembly_name,
                   a.organism, a.cds_file, a.nt_file, a.pep_file,
                   p.project_id, p.project_name
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

            $self->render( 
                assemblies => $assemblies,
                title      => 'Assemblies',
            );
        },

        txt => sub {
            $self->render( text => dump($assemblies) );
        },
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self        = shift;
    my $assembly_id = $self->param('assembly_id');
    my $dbh         = IMicrobe::DB->new->dbh;

    my $sth = $dbh->prepare(
        q[
            select a.assembly_id, a.assembly_code, a.assembly_name,
                   a.organism, a.cds_file, a.nt_file, a.pep_file,
                   p.project_id, p.project_name
            from   assembly a, project p
            where  a.assembly_id=?
            and    a.project_id=p.project_id
        ]
    );
    $sth->execute($assembly_id);
    my $assembly = $sth->fetchrow_hashref;

    if (!$assembly) {
        return $self->reply->exception("Bad assembly id ($assembly_id)");
    }

    $self->respond_to(
        json => sub {
            $self->render( json => $assembly );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                assembly => $assembly,
                title    => sprintf('Assembly: %s', 
                    $assembly->{'assembly_name'} || $assembly->{'organism'}
                ),
            );
        },

        txt => sub {
            $self->render( text => dump($assembly) );
        },
    );
}

1;
