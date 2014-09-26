package IMicrobe::Controller::Welcome;

use Data::Dump 'dump';
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub index {
    my $self = shift;

    my @routes = sort (
        grep { /\S+/ }
        map  { $_->to_string   }
        grep { $_->is_endpoint }
        @{ $self->app->routes->children }
    );

    $self->respond_to(
        json => sub {
            $self->render( json => \@routes );
        },

        html => sub {
            $self->layout('default');
            $self->render();
        },

        txt => sub {
            $self->render( text => dump(\@routes) );
        },
    );
}

1;
