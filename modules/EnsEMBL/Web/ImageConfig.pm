# $Id: ImageConfig.pm,v 1.3 2013-10-17 12:05:37 ek3 Exp $

package EnsEMBL::Web::ImageConfig;

sub menus {
  return $_[0]->{'menus'} ||= {
      #1kg:
    "g1k"               => '1000 Genomes',

    # Sequence
    seq_assembly        => 'Sequence and assembly',
    sequence            => [ 'Sequence',                'seq_assembly' ],
    misc_feature        => [ 'Clones & misc. regions',  'seq_assembly' ],
    genome_attribs      => [ 'Genome attributes',       'seq_assembly' ],
    marker              => [ 'Markers',                 'seq_assembly' ],
    simple              => [ 'Simple features',         'seq_assembly' ],
    ditag               => [ 'Ditag features',          'seq_assembly' ],
    dna_align_other     => [ 'GRC alignments',          'seq_assembly' ],
    dna_align_compara   => [ 'Imported alignments',     'seq_assembly' ],
    
    # Transcripts/Genes
    gene_transcript     => 'Genes and transcripts',
    transcript          => [ 'Genes',                  'gene_transcript' ],
    prediction          => [ 'Prediction transcripts', 'gene_transcript' ],
    lrg                 => [ 'LRG transcripts',        'gene_transcript' ],
    rnaseq              => [ 'RNASeq models',          'gene_transcript' ],
    
    # Supporting evidence
    splice_sites        => 'Splice sites',
    evidence            => 'Evidence',
    
    # Alignments
    mrna_prot           => 'mRNA and protein alignments',
    dna_align_cdna      => [ 'mRNA alignments',    'mrna_prot' ],
    dna_align_est       => [ 'EST alignments',     'mrna_prot' ],
    protein_align       => [ 'Protein alignments', 'mrna_prot' ],
    protein_feature     => [ 'Protein features',   'mrna_prot' ],
    dna_align_rna       => 'ncRNA',
    
    # Proteins
    domain              => 'Protein domains',
    gsv_domain          => 'Protein domains',
    feature             => 'Protein features',
    
    # Variations
    variation           => 'Variation',
    recombination       => [ 'Recombination & Accessibility', 'variation' ],
    somatic             => 'Somatic mutations',
    ld_population       => 'Population features',
    
    # Regulation
    functional          => 'Regulation',
    
    # Compara
    compara             => 'Comparative genomics',
    pairwise_blastz     => [ 'BLASTz/LASTz alignments',    'compara' ],
    pairwise_other      => [ 'Pairwise alignment',         'compara' ],
    pairwise_tblat      => [ 'Translated blat alignments', 'compara' ],
    multiple_align      => [ 'Multiple alignments',        'compara' ],
    conservation        => [ 'Conservation regions',       'compara' ],
    synteny             => 'Synteny',
    
    # Other features
    repeat              => 'Repeat regions',
    oligo               => 'Oligo probes',
    trans_associated    => 'Transcript features',
    
    # Info/decorations
    information         => 'Information',
    decorations         => 'Additional decorations',
    other               => 'Additional decorations',
    
    # External data
    user_data           => 'Your data',
    external_data       => 'External data',
  };
}


sub _add_msa_track {
    my ($self, %args) = @_;
    my ($menu, $source) = ($args{'menu'}, $args{'source'});

    $menu ||= $self->get_node('user_data');

    return unless $menu;

    my $time = $source->{'timestamp'};
    my $key = $args{'key'} || 'msa_' . $time . '_' . md5_hex($self->{'species'} . ':' . $source->{'source_url'});
    my $sname =  $source->{'source_name'} ||  $source->{'name'};

    my $track = $self->create_track($key, $sname, {
      display     => 'on',     #1kg: user tracks are ON by default
      glyphset    => 'msa',
      sources     => undef,
      strand      => 'f',
      depth       => 0.5,
      format      => $source->{'format'},
      bump_width  => 0,
      renderers   => [off => 'Off', normal => 'Normal'],
      data => $source->{'data'},
      fasta => $source->{'fasta'},
      id => $key,
      caption     => $source->{'caption'} || $sname,
      url         => $source->{'source_url'} || $source->{url},
      description => $source->{'description'} || sprintf('Data retrieved from a MSA file on an external webserver. This data is attached to the %s, and comes from URL: %s', encode_entities($source->{'source_type'}), encode_entities($source->{'source_url'} || $source->{'url'})),
});

$menu->append($track) if $track;
}


