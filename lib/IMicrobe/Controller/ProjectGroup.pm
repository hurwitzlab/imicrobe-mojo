package IMicrobe::Controller::ProjectGroup;

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
                        domain => {
                            type => 'str',
                            desc => 'list of project groups',
                            required => 'false',
                        }
                    },
                    results => 'a list of combined assemblies',
                },

                view => {
                    params => {
                        project_group_id => {
                            type     => 'int',
                            desc     => 'the project group id',
                            required => 'true'
                        }
                    },
                    results => 'the details of a project group',
                }
            });
        }
    );
}

# ----------------------------------------------------------------------
sub list {
    my $self   = shift;
    my $schema = $self->db->schema;
    my @groups = $schema->resultset('ProjectGroup')->all;

    $self->respond_to(
        json => sub {
            $self->render( json => \@groups );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                groups => \@groups, 
                title  => 'Project Groups',
            );
        },

        txt => sub {
            $self->render( text => dump(\@groups) );
        },

        tab => sub {
            my $text = '';

#            if (@$groups) {
#                my @flds = sort keys %{ $projects->[0] };
#                my @data = (join "\t", @flds);
#                for my $project (@$projects) {
#                    push @data, join "\t", 
#                        map { s/[\r\n]//g; $_ }
#                        map { 
#                            ref $project->{$_} eq 'ARRAY' 
#                            ? join(', ', @{$project->{$_}})
#                            : $project->{$_} // '' 
#                        } @flds;
#                }
#                $text = join "\n", @data;
#            }

            $self->render( text => $text );
        },
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self     = shift;
    my $group_id = $self->param('project_group_id');
    my $schema   = $self->db->schema;
    my $Group    = $schema->resultset('ProjectGroup')->find($group_id);

    if (!$Group) {
        return $self->reply->exception("Bad project group id ($group_id)");
    }

    $self->respond_to(
        json => sub {
            $self->render( json => { $Group->get_inflated_columns() } );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                title => sprintf("Project Group %s", $Group->group_name),
                group => $Group,
            );
        },

        txt => sub {
            $self->render( text => dump({$Group->get_inflated_columns()}) );
        },
    );
}


1;
