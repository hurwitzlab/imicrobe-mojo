package IMicrobe::Controller::Sample;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;

sub dbh {
    return DBI->connect('dbi:mysql:imicrobe', 'imicrobe', '', {RaiseError=>1});
}

# ----------------------------------------------------------------------
sub list {
    my $self = shift;
    my $project_id = $self->param('project_id') or die 'No project id';
    my $dbh = dbh();
    my $samples = $dbh->selectall_arrayref(
        'select * from sample where project_id=?', 
        { Columns => {} }, 
        $project_id
    );

    $self->respond_to(
        json => sub {
            $self->render( json => $samples );
        },

        html => sub {
            $self->render( samples => $samples );
        },

        txt => sub {
            $self->render( text => dump($samples) );
        },
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self = shift;
    my $sample_id = $self->param('sample_id') or die 'No sample id';
    my $dbh = dbh();
    my $sth = $dbh->prepare(
        q[
            select s.*, p.*
            from   sample s, project p
            where  s.sample_id=?
            and    s.project_id=p.project_id
        ]
    );
    $sth->execute($sample_id);
    my $sample = $sth->fetchrow_hashref;

    $self->respond_to(
        json => sub {
            $self->render( json => $sample );
        },

        html => sub {
            $self->layout('default');

            $self->render( sample => $sample );
        },

        txt => sub {
            $self->render( text => dump($sample) );
        },
    );
}

1;
