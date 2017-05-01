package IMicrobe::Controller::App;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use JSON::XS qw'encode_json decode_json';

# ----------------------------------------------------------------------
sub file_browser {
    my $self  = shift;
    my $token = $self->get_access_token;

    #$self->layout('popup');
    $self->render(
        token => $token,
        user  => $self->session->{'user'},
        #token_json => encode_json($token),
    );
}

# ----------------------------------------------------------------------
sub launch {
    my $self       = shift;
    my $app_id     = $self->param('app_id') or die 'No app_id';
    my $schema     = $self->db->schema;
    my $session    = $self->session;
    my $token      = $session->{'token'}{'access_token'} 
                     or die "Please <a href='/login'>login</a>\n";
    my @sample_ids = @{ $session->{'items'} || [] };
    #or die "Nothing in your cart\n";

    my $job = {};
    (my $job_id = rand()) =~ s/^0\.//; # get a random string of numbers

    if ($app_id =~ /^muscope-mash/i) {
        my @sample_names;
        for my $sample_id (@sample_ids) {
            my $Sample = $schema->resultset('Sample')->find($sample_id);
            push @sample_names, $Sample->sample_name;
        }

        $job = {
            name       =>  "muscope-mash-$job_id",
            appId      =>  $app_id,
            archive    =>  'true',
            parameters => { SAMPLE_NAMES => join(',', @sample_names) }
        }
    }
    elsif ($app_id =~ /^muscope-b?last/i) {
        my $query  = $self->param('QUERY') or die "No QUERY\n";
        $query =~ s{^/iplant/home/}{agave://data.iplantcollaborative.org/};
        
        my $pct_id = $self->param('PCT_ID');
        $job = {
            name       =>  "$app_id-$job_id",
            appId      =>  $app_id,
            archive    =>  'true',
            inputs     => { QUERY => $query },
            parameters => { PCT_ID => $pct_id },
        }
    }
    else {
        die "Unknown app_id ($app_id)";
    }

    if (my $email = $session->{'user'}{'email'}) {
        $job->{'notifications'} = [{ url => $email, event => 'FINISHED' }];
    }
    say dump($job);

    my $url    = 'https://agave.iplantc.org/jobs/v2';
    my $ua     = Mojo::UserAgent->new;
    my $res    = $ua->post(
                 $url => { Authorization => "Bearer $token" } => json => $job
                 )->res;
    my $result = decode_json($res->body);

    $self->layout('default');
    $self->render(app_id => $app_id, result => $result);
}

# ----------------------------------------------------------------------
sub list {
    my $self  = shift;
    my $conf  = $self->config;
    my $token = $self->get_access_token(state => '/app/list');

    $self->respond_to(
        html => sub {
            $self->layout('default');
            $self->render(apps => $conf->{'apps'}, token => $token);
        },

        json => sub {
            $self->render( json => $conf->{'apps'} );
        },

        tab => sub {
            $self->render( text => join("\t", @{ $conf->{'apps'} } ));
        },

        txt => sub {
            $self->render( text => dump($conf->{'apps'}) );
        },
    );
}

# ----------------------------------------------------------------------
sub run {
    my $self   = shift;
    my $token  = $self->get_access_token;
    my $app_id = $self->param('app_id');
    my $conf   = $self->config;
    my %valid  = map { $_, 1 } @{ $conf->{'apps'} || [] };

    unless ($valid{ $app_id }) {
        die "Bad app_id ($app_id)\n";
    }

    my $access  = $token->{'access_token'};
    my $ua      = Mojo::UserAgent->new;
    my $url     = sprintf("https://agave.iplantc.org/apps/v2/%s", $app_id);
    my $res     = $ua->get($url => { Authorization => "Bearer $access" })->res;
    my $result  = decode_json($res->body);

    unless ($result->{'status'} eq 'success') {
        die $res->body;
    }


    $self->layout('default');
    $self->render(
        app   => $result->{'result'}, 
        token => $token,
        token_json => encode_json($token),
        user  => $self->session->{'user'},
    );
}

1;
