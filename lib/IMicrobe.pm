package IMicrobe;

use Mojo::Base 'Mojolicious';

sub startup {
    my $self = shift;

    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');
    $self->plugin('tt_renderer');
    $self->plugin('JSONConfig', { file => 'imicrobe.json' });

    # Router
    my $r = $self->routes;

    # Normal route to controller
    $r->get('/')->to('welcome#index');

    $r->get('/index')->to('welcome#index');

    $r->get('/info')->to('welcome#info');

    $r->get('/assembly/list')->to('assembly#list');

    $r->get('/assembly/view/:assembly_id')->to('assembly#view');

    $r->get('/project/browse')->to('project#browse');

    $r->get('/project/list')->to('project#list');

    $r->get('/project/view/:project_id')->to('project#view');

    $r->get('/pubchase/list')->to('pubchase#list');

    $r->get('/publication/list')->to('publication#list');

    $r->get('/publication/view/:pub_id')->to('publication#view');

    $r->get('/sample/list/:project_id')->to('sample#list');

    $r->get('/sample/view/:sample_id')->to('sample#view');

    $r->get('/search')->to('search#results');
}

1;
