package IMicrobe::Controller::Sample;

use IMicrobe::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;

# ----------------------------------------------------------------------
sub list {
    my $self    = shift;
    my $dbh     = IMicrobe::DB->new->dbh;
    my $samples = $dbh->selectall_arrayref(
        q[
            select s.sample_id, s.sample_name, s.sample_type,
                   s.reads_file, s.annotations_file, s.peptides_file, 
                   s.contigs_file, s.cds_file,
                   s.phylum, s.class, s.family, s.genus, s.species, 
                   s.strain, s.clonal, s.axenic, s.pcr_amp, s.pi,
                   p.project_id, p.project_name
            from   sample s, project p
            where  s.project_id=p.project_id
        ],
        { Columns => {} }
    );

    $self->respond_to(
        json => sub {
            $self->render( json => $samples );
        },

        html => sub {
            $self->layout('default');
            $self->render( title => 'Samples', samples => $samples );
        },

        txt => sub {
            $self->render( text => dump($samples) );
        },
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self      = shift;
    my $sample_id = $self->param('sample_id') or die 'No sample id';
    my $dbh       = IMicrobe::DB->new->dbh;

    if ($sample_id =~ /^\D/) {
        for my $fld (qw[ sample_name sample_acc ]) {
            my $sql = "select sample_id from sample where $fld=?";
            if (my $id = $dbh->selectrow_array($sql, {}, $sample_id)) {
                $sample_id = $id;
                last;    
            }
        }
    }

    my $sth = $dbh->prepare(
        q[
            select s.*, 
                   p.project_name
            from   sample s, project p
            where  s.sample_id=?
            and    s.project_id=p.project_id
        ],
    );
    $sth->execute($sample_id);
    my $sample = $sth->fetchrow_hashref;

    if (!$sample) {
        return $self->reply->exception("Bad sample id ($sample_id)");
    }

    $self->respond_to(
        json => sub {
            $self->render( json => $sample );
        },

        html => sub {
            $self->layout('default');

            $self->render( sample => $sample );
        },

        txt => sub {
            $self->render( text => dump($sample) );
        },
    );
}

1;
