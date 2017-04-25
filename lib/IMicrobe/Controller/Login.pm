package IMicrobe::Controller::Login;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use JSON::XS 'decode_json';

# ----------------------------------------------------------------------
sub login {
    my $self  = shift;
    my $token = $self->get_access_token;

    $self->layout('default');
    $self->render();
}

# --------------------------------------------------
sub auth {
    my $self = shift;

    if (my $error = $self->param('error')) {
        die $error;
    }

    my $code   = $self->param('code') or die 'No code parameter';
    my $config = $self->config;
    my $key    = $config->{'tacc_api_key'} or die "No TACC API key\n";
    my $params = join '&',
        'client_id='    . $key->{'public'},
        'client_secret='. $key->{'private'},
        'redirect_uri=' . $key->{'redirect_url'},
        'code='         . $code,
        'grant_type=authorization_code',
        'scope=PRODUCTION',
        'response_type=code',
        'state=000';

    my $ua    = Mojo::UserAgent->new;
    my $res   = $ua->post('https://agave.iplantc.org/token' => $params)->res;
    my $token = decode_json($res->body);

    unless ($res->code eq '200') {
        die $token->{'error_description'} || 
            $token->{'error'} || 
            'Problem authenticating';
    }

    if ($token->{'token_type'} ne 'bearer') {
        die "Was expecting a 'bearer' token but got ", $token->{'token_type'};
    }

    my $access = $token->{'access_token'}
                 or die 'No access_token in response.';
    my $user_res = $ua->get(
        'https://agave.iplantc.org/profiles/v2/me' =>
        { Authorization => "Bearer $access" }
    )->res;

    my $user = decode_json($user_res->body);

    unless ($user_res->code eq '200') {
        die $user->{'error_description'} ||
            $user->{'error'} ||
            'Problem getting user profile';
    }

    #
    # Note when the token expires
    #
    $token->{'expires'} = time() + $token->{'expires_in'};

    my $user_info = $user->{'result'};
    $self->session(token => $token);
    $self->session(user  => $user_info);

    my $state = $self->param('state') || '';
    my $url   = $state =~ m{^/\w+} ? $state : '/login';
    return $self->redirect_to($url);
}

1;
