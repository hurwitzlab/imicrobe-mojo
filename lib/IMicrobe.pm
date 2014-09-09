package IMicrobe;

use Mojo::Base 'Mojolicious';

sub startup {
    my $self = shift;

    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');
    $self->plugin('tt_renderer');

    # Router
    my $r = $self->routes;

    # Normal route to controller
    #$r->get('/')->to('welcome#home');

    $r->get('/')->to('project#list');

    $r->get('/project/list')->to('project#list');

    $r->get('/project/view/:project_id')->to('project#view');

    $r->get('/sample/list/:project_id')->to('sample#list');

    $r->get('/search')->to('search#results');
}

1;
