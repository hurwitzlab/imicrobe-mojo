package IMicrobe::Controller::App;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use JSON::XS qw'encode_json decode_json';

sub _fix_inputs {
    my $path  = shift or return '';

    return 
      map { $_ =~ s{^/iplant/home/}{agave://data.iplantcollaborative.org/} }
      split(';', $path);
}

# ----------------------------------------------------------------------
sub launch {
    my $self     = shift;
    my $app_id   = $self->param('app_id') or die 'No app_id';
    my $schema   = $self->db->schema;
    my $App      = $schema->resultset('App')->find($app_id)
                   or die "Bad app id ($app_id)\n";
    my $session  = $self->session;
    my $token    = $session->{'token'}{'access_token'} 
                   or die "Please <a href='/login'>login</a>\n";
    my $app_name = $App->app_name;

    (my $job_id = rand()) =~ s/^0\.//; # get a random string of numbers
    my $job = {
        name       =>  "$app_name-$job_id",
        appId      =>  $app_name,
        archive    =>  'true',
    };

    if ($app_name =~ /mash/i) {
        my $query = _fix_inputs($self->param('input-QUERY'));

        $job->{'inputs'}     = { QUERY => $query };
        $job->{'parameters'} = {
           SAMPLE_NAMES => $self->param('param-SAMPLE_NAMES') || '' 
        };
    }
    elsif ($app_name =~ /^imicrobe-b?last/i) {
        my $query  = _fix_inputs($self->param('input-QUERY')) 
                     or die "No QUERY\n";
        my $pct_id = $self->param('param-PCT_ID');
        $job->{'inputs'}     = { QUERY => $query   };
        $job->{'parameters'} = { PCT_ID => $pct_id };
    }
    else {
        my %params = %{ $self->req->params->to_hash };
        while (my ($key, $val) = each %params) {
            if ($key =~ /^(input|param)-(.+)/) {
                my ($type, $name) = ($1, $2);
                my $cat = $type eq 'input' ? 'inputs' : 'parameters';
                $job->{ $cat }{ $name } = $val;
            }
        } 
    }

    if (my $email = $session->{'user'}{'email'}) {
        $job->{'notifications'} = [{ url => $email, event => 'FINISHED' }];
    }

    my $url    = 'https://agave.iplantc.org/jobs/v2';
    my $ua     = Mojo::UserAgent->new;
    my $res    = $ua->post(
                 $url => { Authorization => "Bearer $token" } => json => $job
                 )->res;
    my $result = decode_json($res->body);

    if (my $user = $self->session->{'user'}) {
        my $schema    = $self->db->schema;
        my ($User)    = $schema->resultset('User')->find_or_create({
            user_name => $user->{'username'}
        });
        my $dt       = DateTime->now;
        my ($AppRun) = $schema->resultset('AppRun')->find_or_create({
            user_id    => $User->id,
            app_id     => $App->id,
            app_ran_at => join(' ', $dt->ymd, $dt->hms),
            params     => dump($job),
        });
    }

    $self->respond_to(
        html => sub {
            $self->render(app_id => $app_id, result => $result);
        },

        json => sub {
            $self->render( json => $result );
        },

        txt => sub {
            $self->render( text => dump($result) );
        },
    );
}

# ----------------------------------------------------------------------
sub list {
    my $self = shift;
    my $schema = $self->db->schema;
    my @Apps   = $schema->resultset('App')->search;
    my $struct = sub { map { { $_->get_inflated_columns } } @Apps };

    $self->respond_to(
        html => sub {
            $self->layout('default');
            $self->render(apps => \@Apps);
        },

        json => sub {
            $self->render( json => [ $struct->() ]);
        },

        tab => sub {
            my $out = $self->tablify($struct->());
            $self->render( text => $out );
        },

        txt => sub {
            $self->render( text => dump($struct->()) );
        },
    );
}

# ----------------------------------------------------------------------
sub run {
    my $self   = shift;
    my $app_id = $self->param('app_id');
    my $App    = $self->db->schema->resultset('App')->find($app_id)
                 or die "Bad app id ($app_id)\n";
    my $token  = $self->session->{'token'};
    my $access = $token->{'access_token'} or die "No access_token\n";
    my $ua     = Mojo::UserAgent->new;
    my $url    = "https://agave.iplantc.org/apps/v2/" . $App->app_name;
    my $res    = $ua->get($url => { Authorization => "Bearer $access" })->res;
    my $result = decode_json($res->body);

    unless ($result->{'status'} eq 'success') {
        die $res->body;
    }

    $self->layout('default');
    $self->render(
        app_id => $app_id,
        app    => $result->{'result'}, 
        token  => $token,
        user   => $self->session->{'user'},
    );
}

1;
