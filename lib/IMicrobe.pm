package IMicrobe;

use Mojo::Base 'Mojolicious';

use lib '/usr/local/imicrobe/lib';
use IMicrobe::DB;

sub startup {
    my $self = shift;

    $self->plugin('tt_renderer');

    $self->plugin('JSONConfig', { file => 'imicrobe.json' });

    $self->sessions->default_expiration(86400);

    my $r = $self->routes;

    # 
    # Admin endpoints
    # 
    $r->get('/admin')->to('admin#index');

    $r->get('/admin/list_projects')->to('admin#list_projects');

    $r->get('/admin/list_publications')->to('admin#list_publications');

    $r->post('/admin/create_project_page')->to('admin#create_project_page');

    $r->post('/admin/create_project_pub')->to('admin#create_project_pub');

    $r->get('/admin/create_project_pub_form/:project_id')->to('admin#create_project_pub_form');

    $r->post('/admin/create_publication')->to('admin#create_publication');

    $r->get('/admin/create_publication_form')->to('admin#create_publication_form');

    $r->get('/admin/create_project_page_form/:project_id')->to('admin#create_project_page_form');

    $r->post('/admin/delete_project_page/:project_page_id')->to('admin#delete_project_page');

    $r->post('/admin/delete_project_pub/:publication_id')->to('admin#delete_project_pub');

    $r->post('/admin/delete_publication/:publication_id')->to('admin#delete_publication');

    $r->get('/admin/edit_project_page/:project_page_id')->to('admin#edit_project_pub');

    $r->get('/admin/edit_project_publications/:project_id')->to('admin#edit_project_publications');

    $r->get('/admin/edit_sample/:sample_id')->to('admin#edit_sample');

    $r->post('/admin/update_project_page')->to('admin#update_project_page');

    $r->get('/admin/home_publications')->to('admin#home_publications');

    $r->get('/admin/edit_project/:project_id')->to('admin#edit_project');

    $r->get('/admin/view_project/:project_id')->to('admin#view_project');

    $r->get('/admin/view_project_pages/:project_id')->to('admin#view_project_pages');

    $r->get('/admin/view_project_samples/:project_id')->to('admin#view_project_samples');

    $r->get('/admin/view_publication/:publication_id')->to('admin#view_publication');

    $r->post('/admin/update_project')->to('admin#update_project');

    $r->post('/admin/update_publication')->to('admin#update_publication');

    $r->post('/admin/update_sample')->to('admin#update_sample');

    #
    # User endpoints
    #
    $r->get('/')->to('welcome#index');

    $r->get('/assembly/info')->to('assembly#info');

    $r->get('/assembly/list')->to('assembly#list');

    $r->get('/assembly/view/:assembly_id')->to('assembly#view');

    $r->get('/combined_assembly/info')->to('combined_assembly#info');

    $r->get('/combined_assembly/list')->to('combined_assembly#list');

    $r->get('/combined_assembly/view/:combined_assembly_id')->to('combined_assembly#view');

    $r->get('/download')->to('download#format');

    $r->post('/download/get')->to('download#get');

    $r->get('/feedback')->to('feedback#form');

    $r->post('/feedback/submit')->to('feedback#submit');

    $r->get('/index')->to('welcome#index');

    $r->get('/info')->to('welcome#index');

    $r->get('/project/info')->to('project#info');

    $r->get('/project/browse')->to('project#browse');

    $r->get('/project/list')->to('project#list');

    $r->get('/project/project_file_list/:project_id')->to('project#project_file_list');

    $r->get('/project/view/:project_id')->to('project#view');

    $r->get('/project_page/info')->to('project_page#info');

    $r->get('/project_page/view/:project_page_id')->to('project_page#view');

    $r->get('/pubchase/info')->to('pubchase#info');

    $r->get('/pubchase/list')->to('pubchase#list');

    $r->get('/publication/info')->to('publication#info');

    $r->get('/publication/list')->to('publication#list');

    $r->get('/publication/view/:publication_id')->to('publication#view');

    $r->get('/reference/info')->to('reference#info');

    $r->get('/reference/list')->to('reference#list');

    $r->get('/reference/view/:reference_id')->to('reference#view');

    $r->get('/sample/info')->to('sample#info');

    $r->get('/sample/list')->to('sample#list');

    $r->get('/sample/map_search')->to('sample#map_search');

    $r->get('/sample/map_search_results')->to('sample#map_search_results');

    $r->get('/sample/sample_file_list/:sample_id')->to('sample#sample_file_list');

    $r->get('/sample/search')->to('sample#search');

    $r->get('/sample/search_params')->to('sample#search_params');

    $r->get('/sample/search_param_values/:field')->to('sample#search_param_values');

    $r->get('/sample/search_results')->to('sample#search_results');

    $r->get('/sample/search_results_map')->to('sample#search_results_map');

    $r->get('/sample/view/:sample_id')->to('sample#view');

    $r->get('/search')->to('search#results');

    $r->get('/search/info')->to('search#info');

    $self->hook(
        before_render => sub {
            my ($c, $args) = @_;

            return unless my $template = $args->{'template'};

            $args->{'config'} = $c->config;

            if ($c->accepts('html')) {
                $args->{'title'} //= ucfirst $template;
                $c->layout('default');
            }
            elsif ($c->accepts('json')) {
                $args->{'json'} = {
                    status    => $args->{'status'},
                    exception => $args->{'exception'},
                };
            }
        }
    );

    $self->hook(
        after_dispatch => sub {
            my $c = shift;
            if ( defined $c->param('download') ) {
                $c->res->headers->add(
                    'Content-type' => 'application/force-download' 
                );
                
                (my $file = $c->req->url->path) =~ s{.+/}{};
                my $name = $c->param('download') || '';

                if ($name =~ /\D/) {
                    $file = $name;
                }

                $c->res->headers->add(
                    'Content-Disposition' => qq[attachment; filename=$file] 
                );
            }
        }
    );

    $self->helper(
        db => sub {
            my $self   = shift;
            my $config = $self->config;
            return IMicrobe::DB->new($config->{'db'});
        }
    );
}

1;
