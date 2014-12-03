package IMicrobe::Controller::ProjectPage;

use strict;
use IMicrobe::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';

# ----------------------------------------------------------------------
sub view {
    my $self  = shift;
    my $pp_id = $self->param('project_page_id');
    my $db    = IMicrobe::DB->new;
    my $Page  = $db->schema->resultset('ProjectPage')->find($pp_id);

    if (!$Page) {
        return $self->reply->exception("Bad project page id ($pp_id)");
    }

    $self->respond_to(
        json => sub {
            $self->render( json => { $Page->get_inflated_columns() } );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                title => sprintf("Project Page: %s", $Page->title),
                page  => $Page,
            );
        },

        txt => sub {
            $self->render( text => dump({$Page->get_inflated_columns()}) );
        },
    );
}

1;
