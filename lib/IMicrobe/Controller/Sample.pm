package IMicrobe::Controller::Sample;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;
#use IMicrobe::DB;

# This action will render a template
sub list {
    my $self = shift;
    my $project_id = $self->param('project_id') or die 'No project id';
    #my $dbh = IMicrobe::DB->new->dbh;
    my $dbh = DBI->connect('dbi:mysql:imicrobe', 'imicrobe', '', {RaiseError=>1});
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

1;
