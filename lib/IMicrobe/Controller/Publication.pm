package IMicrobe::Controller::Publication;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';

# ----------------------------------------------------------------------
sub info {
    my $self = shift;

    $self->respond_to(
        json => sub {
            $self->render(json => { 
                list => {
                    results => 'a list of publications',
                },

                view => {
                    params => {
                        publication_id => {
                            type     => 'int',
                            desc     => 'the publication id',
                            required => 'true'
                        }
                    },
                    results => 'the details of a publication',
                }
            });
        }
    );
}

# ----------------------------------------------------------------------
sub list {
    my $self   = shift;
    my $db     = $self->db;
    my $schema = $db->schema;
    my $Pubs   = $schema->resultset('Publication');

    $self->respond_to(
        json => sub {
            $self->render( json => [
                map { {$_->get_inflated_columns()} } $Pubs->all()
            ]);
        },

        html => sub {
            $self->layout('default');

            $self->render( pubs => $Pubs, title => 'Publications' );
        },

        txt  => sub {
            $self->render( text => dump([
                map { {$_->get_inflated_columns()} } $Pubs->all()
            ]));
        },

        tab => sub {
            my $text = '';

            if ($Pubs->count > 0) {
                my @flds = $Pubs->result_source->columns;
                my @data = (join "\t", @flds);

                while (my $pub = $Pubs->next) {
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
    my $self   = shift;
    my $pub_id = $self->param('publication_id');
    my $db     = $self->db;
    my $schema = $db->schema;
    my $Pub    = $schema->resultset('Publication')->find($pub_id);

    if (!$Pub) {
        return $self->reply->exception("Bad publication id ($pub_id)");
    }

    $self->respond_to(
        json => sub {
            $self->render( json => { $Pub->get_inflated_columns } ),
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                pub   => $Pub,
                title => 
                    sprintf('Publication: %s', $Pub->title || 'Untitled'),
            );
        },

        txt => sub {
            $self->render( text => dump({$Pub->get_inflated_columns}) );
        },
    );
}

1;