sub _add_vcf_track {
    my ($self, %args) = @_;
    my ($menu, $source) = ($args{'menu'}, $args{'source'});

    $menu ||= $self->get_node('user_data');
    return unless $menu;

    my $time = $source->{'timestamp'};

    my $key = $args{'key'} || 'vcf_' . $time . '_' . md5_hex($self->{'species'} . ':' . $source->{'source_url'});

    my $sname =  $source->{'source_name'} ||  $source->{'name'};
    my $track = $self->create_track($key, $sname, {
      display     => 'on',          #1kg: user tracks are ON by default
      glyphset    => 'vcf',
      sources     => undef,
      strand      => 'f',
      depth       => 0.5,
      bump_width  => 0,
      format      => $source->{'format'},
      colourset   => 'variation',
      renderers   => [off => 'Off', compact => 'Compact', histogram => 'Density'],
      caption     => $source->{'caption'} || $sname,
      url         => $source->{'source_url'} || $source->{url},
      description => $source->{'description'} || sprintf('Data retrieved from a VCF file on an external webserver. This data is attached to the %s, and comes from URL: %s', encode_entities($source->{'source_type'}), encode_entities($source->{'source_url'} || $source->{'url'})),
});

$menu->append($track) if $track;
}

sub _add_flat_file_track {
    my ($self, $menu, $sub_type, $key, $name, $description, %options) = @_;

    $menu ||= $self->get_node('user_data');

    return unless $menu;

    my ($strand, $renderers) = $self->_user_track_settings($options{'style'});

    my $track = $self->create_track($key, $name, {
    display     => 'on',       #1kg: user tracks are ON by default
    strand      => $strand,
    external    => 'url',
    glyphset    => '_flat_file',
    colourset   => 'classes',
    caption     => $name,
    sub_type    => $sub_type,
    renderers   => $renderers,
    description => $description,
    %options
    });

    $menu->append($track) if $track;
}

sub _add_file_format_track {
    my ($self, %args) = @_;

    my $menu = $args{'menu'} || $self->get_node('user_data');

    return unless $menu;

    my $type    = lc $args{'format'};
    my $article = $args{'format'} =~ /^[aeiou]/ ? 'an' : 'a';
    my $desc;

    if ($args{'internal'}) {
      $desc = sprintf('Data served from a %s file: %s', $args{'format'}, $args{'description'});
    } else {
      $desc = sprintf(
      "Data retrieved from %s %s file on an external webserver. %s
      This data is attached to the %s, and comes from URL: %s",
      $article,
                    $args{'format'},
                    $args{'description'},
                    encode_entities($args{'source'}{'source_type'}),
                    encode_entities($args{'source'}{'source_url'})
                    );
    }

    my $track = $self->create_track($args{'key'}, $args{'source'}{'source_name'}, {
    display     => 'on',            #1kg: user tracks are ON by default
    strand      => 'f',
    format      => $args{'format'},
    glyphset    => $type,
    colourset   => $type,
    renderers   => $args{'renderers'},
    caption     => $args{'source'}{'source_name'},
    url         => $args{'source'}{'source_url'},
    description => $desc,
    %{$args{'options'}}
  });

  $menu->append($track) if $track;
}

