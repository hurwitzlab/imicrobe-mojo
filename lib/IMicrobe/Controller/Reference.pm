package IMicrobe::Controller::Reference;

use IMicrobe::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;

# ----------------------------------------------------------------------
sub info {
    my $self = shift;

    $self->respond_to(
        json => sub {
            $self->render(json => { 
                list => {
                    results => 'a list of reference genomes',
                },
                view => {
                    params => {
                        reference_id => {
                            type     => 'int',
                            desc     => 'the reference id',
                            required => 'true'
                        }
                    },
                    results => 'the details of a reference',
                }
            });
        }
    );
}

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
                select   reference_id, file, name, build_date, 
                         revision, length, seq_count
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

            $self->render( refs => \@refs, title => 'Reference Data Sets' );
        },

        txt => sub {
            $self->render( text => dump(\@refs) );
        },

        tab => sub {
            my $text = '';

            if (@refs) {
                my @flds = sort keys %{ $refs[0] };
                my @data = (join "\t", @flds);
                for my $ref (@refs) {
                    push @data, join "\t", map { $ref->{$_} // '' } @flds;
                }
                $text = join "\n", @data;
            }

            $self->render( text => $text );
        },
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self         = shift;
    my $db           = IMicrobe::DB->new;
    my $reference_id = $self->param('reference_id');
    my $Reference    = $db->schema->resultset('Reference')->find($reference_id);

    $self->respond_to(
        json => sub {
            $self->render( json => { 
                reference => { $Reference->get_inflated_columns() },
            });
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                title     => sprintf("Reference %s", $Reference->name),
                reference => $Reference,
            );
        },

        txt => sub {
            $self->render( text => dump({
                reference => { $Reference->get_inflated_columns() },
            }));
        },
    );
}

1;
