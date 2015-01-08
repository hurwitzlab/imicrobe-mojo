package IMicrobe::Controller::Sample;

use IMicrobe::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;

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
                                 .  'samples belong',
                            required => 'false',
                        }
                    },
                    results => 'a list of samples',
                },

                search => {
                    params => {
                        latitude_min => {
                            type     => 'int',
                            desc     => 'latitude_min',
                            required => 'false',
                        },
                        latitude_max => {
                            type     => 'int',
                            desc     => 'latitude_max',
                            required => 'false',
                        },
                        longitude_min => {
                            type     => 'int',
                            desc     => 'longitude_min',
                            required => 'false',
                        },
                        longitude_max => {
                            type     => 'int',
                            desc     => 'longitude_max',
                            required => 'false',
                        },
                    },
                    results => 'search results',
                },

                view => {
                    params => {
                        sample_id => {
                            type => 'int',
                            desc => 'the sample id',
                            required => 'true'
                        }
                    },
                    results => 'the details of a sample',
                }
            });
        }
    );
}

# ----------------------------------------------------------------------
sub list {
    my $self = shift;
    my $dbh  = IMicrobe::DB->new->dbh;
    my $sql  = q[
        select s.sample_id, s.sample_name, s.sample_type,
               s.reads_file, s.annotations_file, s.peptides_file, 
               s.contigs_file, s.cds_file, s.fastq_file,
               s.phylum, s.class, s.family, s.genus, s.species, 
               s.strain, s.clonal, s.axenic, s.pcr_amp, s.pi,
               s.latitude, s.longitude,
               p.project_id, p.project_name
        from   sample s, project p
        where  s.project_id=p.project_id
    ];

    if (my $project_id = $self->req->param('project_id')) {
        $sql .= sprintf('and s.project_id=%s', $dbh->quote($project_id));
    }

    my $samples = $dbh->selectall_arrayref($sql, { Columns => {} });

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

        tab => sub {
            my $text = '';

            if (@$samples) {
                my @flds = sort keys %{ $samples->[0] };
                my @data = (join "\t", @flds);
                for my $sample (@$samples) {
                    push @data, join "\t", map { $sample->{$_} // '' } @flds;
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

    $sample->{'attrs'} = $dbh->selectall_arrayref(
        q'
            select t.type, a.attr_value, t.url_template
            from   sample_attr_type t, sample_attr a
            where  a.sample_id=?
            and    a.sample_attr_type_id=t.sample_attr_type_id
        ', 
        { Columns => {} },
        $sample_id
    );

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

# ----------------------------------------------------------------------
sub search {
    my $self = shift;
    $self->layout('default');
    $self->render(title => 'Samples Map Search');
}

# ----------------------------------------------------------------------
sub search_results {
    my $self = shift;
    my $dbh  = IMicrobe::DB->new->dbh;
    my $sql  = q'
        select p.project_id, p.project_name, p.pi as project_pi,
               s.sample_id, s.sample_name, s.pi as sample_pi, 
               s.latitude, s.longitude, s.phylum, s.class, 
               s.family, s.genus, s.species, s.strain,
               s.reads_file, s.annotations_file, s.peptides_file,
               s.contigs_file, s.cds_file, s.fastq_file
        from   sample s, project p
        where  s.project_id=p.project_id
    ';

    my @samples;
    if (my $bounds = $self->param('bounds')) {
        my @tmp;
        for my $area (split(/:/, $bounds)) {
            my ($lat_lo, $lng_lo, $lat_hi, $lng_hi) = split(',', $area);

            ($lat_lo, $lat_hi) = sort { $a <=> $b } ($lat_lo, $lat_hi);
            ($lng_lo, $lng_hi) = sort { $a <=> $b } ($lng_lo, $lng_hi);

            my $run = $sql . sprintf(
                q'
                    and    (s.latitude  >= %s and s.latitude  <= %s)
                    and    (s.longitude >= %s and s.longitude <= %s)
                ',
                $lat_lo, $lat_hi, $lng_lo, $lng_hi
            );

            push @tmp, @{ 
                $dbh->selectall_arrayref($run, { Columns => {} }) 
            };
        }

        my %seen;
        for my $sample (@tmp) {
            unless ($seen{ $sample->{'sample_id'} }++) {
                push @samples, $sample;
            }
        }
    }
    else {
        @samples = @{ $dbh->selectall_arrayref($sql, { Columns => {} }) };
    }

    $self->respond_to(
        json => sub {
            $self->render( json => { samples => \@samples } );
        },

        html => sub {
            #$self->layout('default');
            $self->render(samples => \@samples);
        },

        tab => sub {
            my $text = '';

            if (@samples > 0) {
                my @flds = sort keys %{ $samples[0] };
                my @data = (join "\t", @flds);

                for my $sample (@samples) {
                    push @data, join "\t", map { $sample->{$_} // '' } @flds;
                }

                $text = join "\n", @data;
            }

            $self->render( text => $text );
        },

        txt => sub {
            $self->render( text => dump(\@samples) );
        },
    );
}

1;
