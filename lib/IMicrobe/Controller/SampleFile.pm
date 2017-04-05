package IMicrobe::Controller::SampleFile;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use String::Trim qw(trim);

# ----------------------------------------------------------------------
sub view {
    my $self         = shift;
    my $schema       = $self->db->schema;
    my $file_id      = $self->param('sample_file_id');
    my ($SampleFile) = $schema->resultset('SampleFile')->find($file_id);

    if (!$SampleFile) {
        return $self->reply->exception("Bad sample file id ($file_id)");
    }

    $self->respond_to(
        json => sub {
            $self->render( json => { sample_file => $SampleFile } );
        },

        html => sub {
            $self->layout('default');
            $self->render( title => 'Sample File', sample_file => $SampleFile );
        },

        txt => sub {
            $self->render( text => dump($SampleFile) );
        },
    );
}

1;