sub add_sequence_variations {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('variation');
  
  return unless $menu && $hashref->{'variation_feature'}{'rows'} > 0;
  
  my $options = {
    db         => $key,
    glyphset   => '_variation',
    strand     => 'r',
    depth      => 0.5,
    bump_width => 0,
    colourset  => 'variation',
    display    => 'off',
# 1kg: added Density
    renderers  => [ 'off', 'Off', 'histogram', 'Density', 'normal', 'Normal (collapsed for windows over 200kb)', 'compact', 'Collapsed', 'labels', 'Expanded with name (hidden for windows over 10kb)', 'nolabels', 'Expanded without name' ],
  };
  
  if (defined($hashref->{'menu'}) && scalar @{$hashref->{'menu'}} && grep {$_->{key} =~ /dbsnp/i} @{$hashref->{menu}}) {
    $self->add_sequence_variations_meta($key, $hashref, $options);
  } else {
    $self->add_sequence_variations_default($key, $hashref, $options);
  }

  $self->add_track('information', 'variation_legend', 'Variation Legend', 'variation_legend', { strand => 'r' });
}


sub add_somatic_mutations {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('somatic');
  
  return unless $menu;
  
  my $somatic = $self->create_submenu('somatic_mutation', 'Somatic variants');
  my %options = (
    db         => $key,
    glyphset   => '_variation',
    strand     => 'r',
    depth      => 0.5,
    bump_width => 0,
    colourset  => 'variation',
    display    => 'off',
# 1kg: added Density
    renderers  => [ 'off', 'Off', 'histogram', 'Density', 'normal', 'Normal (collapsed for windows over 200kb)', 'compact', 'Collapsed', 'labels', 'Expanded with name (hidden for windows over 10kb)', 'nolabels', 'Expanded without name' ],
  );
  
  # All sources
  $somatic->append($self->create_track("somatic_mutation_all", "Somatic variants (all sources)", {
    %options,
    caption     => 'Somatic variants (all sources)',
    description => 'Somatic variants from all sources'
  }));
  
   
  # Mixed source(s)
  foreach my $key_1 (keys(%{$self->species_defs->databases->{'DATABASE_VARIATION'}{'SOMATIC_MUTATIONS'}})) {
    if ($self->species_defs->databases->{'DATABASE_VARIATION'}{'SOMATIC_MUTATIONS'}{$key_1}{'none'}) {
      (my $k = $key_1) =~ s/\W/_/g;
      $somatic->append($self->create_track("somatic_mutation_$k", "$key_1 somatic variants", {
        %options,
        caption     => "$key_1 somatic variants",
        source      => $key_1,
        description => "Somatic variants from $key_1"
      }));
    }
  }
  
  # Somatic source(s)
  foreach my $key_2 (sort grep { $hashref->{'source'}{'somatic'}{$_} == 1 } keys %{$hashref->{'source'}{'somatic'}}) {
    next unless $hashref->{'source'}{'counts'}{$key_2} > 0;
    
    $somatic->append($self->create_track("somatic_mutation_$key_2", "$key_2 somatic mutations (all)", {
      %options,
      caption     => "$key_2 somatic mutations (all)",
      source      => $key_2,
      description => "All somatic variants from $key_2"
    }));
    
    my $tissue_menu = $self->create_submenu('somatic_mutation_by_tissue', 'Somatic variants by tissue');
    
    ## Add tracks for each tumour site
    my %tumour_sites = %{$self->species_defs->databases->{'DATABASE_VARIATION'}{'SOMATIC_MUTATIONS'}{$key_2} || {}};
    
    foreach my $description (sort  keys %tumour_sites) {
      next if $description eq 'none';
      
      my $phenotype_id           = $tumour_sites{$description};
      my ($source, $type, $site) = split /\:/, $description;
      my $formatted_site         = $site;
      $site                      =~ s/\W/_/g;
      $formatted_site            =~ s/\_/ /g;
      
      $tissue_menu->append($self->create_track("somatic_mutation_${key_2}_$site", "$key_2 somatic mutations in $formatted_site", {
        %options,
        caption     => "$key_2 $formatted_site tumours",
        filter      => $phenotype_id,
        description => $description
      }));    
    }
    
    $somatic->append($tissue_menu);
  }
  
  $menu->append($somatic);
}

1;
