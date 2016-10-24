package IMicrobe::Controller::Investigator;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use String::Trim qw(trim);

# ----------------------------------------------------------------------
sub info {
    my $self = shift;

    $self->respond_to(
        json => sub {
            $self->render(json => { 
                list => {
                    results => 'a list of investigators',
                },

                view => {
                    params => {
                        investigator_id => {
                            type => 'int',
                            desc => 'the investigator id',
                            required => 'true'
                        }
                    },
                    results => 'the details of an investigator',
                }
            });
        }
    );
}

# ----------------------------------------------------------------------
sub list {
    my $self   = shift;
    my $schema = $self->db->schema;
    my $Invs   = $schema->resultset('Investigator');

    $self->respond_to(
        json => sub {
            $self->render( json => [
                map { {$_->get_inflated_columns()} } $Invs->all()
            ]);
        },

        html => sub {
            $self->layout('default');
            $self->render( title => 'Investigators', investigators => $Invs );
        },

        txt => sub {
            $self->render( text => dump([
                map { {$_->get_inflated_columns()} } $Invs->all()
            ]));
        },

        tab => sub {
            my $text = '';

            if ($Invs->count > 0) {
                my @flds = $Invs->result_source->columns;
                my @data = (join "\t", @flds);

                while (my $inv = $Invs->next) {
                    push @data, join "\t", map { $inv->$_() // '' } @flds;
                }

                $text = join "\n", @data;
            }

            $self->render( text => $text );
        },
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self      = shift;
    my $inv_id    = $self->param('investigator_id') or die 'No investigator_id';
    my $schema    = $self->db->schema;

    my ($Inv) = $schema->resultset('Investigator')->find($inv_id);
    if (!$Inv) {
        return $self->reply->exception("Bad investigator id ($inv_id)");
    }

    $self->respond_to(
        json => sub {
            $self->render( json => { $Inv->get_inflated_columns() });
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                title => 
                  sprintf('Investigator: %s', $Inv->investigator_name || 'NA'),
                investigator => $Inv,
            );
        },

        txt => sub {
            $self->render( text => dump({ 
                investigator => { $Inv->get_inflated_columns() }
            }));
        },
    );
}

1;
