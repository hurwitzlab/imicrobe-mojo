package IMicrobe::Controller::Project;

use IMicrobe::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;

# ----------------------------------------------------------------------
sub browse {
    my $self     = shift;
    my $dbh      = IMicrobe::DB->new->dbh;
    my $projects = $dbh->selectall_arrayref(
        q[
            select   count(*) as count, d.domain_name
            from     project p, domain d, project_to_domain p2d
            where    p.project_id=p2d.project_id
            and      p2d.domain_id=d.domain_id
            group by 2
            order by 2
        ],
        { Columns => {} }
    );

    $self->respond_to(
        json => sub {
            $self->render( json => $projects );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                projects => $projects,
                title    => 'Projects by Domain of Life',
            );
        },

        txt => sub {
            $self->render( text => dump($projects) );
        },
    );
}

# ----------------------------------------------------------------------
sub list {
    my $self   = shift;
    my $dbh    = IMicrobe::DB->new->dbh;
    my $domain = lc($self->param('domain') || '');
    my $sql    = q[
        select    p.project_id, p.project_name, p.project_code,
                  p.pi, p.institution,
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
        %s
    ];

    if ($domain) {
        my %valid = 
            map { $_, 1 } 
            @{ $dbh->selectcol_arrayref('select domain_name from domain') };

        if ($valid{$domain}) {
            $sql = sprintf($sql, 
                sprintf('where d.domain_name=%s', $dbh->quote($domain))
            );
        }
        else {
            return $self->reply->exception("Bad domain ($domain)");
        }
    }
    else {
        $sql = sprintf($sql, '');
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
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self       = shift;
    my $project_id = $self->param('project_id');

    my $dbh = IMicrobe::DB->new->dbh;
    my $sql = sprintf(
        'select * from project where %s=?',
        $project_id =~ /\D+/ ? 'project_code' : 'project_id'
    );

    my $sth = $dbh->prepare($sql);
    $sth->execute($project_id);
    my $project = $sth->fetchrow_hashref;

    if (!$project) {
        return $self->reply->exception("Bad project id ($project_id)");
    }

    $project->{'domains'} = $dbh->selectcol_arrayref(
        q[
            select d.domain_name 
            from   project_to_domain p2d, domain d
            where  p2d.project_id=?
            and    p2d.domain_id=d.domain_id
        ],
        {},
        $project_id
    );

    $project->{'samples'} = $dbh->selectall_arrayref(
        'select * from sample where project_id=?', { Columns => {} }, 
        $project_id
    );

    $project->{'assemblies'} = $dbh->selectall_arrayref(
        'select * from assembly where project_id=?', { Columns => {} }, 
        $project_id
    );

    my $cmb_asm = $dbh->selectall_arrayref(
        'select * from combined_assembly where project_id=?', 
        { Columns => {} }, 
        $project_id
    );
    
    for my $asm (@$cmb_asm) {
        $asm->{'samples'} = $dbh->selectall_arrayref(
            q[
                select s.sample_id, s.sample_name
                from   combined_assembly_to_sample c2s,
                       sample s
                where  c2s.combined_assembly_id=?
                and    c2s.sample_id=s.sample_id
            ], 
            { Columns => {} }, 
            $asm->{'combined_assembly_id'}
        );
    }

    $project->{'combined_assemblies'} = $cmb_asm;

    $self->respond_to(
        json => sub {
            $self->render( json => $project );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                title   => sprintf("Project: %s", $project->{'project_name'}),
                project => $project,
            );
        },

        txt => sub {
            $self->render( text => dump($project) );
        },
    );
}

1;
