package IMicrobe::Controller::Project;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';

# ----------------------------------------------------------------------
sub browse {
    my $self     = shift;
    my $dbh      = $self->db->dbh;
 
    my @projects = map { 
            $_->{'url'} = 
                sprintf('/project/list?domain=%s', $_->{'domain_name'});
            $_;
        }
        @{ 
            $dbh->selectall_arrayref(
            q[
                select   count(*) as count, d.domain_name
                from     project p, domain d, project_to_domain p2d
                where    p.project_id=p2d.project_id
                and      p2d.domain_id=d.domain_id
                group by 2
                order by 2
            ],
            { Columns => {} }
        )};

    $self->respond_to(
        json => sub {
            $self->render( json => \@projects );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                projects => \@projects,
                title    => 'Projects by Domain of Life',
            );
        },

        tab => sub {
            my $text = '';

            if (@projects) {
                my @flds = sort keys %{ $projects[0] };
                my @data = (join "\t", @flds);
                for my $project (@projects) {
                    push @data, join "\t", map { $project->{$_} } @flds;
                }
                $text = join "\n", @data;
            }

            $self->render( text => $text );
        },

        txt => sub {
            $self->render( text => dump(\@projects) );
        },
    );
}

# ----------------------------------------------------------------------
sub info {
    my $self = shift;

    $self->respond_to(
        json => sub {
            $self->render(json => { 
                browse => {
                    results => 'a list of the number of projects associated '
                            .  'with a domain of life'
                },

                list => {
                    params => {
                        domain => {
                            type => 'str',
                            desc => 'a domain of life to which '
                                 .  'projects belong',
                            required => 'false',
                        }
                    },
                    results => 'a list of combined assemblies',
                },

                view => {
                    params => {
                        project_id => {
                            type     => 'int',
                            desc     => 'the project id',
                            required => 'true'
                        }
                    },
                    results => 'the details of a project',
                }
            });
        }
    );
}

# ----------------------------------------------------------------------
sub list {
    my $self   = shift;
    my $dbh    = $self->db->dbh;
    my $domain = lc($self->param('domain') || '');
    my $sql    = q[
        select    p.project_id, p.project_name, p.project_code,
                  p.project_type, p.description, 
                  read_file, meta_file, assembly_file, peptide_file,
                  count(s.sample_id) as num_samples
        from      project p
        left join sample s
        on        p.project_id=s.project_id
        left join project_to_domain p2d
        on        p.project_id=p2d.project_id
        left join domain d
        on        p2d.domain_id=d.domain_id
    ];

    if ($domain) {
        my %valid = 
            map { $_, 1 } 
            @{ $dbh->selectcol_arrayref('select domain_name from domain') };

        if ($valid{$domain}) {
            $sql .= sprintf('where d.domain_name=%s', $dbh->quote($domain));
        }
        else {
            return $self->reply->exception("Bad domain ($domain)");
        }
    }

    $sql .= 'group by 1';

    my $projects = $dbh->selectall_arrayref($sql, { Columns => {} });
    for my $project (@$projects) {
        $project->{'domains'} = $dbh->selectcol_arrayref(
            q[
                select d.domain_name 
                from   project_to_domain p2d, domain d
                where  p2d.project_id=?
                and    p2d.domain_id=d.domain_id
            ],
            {},
            $project->{'project_id'}
        );
        $project->{'investigators'} = $dbh->selectall_arrayref(
            q[
                select i.investigator_id, i.investigator_name, i.institution
                from   project_to_investigator p2i, investigator i
                where  p2i.project_id=?
                and    p2i.investigator_id=i.investigator_id
            ],
            { Columns => {} },
            $project->{'project_id'}
        );
    }

    $self->respond_to(
        json => sub {
            $self->render( json => $projects );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                projects => $projects, 
                domain   => $domain,
                title    => 'Projects',
            );
        },

        txt => sub {
            $self->render( text => dump($projects) );
        },

        tab => sub {
            my $text = '';

            if (@$projects) {
                my @flds = sort keys %{ $projects->[0] };
                my @data = (join "\t", @flds);
                for my $project (@$projects) {
                    push @data, join "\t", 
                        map { s/[\r\n]//g; $_ }
                        map { 
                            ref $project->{$_} eq 'ARRAY' 
                            ? join(', ', @{$project->{$_}})
                            : $project->{$_} // '' 
                        } @flds;
                }
                $text = join "\n", @data;
            }

            $self->render( text => $text );
        },
    );
}

# ----------------------------------------------------------------------
sub project_file_list {
    my $self       = shift;
    my $project_id = $self->param('project_id');
    my $schema     = $self->db->schema;
    my $Project    = $schema->resultset('Project')->find($project_id) or 
        return $self->reply->exception("Bad project id ($project_id)");

    my @files = map { 
        { 
            type     => $_->project_file_type->type, 
            location => $_->file,
            owner    => 'project',    
            owner_id => $project_id
        } 
    } $Project->project_files->all;

    for my $Sample ($Project->samples) {
        push @files, map { 
            { 
                type     => $_->sample_file_type->type, 
                location => $_->file,
                owner    => 'sample',
                owner_id => $Sample->id,
            } 
        } $Sample->sample_files->all;
    }

    $self->respond_to(
        json => sub {
            $self->render( json => \@files );
        },

        tab => sub {
            my $text = '';

            if (@files) {
                my @flds = sort keys %{ $files[0] };
                my @data = (join "\t", @flds);
                for my $file (@files) {
                    push @data, join "\t", map { $file->{$_} } @flds;
                }
                $text = join "\n", @data;
            }

            $self->render( text => $text );
        },

        txt => sub {
            $self->render( text => dump(\@files) );
        },
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self = shift;
    my $db   = $self->db;
    my $id   = $self->param('project_id');
    my $sql  = sprintf(
        'select project_id from project where %s=?',
        $id =~ /\D+/ ? 'project_code' : 'project_id'
    );

    my $sth = $db->dbh->prepare($sql);
    $sth->execute($id);
    my ($project_id) = $sth->fetchrow_array or 
        return $self->reply->exception("Bad project id ($id)");

    my $Project = $db->schema->resultset('Project')->find($project_id);
    my $domains = $db->dbh->selectcol_arrayref(
        q'
            select d.domain_name 
            from   project_to_domain p2d, domain d
            where  p2d.project_id=?
            and    p2d.domain_id=d.domain_id
        ',
        {},
        $project_id
    );

    my $file_count = $Project->project_files->count;
    for my $Sample ($Project->samples->all) {
        $file_count += $Sample->sample_files->count;
    }

    $self->respond_to(
        json => sub {
            $self->render( json => { 
                project => { $Project->get_inflated_columns() },
                samples => [ 
                    map { {$_->get_inflated_columns()} } $Project->samples->all
                ], 
            });
        },

        html => sub {
            $self->layout('default');

            $self->render(
                title   => sprintf("Project: %s", $Project->project_name),
                domains => $domains,
                project => $Project,
                file_count => $file_count,
            );
        },

        txt => sub {
            $self->render( text => dump({
                project => { $Project->get_inflated_columns() },
                samples => [ 
                    map { {$_->get_inflated_columns()} }
                    $Project->samples->all
                ], 
            }))
        },
    );
}

1;
