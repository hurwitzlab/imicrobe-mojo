package IMicrobe::Controller::Project;

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
    my $projects = $dbh->selectall_arrayref(
        q[
            select    p.project_id, p.project_name, p.project_code,
                      p.pi, p.institution,
                      p.project_type, p.description, 
                      count(s.sample_id) as num_samples
            from      project p 
            left join sample s
            on        p.project_id=s.project_id
            group by  1
        ],
        { Columns => {} }
    );

    $self->respond_to(
        json => sub {
            $self->render( json => $projects );
        },

        html => sub {
            $self->layout('default');

            $self->render( projects => $projects );
        },

        txt => sub {
            $self->render( text => dump($projects) );
        },
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self = shift;
    my $project_id = $self->param('project_id') or die 'No project id';
    my $dbh = db();

    my $sth = $dbh->prepare('select * from project where project_id=?');
    $sth->execute($project_id);
    my $project = $sth->fetchrow_hashref;

    $project->{'samples'} = $dbh->selectall_arrayref(
        'select * from sample where project_id=?', { Columns => {} }, 
        $project_id
    );

    $project->{'assemblies'} = $dbh->selectall_arrayref(
        'select * from assembly where project_id=?', { Columns => {} }, 
        $project_id
    );

    $self->respond_to(
        json => sub {
            $self->render( json => $project );
        },

        html => sub {
            $self->layout('default');

            $self->render( project => $project );
        },

        txt => sub {
            $self->render( text => dump($project) );
        },
    );
}

1;
