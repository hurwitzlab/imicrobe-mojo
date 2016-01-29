package IMicrobe::Controller::Assembly;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';

# ----------------------------------------------------------------------
sub info {
    my $self = shift;

    $self->respond_to(
        json => sub {
            $self->render(json => { 
                'list' => {
                    params => {
                        project_id => {
                            type => 'int',
                            desc => 'value of the project id to which the '
                                 .  'assemblies belong',
                            required => 'false',
                        }
                    },
                    results => 'a list of assemblies',
                },

                'view' => {
                    params => {
                        assembly_id => {
                            type => 'int',
                            desc => 'the assembly id',
                            required => 'true'
                        }
                    },
                    results => 'the details of an assembly',
                }
            });
        }
    );
}

# ----------------------------------------------------------------------
sub list {
    my $self = shift;
    my $dbh  = $self->db->dbh;
    my $sql  = q[
        select a.assembly_id, a.assembly_code, a.assembly_name,
               a.organism, a.cds_file, a.nt_file, a.pep_file,
               p.project_id, p.project_name
        from   assembly a, project p
        where  a.project_id=p.project_id
    ];

    if (my $project_id = $self->req->param('project_id')) {
        $sql .= sprintf('and a.project_id=%s', $dbh->quote($project_id));
    }

    my $assemblies = $dbh->selectall_arrayref($sql, { Columns => {} });

    $self->respond_to(
        json => sub {
            $self->render( json => $assemblies );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                assemblies => $assemblies,
                title      => 'Assemblies',
            );
        },

        txt => sub {
            $self->render( text => dump($assemblies) );
        },

        tab => sub {
            my $text = '';

            if (@$assemblies) {
                my @flds = sort keys %{ $assemblies->[0] };
                my @data = (join "\t", @flds);
                for my $asm (@$assemblies) {
                    push @data, join "\t", map { $asm->{$_} // '' } @flds;
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
    my $assembly_id = $self->param('assembly_id');
    my $db          = $self->db;
    my $dbh         = $db->dbh;
    my $schema      = $db->schema;

    if ($assembly_id =~ /^\D/) {
        for my $fld (qw[ assembly_name assembly_code ]) {
            my $sql = "select assembly_id from assembly where $fld=?";
            if (my $id = $dbh->selectrow_array($sql, {}, $assembly_id)) {
                $assembly_id = $id;
                last;    
            }
        }
    }

    my $Assembly = $schema->resultset('Assembly')->find($assembly_id);

    if (!$Assembly) {
        return $self->reply->exception("Bad assembly id ($assembly_id)");
    }

    $self->respond_to(
        json => sub {
            $self->render( json => $Assembly->get_inflated_columns() );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                assembly => $Assembly,
                title    => sprintf('Assembly: %s', $Assembly->assembly_name),
            );
        },

        txt => sub {
            $self->render( text => dump({$Assembly->get_inflated_columns()}) );
        },
    );
}

1;
