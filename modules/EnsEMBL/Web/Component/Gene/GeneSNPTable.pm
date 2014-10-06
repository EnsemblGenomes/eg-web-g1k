# $Id: GeneSNPTable.pm,v 1.1 2012-12-10 16:25:18 ek3 Exp $

package EnsEMBL::Web::Component::Gene::GeneSNPTable;

sub make_table {
  my ($self, $table_rows, $consequence_type) = @_;
    
  my $columns = [
    { key => 'ID',       sort => 'html'                                                    },
    { key => 'chr' ,     sort => 'position',  title => 'Chr: bp'                           },
    { key => 'Alleles',  sort => 'string',                               align => 'center' },
    { key => 'HGVS',     sort => 'string',    title => 'HGVS name(s)',   align => 'center' },
    { key => 'class',    sort => 'string',    title => 'Class',          align => 'center' },
    { key => 'Source',   sort => 'string'                                                  },
    # 1kg:
    { key => 'ma',   sort => 'string',    title => 'Minor allele',     align => 'center' },
    { key => 'maf',   sort => 'position',    title => 'Global frequency',     align => 'center' },
    # 1kg
    { key => 'status',   sort => 'string',    title => 'Validation',     align => 'center' },
    { key => 'snptype',  sort => 'string',    title => 'Type',                             },
    { key => 'aachange', sort => 'string',    title => 'Amino Acid',     align => 'center' },
    { key => 'aacoord',  sort => 'position',  title => 'AA co-ordinate', align => 'center' },
  ];
  
  # add SIFT and PolyPhen for human
  if ($self->hub->species eq 'Homo_sapiens') {
    push @$columns, (
      { key => 'sift',     sort => 'position_html', title => 'SIFT'     },
      { key => 'polyphen', sort => 'position_html', title => 'PolyPhen' },
    );
  }
  
  push @$columns, { key => 'Transcript', sort => 'string' };
  
  return $self->new_table($columns, $table_rows, { data_table => 1, sorting => [ 'chr asc' ], exportable => 1, id => "${consequence_type}_table" });
}

