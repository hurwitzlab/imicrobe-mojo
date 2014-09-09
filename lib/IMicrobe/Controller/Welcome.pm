package IMicrobe::Controller::Welcome;

use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub home {
    my $self = shift;

    $self->layout('default');
    $self->render();
}

1;
