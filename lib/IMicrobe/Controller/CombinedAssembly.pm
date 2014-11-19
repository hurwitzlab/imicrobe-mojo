package IMicrobe::Controller::CombinedAssembly;

use IMicrobe::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;

# ----------------------------------------------------------------------
sub list {
    my $self       = shift;
    my $dbh        = IMicrobe::DB->new->dbh;
    my $assemblies = $dbh->selectall_arrayref(
        q[
            select a.combined_assembly_id, a.assembly_name,
                   a.phylum, a.class, a.family,
                   a.genus, a.species, a.strain, a.pcr_amp,
                   a.annotations_file, a.peptides_file,
                   a.nucleotides_file, a.cds_file,
                   p.project_id, p.project_name
            from   combined_assembly a, project p
            where  a.project_id=p.project_id
        ],
        { Columns => {} }, 
    );
    
    for my $asm (@$assemblies) {
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

    $self->respond_to(
        json => sub {
            $self->render( json => $assemblies );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                title      => 'Combined Assemblies', 
                assemblies => $assemblies 
            );
        },

        txt => sub {
            $self->render( text => dump($assemblies) );
        },
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self        = shift;
    my $assembly_id = $self->param('combined_assembly_id');
    my $dbh         = IMicrobe::DB->new->dbh;

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

    my $sth = $dbh->prepare(
        q[
            select a.combined_assembly_id, a.assembly_name,
                   a.phylum, a.class, a.family,
                   a.genus, a.species, a.strain, a.pcr_amp,
                   a.annotations_file, a.peptides_file,
                   a.nucleotides_file, a.cds_file,
                   p.project_id, p.project_name
            from   combined_assembly a, project p
            where  a.combined_assembly_id=?
            and    a.project_id=p.project_id
        ]
    );
    $sth->execute($assembly_id);
    my $assembly = $sth->fetchrow_hashref;

    if (!$assembly) {
        return 
        $self->reply->exception("Bad combined assembly id ($assembly_id)");
    }

    $assembly->{'samples'} = $dbh->selectall_arrayref(
        q[
            select s.sample_id, s.sample_name
            from   combined_assembly_to_sample ca2s, sample s
            where  ca2s.combined_assembly_id=?
            and    ca2s.sample_id=s.sample_id
        ],
        { Columns => {} },
        $assembly_id
    );

    $self->respond_to(
        json => sub {
            $self->render( json => $assembly );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                assembly => $assembly,
                title    => sprintf(
                    "Combined Assembly: %s", 
                    $assembly->{'assembly_name'} || 'Unknown'
                ),
            );
        },

        txt => sub {
            $self->render( text => dump($assembly) );
        },
    );
}

1;