sub variation_table {
  my ($self, $consequence_type, $transcripts, $slice) = @_;
  my $hub         = $self->hub;
  my $cons_format = $hub->param('consequence_format');
  my $show_scores = $hub->param('show_scores');
  my @rows;
  
  # create some URLs - quicker than calling the url method for every variation
  my $base_url = $hub->url({
    type   => 'Variation',
    action => 'Mappings',
    vf     => undef,
    v      => undef,
    source => undef,
  });
  
  my $base_trans_url;
  my $url_transcript_prefix;

  if ($self->isa('EnsEMBL::Web::Component::LRG::LRGSNPTable')) {
    my $gene_stable_id     = $transcripts->[0] && $transcripts->[0]->gene ? $transcripts->[0]->gene->stable_id : undef;
    $url_transcript_prefix = 'lrgt';
    
    $base_trans_url = $hub->url({
      type    => 'LRG',
      action  => 'Summary',
      lrg     => $gene_stable_id,
      __clear => 1
    });
  } else {
    $url_transcript_prefix = 't';
    
    $base_trans_url = $hub->url({
      type   => 'Transcript',
      action => 'Summary',
      t      => undef,
    }); 
  }
  
  foreach my $transcript (@$transcripts) {
    my $transcript_stable_id = $transcript->stable_id;
    
    my %snps = %{$transcript->__data->{'transformed'}{'snps'} || {}};
   
    next unless %snps;
    
    my $gene_snps         = $transcript->__data->{'transformed'}{'gene_snps'} || [];
    my $tr_start          = $transcript->__data->{'transformed'}{'start'};
    my $tr_end            = $transcript->__data->{'transformed'}{'end'};
    my $extent            = $transcript->__data->{'transformed'}{'extent'};
    my $cdna_coding_start = $transcript->Obj->cdna_coding_start;
    my $gene              = $transcript->gene;
    
    foreach (@$gene_snps) {
      my ($snp, $chr, $start, $end) = @$_;
      my $raw_id               = $snp->dbID;
      my $transcript_variation = $snps{$raw_id};

      # 1kg:
      my $variation = $snp->variation();
      my $ma = $variation->minor_allele();
      my $maf = $variation->minor_allele_frequency();
      # 1kg

      next unless $transcript_variation;
      
      foreach my $tva(@{$transcript_variation->get_all_alternate_TranscriptVariationAlleles}) {
        my $skip = 1;

        if ($consequence_type eq 'ALL') {
          $skip = 0;
        } elsif ($tva) {
          foreach my $con (@{$tva->get_all_OverlapConsequences}) {
            if ($self->select_consequence_term($con, $cons_format) eq $consequence_type) {
              $skip = 0;
              last;
            }
          }
        }
        
        next if $skip;
        
        if ($tva && $end >= $tr_start - $extent && $start <= $tr_end + $extent) {
          my $validation        = $snp->get_all_validation_states || [];
          my $variation_name    = $snp->variation_name;
          my $var_class         = $snp->var_class;
          my $translation_start = $transcript_variation->translation_start;
          my $source            = $snp->source;
          
          my ($aachange, $aacoord) = $translation_start ? 
            ($tva->pep_allele_string, sprintf('%s (%s)', $translation_start, (($transcript_variation->cdna_start - $cdna_coding_start) % 3 + 1))) : 
            ('-', '-');
          
          my $url           = "$base_url;v=$variation_name;vf=$raw_id;source=$source";
          my $trans_url     = "$base_trans_url;$url_transcript_prefix=$transcript_stable_id";
          my $allele_string = $snp->allele_string;
          
          # break up allele string if too long (will disrupt highlight below, but for long alleles who cares)
          $allele_string =~ s/(.{20})/$1\n/g;
          
          # highlight variant allele in allele string
          my $vf_allele  = $tva->variation_feature_seq;
          $allele_string =~ s/$vf_allele/<b>$vf_allele<\/b>/g if $allele_string =~ /\//;
          
          # sort out consequence type string
          my $type = join ',<br />', map {$self->select_consequence_label($_, $cons_format)} @{$tva->get_all_OverlapConsequences || []};
          $type  ||= '-';
          
          my $sift = $self->render_sift_polyphen(
            $tva->sift_prediction || '-',
            $show_scores eq 'yes' ? $tva->sift_score : undef
          );
          
          my $poly = $self->render_sift_polyphen(
            $tva->polyphen_prediction || '-',
            $show_scores eq 'yes' ? $tva->polyphen_score : undef
          );
          
          # Adds LSDB/LRG sources
          if ($self->isa('EnsEMBL::Web::Component::LRG::LRGSNPTable')) {
            my $var = $snp->variation;
            my $syn_sources = $var->get_all_synonym_sources;
            foreach my $s_source (@$syn_sources) {
              next if ($s_source !~ /LSDB|LRG/);
              
              my $synonym = ($var->get_all_synonyms($s_source))->[0];
              $source .= ", ".$hub->get_ExtURL_link($s_source, $s_source, $synonym);
            }
          }
          
          my $row = {
            ID         => qq{<a href="$url">$variation_name</a>},
            class      => $var_class,
            Alleles    => $allele_string,
            Ambiguity  => $snp->ambig_code,
            status     => (join(', ',  @$validation) || '-'),
            chr        => "$chr:$start" . ($start == $end ? '' : "-$end"),
            Source     => $source,
            # 1kg:  
            ma         => $ma || '-',
            maf        => $maf ? sprintf("%.3f", $maf) : '-',
            # 1kg
            snptype    => $type,
            Transcript => qq{<a href="$trans_url">$transcript_stable_id</a>},
            aachange   => $aachange,
            aacoord    => $aacoord,
            sift       => $sift,
            polyphen   => $poly,
            HGVS       => $self->get_hgvs($tva) || '-',
          };
          
          push @rows, $row;
        }
      }
    }
  }

  return \@rows;
}

1;
