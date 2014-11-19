package IMicrobe::Controller::Admin;

use IMicrobe::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;

# ----------------------------------------------------------------------
sub edit_project {
    my $self       = shift;
    my $project_id = $self->param('project_id');

    my $dbh = IMicrobe::DB->new->dbh;
    my $sql = sprintf(
        'select * from project where %s=?',
        $project_id =~ /\D+/ ? 'project_code' : 'project_id'
    );

    my $sth = $dbh->prepare($sql);
    $sth->execute($project_id);
    my $project = $sth->fetchrow_hashref;

    $self->layout('default');
    $self->render( 
        project => $project,
        title   => 'Edit Project',
    );
}

# ----------------------------------------------------------------------
sub update_project {
    my $self       = shift;
    my $req        = $self->req;
    my $project_id = $req->param('project_id');

    my @flds = qw[ 
        project_name pi institution project_code project_type description 
    ];
    my @vals = map { $req->param($_) } @flds;

    my $dbh  = IMicrobe::DB->new->dbh;
    my $sql  = sprintf(
        'update project set %s where project_id=?',
        join(', ', map { "$_=?" } @flds),
    );
        
    $dbh->do($sql, {}, @vals, $project_id);

    return $self->redirect_to('/admin/edit_project', $project_id);
}

1;
