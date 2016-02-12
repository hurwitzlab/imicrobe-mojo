package IMicrobe::Controller::CombinedAssembly;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';

# ----------------------------------------------------------------------
sub info {
    my $self = shift;

    $self->respond_to(
        json => sub {
            $self->render(json => { 
                list => {
                    params => {
                        project_id => {
                            type => 'int',
                            desc => 'value of the project id to which the '
                                 .  'combined assemblies belong',
                            required => 'false',
                        }
                    },
                    results => 'a list of combined assemblies',
                },

                view => {
                    params => {
                        combined_assembly_id => {
                            type     => 'int',
                            desc     => 'the combined assembly id',
                            required => 'true'
                        }
                    },
                    results => 'the details of a combined assembly',
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
    my $rs     = $schema->resultset('CombinedAssembly');

    my @Assemblies;
    if (my $project_id = $self->param('project_id')) {
        @Assemblies = $rs->search({ project_id => $project_id });
    }
    else {
        @Assemblies = $rs->all;
    }

    my @exploded;
    for my $CA (@Assemblies) {
        my %hash = $CA->get_inflated_columns();

        $hash{'samples'} = [
            map { {$_->get_inflated_columns()} } 
            $CA->samples->all
        ];

        push @exploded, \%hash;
    }

    $self->respond_to(
        json => sub {
            $self->render( json => \@exploded )
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                title      => 'Combined Assemblies', 
                assemblies => \@Assemblies 
            );
        },

        txt => sub {
            $self->render(text => dump(\@exploded))
        },

        tab => sub {
            my $text = '';
            if (@exploded) {
                my @flds = sort keys %{ $exploded[0] };
                my @data = (join "\t", @flds);
                for my $asm (@exploded) {
                    push @data, join "\t", 
                        map { s/[\r\n]//g; $_ }
                        map { 
                            ref $asm->{$_} eq 'ARRAY' 
                            ? '-'
                            : $asm->{$_} // '' 
                        } @flds;
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
    my $assembly_id = $self->param('combined_assembly_id');
    my $db          = $self->db;
    my $dbh         = $db->dbh;
    my $schema      = $db->schema;

    if ($assembly_id =~ /^\D/) {
        my $sql = q[
            select combined_assembly_id 
            from   combined_assembly 
            where  assembly_name=?
        ];

        if (my $id = $dbh->selectrow_array($sql, {}, $assembly_id)) {
            $assembly_id = $id;
        }
    }

    my $Assembly = $schema->resultset('CombinedAssembly')->find($assembly_id);

    if (!$Assembly) {
        return 
        $self->reply->exception("Bad combined assembly id ($assembly_id)");
    }

    $self->respond_to(
        json => sub {
            $self->render( json => { 
                assembly => { $Assembly->get_inflated_columns() },
                samples  => [
                    map { {$_->sample->get_inflated_columns()} } 
                    $Assembly->combined_assembly_to_samples->all
                ]
            });
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                assembly => $Assembly,
                title    => sprintf(
                    "Combined Assembly: %s", 
                    $Assembly->assembly_name || 'Unknown'
                ),
            );
        },

        txt => sub {
            $self->render( text => dump({
                assembly => { $Assembly->get_inflated_columns() },
                samples  => [
                    map { {$_->sample->get_inflated_columns()} } 
                    $Assembly->combined_assembly_to_samples->all
                ]
            }))
        },
    );
}

1;
