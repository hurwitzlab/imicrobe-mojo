package IMicrobe::Controller::Sample;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
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
    my $self   = shift;
    my $db     = $self->db;
    my $dbh    = $db->dbh;
    my $sql    = q[
        select     s.sample_id, s.sample_name, s.sample_type,
                   p.project_id, p.project_name,
                   s.latitude, s.longitude,
                   d.domain_name,
                   count(f.sample_file_id) as num_files
        from       sample s 
        inner join project p
        on         s.project_id=p.project_id
        left join  sample_file f
        on         s.sample_id=f.sample_id
        left join  project_to_domain p2d
        on         p.project_id=p2d.project_id
        left join  domain d
        on         p2d.domain_id=d.domain_id
    ];

    my (@where, @args);
    if (my $project_id = $self->req->param('project_id')) {
        push @where, 's.project_id=?';
        push @args, $project_id;
    }

    if (my $domain_id = $self->req->param('domain_id')) {
        push @where, 'd2p.domain_id=?';
        push @args, $domain_id;
    }

    if (my $domain = $self->req->param('domain')) {
        push @where, 'd.domain_name=?';
        push @args, $domain;
    }

    if (@where) {
        my $first = ' where ' . shift(@where);
        $sql .= join ' and ', $first, map { qq[($_)] } @where;
    }

    $sql .= ' group by 1,2,3,4,5,6,7,8';

    my $samples = $dbh->selectall_arrayref($sql, { Columns => {} }, @args);
    for my $sample (@$samples) {
        $sample->{'files'} = $dbh->selectall_arrayref(
            q[
                select f.file, t.type
                from   sample_file f, sample_file_type t
                where  f.sample_id=?
                and    f.sample_file_type_id=t.sample_file_type_id
            ],
            { Columns => {} },
            $sample->{'sample_id'}
        );
    }

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
                    push @data, join "\t", 
                        map { ref $sample->{$_} ? '-' : $sample->{$_} // '' } 
                        @flds;
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
    my $db        = $self->db;
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

    my @attributes = map { 
        {
            type     => $_->sample_attr_type->type, 
            category => $_->sample_attr_type->category, 
            value    => $_->attr_value,
        } 
    } $Sample->sample_attrs->all;

    my @files = map {
        { $_->sample_file_type->type, $_->file }
    } $Sample->sample_files->all;

    my %sample_hash;
    my %tmp = $Sample->get_columns;
    while (my ($key, $val) = each %tmp) {
        next if ref $val;
        $sample_hash{ $key } = $val;
    }

    $self->respond_to(
        json => sub {
            $self->render( json => { 
                sample     => \%sample_hash,
                attributes => \@attributes,
                files      => \@files,
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
                sample     => \%sample_hash,
                attributes => \@attributes,
                files      => \@files,
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
    my $db      = $self->db;
    my $mongo   = $db->mongo;
    my $mdb     = $mongo->get_database('imicrobe');
    my $result  = $mdb->run_command([
       distinct => 'sample',
       key      => $field,
       query    => {}
    ]);

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
    my $self   = shift;
    my $db     = $self->db;
    my $mongo  = $db->mongo;
    my $mdb    = $mongo->get_database('imicrobe');
    my $coll   = $mdb->get_collection('sampleKeys');
    my @types  = 
        sort { $a->[0] cmp $b->[0] }
        grep { $_->[0] ne '_id' }
        grep { $_->[0] !~ /(\.floatApprox|\.bottom|\.top|text|none)/i }
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
    my $db          = $self->db;
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

    my (@samples, @search_params);
    if (%search) {
        @search_params = map { s/^(max|min)_//; $_ } keys %search;
        my @return_fields; 

        if ($self->param('download')) {
            @return_fields = map { $_->[0] } $self->_search_params;
        }
        else {
            @return_fields = (
                'specimen__project_id', 
                'specimen__project_name',
                'specimen__sample_id',
                'specimen__sample_name', 
                'location__latitude', 
                'location__longitude',
                @search_params
            );
        }

        my %fields = map { $_, 1 } @return_fields;
        my $cursor = $coll->find(\%search); #->fields(\%fields);

        for my $sample ($cursor->all) {
            if ($self->param('download')) {
                my $files = $dbh->selectall_arrayref(
                    q[
                        select t.type, f.file
                        from   sample_file f, sample_file_type t   
                        where  f.sample_id=?
                        and    f.sample_file_type_id=t.sample_file_type_id
                    ],
                    { Columns => {} },
                    ($sample->{'specimen__sample_id'})
                );

                for my $file (@$files) {
                    (my $type = lc($file->{'type'})) =~ s/\W/_/g;
                    $sample->{'file__' . $type} = $file->{'file'};
                }
            }
            else {
                $sample->{'search_values'} = [
                    map { $sample->{ $_ } } @search_params
                ];
            }

            push @samples, $sample;
        }
    }

    $self->respond_to(
        json => sub {
            $self->render( json => { 
                samples       => \@samples, 
                search_fields => \@search_params,
                search_fields_pretty => [
                    map { s/__/: /; s/_/ /g; ucfirst($_) } @search_params
                ],
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
    my $dbh  = $self->db->dbh;
    my $sql  = q'
        select p.project_id, p.project_name, p.pi,
               s.sample_id, s.sample_name, s.latitude, s.longitude
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
sub sample_file_list {
    my $self      = shift;
    my $sample_id = $self->param('sample_id');
    my $schema    = $self->db->schema;
    my $Sample    = $schema->resultset('Sample')->find($sample_id) or 
        return $self->reply->exception("Bad sample id ($sample_id)");

    my @files = map { 
        { type => $_->sample_file_type->type, location => $_->file } 
    } $Sample->sample_files->all;

    say "files = ", dump(\@files);

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

1;
