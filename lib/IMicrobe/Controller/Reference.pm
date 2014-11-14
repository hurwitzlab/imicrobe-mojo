package IMicrobe::Controller::Reference;

use IMicrobe::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;

# ----------------------------------------------------------------------
sub list {
    my $self = shift;
    my $dbh  = IMicrobe::DB->new->dbh;
    my $url  = "http://mirrors.iplantcollaborative.org/browse/iplant/"
             . "home/shared/imicrobe/camera/camera_reference_datasets/";
    my @refs = 
        map { $_->{'url'} = $url . $_->{'file'}; $_ }
        @{$dbh->selectall_arrayref(
            q[
                select   file, name
                from     reference
                order by 2
            ],
            { Columns => {} }
        )};

    $self->respond_to(
        json => sub {
            $self->render( json => \@refs );
        },

        html => sub {
            $self->layout('default');

            $self->render( refs => \@refs );
        },

        txt => sub {
            $self->render( text => dump(\@refs) );
        },
    );
}

1;