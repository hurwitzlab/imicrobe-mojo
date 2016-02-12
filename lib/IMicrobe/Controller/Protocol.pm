package IMicrobe::Controller::Protocol;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';

# ----------------------------------------------------------------------
sub info {
    my $self = shift;

    $self->respond_to(
        json => sub {
            $self->render(json => { 
                list => {
                    results => 'a list of protocols',
                },

                view => {
                    params => {
                        protocol_id => {
                            type     => 'int',
                            desc     => 'the protocol id',
                            required => 'true'
                        }
                    },
                    results => 'the details of a protocol',
                }
            });
        }
    );
}

# ----------------------------------------------------------------------
sub list {
    my $self      = shift;
    my $db        = $self->db;
    my $schema    = $db->schema;
    my $Protocols = $schema->resultset('Protocol');

    $self->respond_to(
        json => sub {
            $self->render( json => [
                map { {$_->get_inflated_columns()} } $Protocols->all()
            ]);
        },

        html => sub {
            $self->layout('default');

            $self->render( protocols => $Protocols, title => 'Protocols' );
        },

        txt  => sub {
            $self->render( text => dump([
                map { {$_->get_inflated_columns()} } $Protocols->all()
            ]));
        },

        tab => sub {
            my $text = '';

            if ($Protocols->count > 0) {
                my @flds = $Protocols->result_source->columns;
                my @data = (join "\t", @flds);

                while (my $pub = $Protocols->next) {
                    push @data, join "\t", map { $pub->$_() // '' } @flds;
                }

                $text = join "\n", @data;
            }

            $self->render( text => $text );
        },
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self        = shift;
    my $protocol_id = $self->param('protocol_id');
    my $db          = $self->db;
    my $schema      = $db->schema;
    my $Protocol    = $schema->resultset('Protocol')->find($protocol_id);

    if (!$Protocol) {
        return $self->reply->exception("Bad protocol id ($protocol_id)");
    }

    $self->respond_to(
        json => sub {
            $self->render( json => { $Protocol->get_inflated_columns } ),
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                protocol => $Protocol,
                title    => sprintf('Protocol: %s', 
                            $Protocol->protocol_name || 'Untitled'),
            );
        },

        txt => sub {
            $self->render( text => dump({$Protocol->get_inflated_columns}) );
        },
    );
}

1;
