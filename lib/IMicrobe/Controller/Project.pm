package IMicrobe::Controller::Project;

use IMicrobe::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;

# ----------------------------------------------------------------------
sub list {
    my $self     = shift;
    my $dbh      = IMicrobe::DB->new->dbh;
    my $projects = $dbh->selectall_arrayref(
        q[
            select    p.project_id, p.project_name, p.project_code,
                      p.pi, p.institution,
                      p.project_type, p.description, 
                      read_file, meta_file, assembly_file, peptide_file,
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
    my $self       = shift;
    my $project_id = $self->param('project_id') or die 'No project id';

    my $dbh = IMicrobe::DB->new->dbh;
    my $sql = sprintf(
        'select * from project where %s=?',
        $project_id =~ /\D+/ ? 'project_code' : 'project_id'
    );
    my $sth = $dbh->prepare($sql);
    
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
