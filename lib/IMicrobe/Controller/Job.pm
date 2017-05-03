package IMicrobe::Controller::Job;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use JSON::XS qw'encode_json decode_json';

# ----------------------------------------------------------------------
sub list {
    my $self    = shift;
    my $limit   = $self->param('limit') || 0;
    my $token   = $self->session->{'token'};
    my $access  = $token->{'access_token'};
    my $ua      = Mojo::UserAgent->new;
    my $url     = sprintf("https://agave.iplantc.org/jobs/v2%s",
                      $limit ? "?limit=$limit" : '');
    my $res     = $ua->get($url => { Authorization => "Bearer $access" })->res;
    my $result  = decode_json($res->body);
    my $jobs    = sub {
        if ($result->{'status'} eq 'success') {
            $result->{'result'};
        }
        else {
            $res->body;
        }
    };

    $self->respond_to(
        html => sub {
            # so I can access the "job._links"
            $Template::Stash::PRIVATE = undef; 
            $self->layout('default');
            $self->render(result => $result);
        },

        json => sub {
            $self->render( json => $jobs->() );
        },

        tab => sub {
            my $data = $jobs->();
            my $out  = $self->tablify(@$data);
            $self->render( text => $out );
        },

        txt => sub {
            $self->render( text => dump(decode_json($jobs->())) );
        },
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self    = shift;
    my $job_id  = $self->param('job_id');
    my $token   = $self->session->{'token'};
    my $access  = $token->{'access_token'};
    my $ua      = Mojo::UserAgent->new;
    my $url     = sprintf("https://agave.iplantc.org/jobs/v2/%s", $job_id);
    my $res     = $ua->get($url => { Authorization => "Bearer $access" })->res;
    my $result  = decode_json($res->body);
    my $job     = sub {
        if ($result->{'status'} eq 'success') {
            $result->{'result'};
        }
        else {
            $res->body;
        }
    };

    $self->respond_to(
        html => sub {
            # so I can access the "job._links"
            $Template::Stash::PRIVATE = undef; 
            $self->layout('default');
            $self->render(job_id => $job_id, result => $result);
        },

        json => sub {
            $self->render( json => $job->() );
        },

        txt => sub {
            $self->render( text => dump($job->()) );
        },
    );
}

1;
