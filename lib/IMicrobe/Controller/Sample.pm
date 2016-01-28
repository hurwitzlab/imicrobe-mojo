package IMicrobe::Controller::Sample;

use IMicrobe::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;
use String::Trim qw(trim);

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
        select     s.sample_id, s.sample_name
                   p.project_id, p.project_name,
                   count(f.sample_file_id) as num_files
        from       sample s 
        inner join project p
        on         s.project_id=p.project_id
        left join  sample_file f
        on         s.sample_id=f.sample_id
        group by   1,2,3,4,5
    ];

    if (my $project_id = $self->req->param('project_id')) {
        $sql .= sprintf('where s.project_id=%s', $dbh->quote($project_id));
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
    my $db        = IMicrobe::DB->new;
    my $dbh       = $db->dbh;
    my $schema    = $db->schema;

    if ($sample_id =~ /^\D/) {
        for my $fld (qw[ sample_name sample_acc ]) {
            my $sql = "select sample_id from sample where $fld=?";
            if (my $id = $dbh->selectrow_array($sql, {}, $sample_id)) {
                $sample_id = $id;
                last;    
            }
        }
    }

    my ($Sample) = $schema->resultset('Sample')->find($sample_id);
    if (!$Sample) {
        return $self->reply->exception("Bad sample id ($sample_id)");
    }

    my @assembly_files;
    for my $fld ( qw[pep_file nt_file cds_file] ) {
        my $val = $dbh->selectrow_array(
            "select $fld from assembly where sample_id=?", {}, $sample_id
        );

        if ($val) {
            push @assembly_files, { type => $fld, file => $val };
        }
    }

    my @combined_assembly_files;
    for my $fld ( 
        qw[ annotations_file peptides_file nucleotides_file cds_file ] 
    ) {
        my $val = $dbh->selectrow_array(
            qq'
            select ca.${fld}
            from   combined_assembly_to_sample c2s, 
                   combined_assembly ca
            where  c2s.sample_id=?
            and    c2s.combined_assembly_id=ca.combined_assembly_id
            ', 
            {}, 
            $sample_id
        );

        if ($val) {
            push @combined_assembly_files, { type => $fld, file => $val };
        }
    }

    my (%attrs, %location);
    for my $attr ($Sample->sample_attrs) {
        my $cat = $attr->sample_attr_type->category;
        $cat    =~ s/\s+/_/g;
        $cat    =~ s/_parameter$//;
        push @{ $attrs{ $cat } }, $attr;

        if ($attr->sample_attr_type->type =~ /^((?:lat|long)itude)$/) {
            $location{ $1 } = $attr->attr_value;
        }
    }

    $self->respond_to(
        json => sub {
            $self->render( json => { 
                sample                  => $Sample->get_inflated_columns(),
                assembly_files          => \@assembly_files,
                combined_assembly_files => \@combined_assembly_files,
            });
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                sample                  => $Sample,
                attributes              => \%attrs,
                location                => \%location,
                assembly_files          => \@assembly_files,
                combined_assembly_files => \@combined_assembly_files,
            );
        },

        txt => sub {
            $self->render( text => dump({ 
                sample                  => {$Sample->get_inflated_columns()},
                assembly_files          => \@assembly_files,
                combined_assembly_files => \@combined_assembly_files,
            }));
        },
    );
}

# ----------------------------------------------------------------------
sub search {
    my $self = shift;
    $self->layout('default');
    $self->render( title => 'Samples Search' );
}

# ----------------------------------------------------------------------
sub search_param_values {
    my $self    = shift;
    my $field   = $self->param('field') or return;
    my $db      = IMicrobe::DB->new;
    my $mongo   = $db->mongo;
    my $mdb     = $mongo->get_database('imicrobe');
    my $result  = $mdb->run_command([
       distinct => 'sample',
       key      => $field,
       query    => {}
    ]);

    print STDERR "result = ", dump($result);
    my @values = $result->{'ok'} ? sort @{ $result->{'values'} } : ();

    $self->respond_to(
        json => sub {
            $self->render( json => \@values );
        },

        txt => sub {
            $self->render( text => dump(\@values) );
        },
    );
}

# ----------------------------------------------------------------------
sub _search_params {
    my $db     = IMicrobe::DB->new;
    my $mongo  = $db->mongo;
    my $mdb    = $mongo->get_database('imicrobe');
    my $coll   = $mdb->get_collection('sampleKeys');
    my @types  = 
        sort { $a->[0] cmp $b->[0] }
        grep { $_->[0] !~ /(_id|\.floatApprox|\.bottom|\.top|text|none)/i }
        map  { [$_->{'_id'}{'key'}, lc $_->{'value'}{'types'}[0]] }
        $coll->find->all();

    return @types;
}

# ----------------------------------------------------------------------
sub search_params {
    my $self   = shift;
    my @params = $self->_search_params();

    $self->respond_to(
        json => sub {
            $self->render( json => \@params );
        },

        txt => sub {
            $self->render( text => dump(\@params) );
        },
    );
}

# ----------------------------------------------------------------------
sub search_results {
    my $self        = shift;
    my $db          = IMicrobe::DB->new;
    my $dbh         = $db->dbh;
    my $mongo       = $db->mongo;
    my $mdb         = $mongo->get_database('imicrobe');
    my $coll        = $mdb->get_collection('sample');
    my @param_types = $self->_search_params();

    my %search;
    for my $ptype (@param_types) {
        my ($name, $type) = @$ptype;
        if ($type eq 'string') {
            if (my @vals = 
                map { split /\s*,\s*/ } @{ $self->every_param($name) || [] }
            ) {
                if (@vals == 1) {
                    $search{$name} = $vals[0];
                }
                else {
                    $search{$name} = { '$in' => \@vals };
                }
            }
        }
        else {
            my $min = $self->param('min_'.$name);
            my $max = $self->param('max_'.$name);

            if (defined $min && defined $max && $min == $max) {
                $search{$name}{'$eq'} = $min;
            }
            else {
                if (defined $min && $min =~ /\d+/) {
                    $search{$name}{'$gte'} = $min;
                }

                if (defined $max && $max =~ /\d+/) {
                    $search{$name}{'$lte'} = $max;
                }
            }
        }
    }

    my @samples;
    if (%search) {
        my %fields = 
            map { $_, 1 } 
            ('project_id', 'project_name',
            'specimen__sample_id', 'specimen__sample_name', 
            'location__latitude', 'location__longitude'),
            keys %search;

        my $cursor = $coll->find(\%search)->fields(\%fields);
        push @samples, $cursor->all;
    }

    $self->respond_to(
        json => sub {
            $self->render( json => { 
                samples       => \@samples, 
                search_fields => [ sort keys %search ],
            });
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

# ----------------------------------------------------------------------
sub search_results_map {
    my $self = shift;
    $self->layout('default');
    $self->render(title => 'Samples Search Map View');
}

# ----------------------------------------------------------------------
sub map_search {
    my $self = shift;
    $self->layout('default');
    $self->render(title => 'Samples Map Search');
}

# ----------------------------------------------------------------------
sub map_search_results {
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

#        html => sub {
#            #$self->layout('default');
#            $self->render(samples => \@samples);
#        },

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
