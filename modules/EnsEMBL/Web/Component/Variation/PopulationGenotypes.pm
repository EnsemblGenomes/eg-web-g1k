package EnsEMBL::Web::Component::Variation::PopulationGenotypes;

sub format_frequencies {
  my ($self, $freq_data, $tg_flag) = @_;
  my $hub        = $self->hub;
  my $is_somatic = $self->object->Obj->is_somatic;
  my (%columns, @rows, @table_array);
  
  my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'pop asc', 'submitter asc' ] });
  
  # split off 1000 genomes, HapMap and failed if present
  if (!$tg_flag) {
    my ($tg_data, $hm_data, $fv_data, $pi_data, $no_pop_data, $mgp_data, $esp_data);

    foreach my $pop_id (keys %$freq_data) {
      if ($pop_id eq 'no_pop') {
        $no_pop_data = delete $freq_data->{$pop_id};
        next;
      }

      my $name = $freq_data->{$pop_id}{'pop_info'}{'Name'};

      foreach my $ssid (keys %{$freq_data->{$pop_id}{'ssid'}}) {

        if ($freq_data->{$pop_id}{'ssid'}{$ssid}{'failed_desc'}) {
          $fv_data->{$pop_id}{'ssid'}{$ssid}                = delete $freq_data->{$pop_id}{'ssid'}{$ssid};
          $fv_data->{$pop_id}{'pop_info'}                 = $freq_data->{$pop_id}{'pop_info'};
          $fv_data->{$pop_id}{'ssid'}{$ssid}{'failed_desc'} =~ s/Variation submission/Variation submission $ssid/;
        } elsif ($name =~ /^1000genomes\:phase.*/i) {
          $tg_data->{$pop_id}{'ssid'}{$ssid} = delete $freq_data->{$pop_id}{'ssid'}{$ssid};
          $tg_data->{$pop_id}{'pop_info'}  = $freq_data->{$pop_id}{'pop_info'};
        } elsif ($name =~ /^cshl\-hapmap/i) {
          $hm_data->{$pop_id}{'ssid'}{$ssid} = delete $freq_data->{$pop_id}{'ssid'}{$ssid};
          $hm_data->{$pop_id}{'pop_info'}  = $freq_data->{$pop_id}{'pop_info'};
        } elsif ($name =~ /^Mouse_Genomes_project/i) {
          $mgp_data->{$pop_id}{'ssid'}{$ssid} = delete $freq_data->{$pop_id}{'ssid'}{$ssid};
          $mgp_data->{$pop_id}{'pop_info'}  = $freq_data->{$pop_id}{'pop_info'};
        } elsif ($name =~ /^ESP/i) {
          $esp_data->{$pop_id}{'ssid'}{$ssid} = delete $freq_data->{$pop_id}{'ssid'}{$ssid};
          $esp_data->{$pop_id}{'pop_info'}  = $freq_data->{$pop_id}{'pop_info'};
        }
      }
    }

    #  recurse this method with just the tg_data and a flag to indicate it
    push @table_array,  @{$self->format_frequencies($tg_data, '1000 Genomes')} if $tg_data;
    push @table_array,  @{$self->format_frequencies($hm_data, 'HapMap')}       if $hm_data;
    push @table_array,  @{$self->format_frequencies($fv_data, 'Inconsistent data')}  if $fv_data;
    push @table_array,  @{$self->format_frequencies($mgp_data, 'Mouse Genomes Project')}  if $mgp_data;
    push @table_array,  @{$self->format_frequencies($esp_data, 'ESP')}  if $esp_data;
 
    # special method for data with no pop/freq data
    push @table_array,  ['Observed variant(s) without frequency or population', $self->no_pop_data($no_pop_data)]  if $no_pop_data;
  }
    
 foreach my $pop_id (keys %$freq_data) {
    my $pop_info = $freq_data->{$pop_id}{'pop_info'};

    foreach my $ssid (keys %{$freq_data->{$pop_id}{'ssid'}}) {
      my $data = $freq_data->{$pop_id}{'ssid'}{$ssid};
      my %pop_row;

      # SSID + Submitter
      if ($ssid) {
        $pop_row{'ssid'}      = $hub->get_ExtURL_link($ssid, 'DBSNPSS', $ssid) unless $ssid eq 'ss0';
        $pop_row{'submitter'} = $hub->get_ExtURL_link($data->{'submitter'}, 'DBSNPSSID', $data->{'submitter'});
      }

      # Freqs alleles
      my @allele_freq = @{$data->{'AlleleFrequency'}};

      foreach my $gt (@{$data->{'Alleles'}}) {
        next unless $gt =~ /(\w|\-)+/;

        my $allele_count = shift @{$data->{'AlleleCount'}} || undef;

        $pop_row{'Allele count'}{$gt}      = "$allele_count <strong>($gt)</strong>" if defined $allele_count;
        $gt = substr($gt,0,10).'...' if (length($gt)>10);
# EG removed br
        $pop_row{"Alleles $gt"} = $self->format_number(shift @allele_freq);
      }

      $pop_row{'Allele count'} = join ' / ', sort {(split /\(|\)/, $a)[1] cmp (split /\(|\)/, $b)[1]} values %{$pop_row{'Allele count'}} if $pop_row{'Allele count'};
      
      # Freqs genotypes
      my @genotype_freq = @{$data->{'GenotypeFrequency'} || []};
## EG : for saccharomyces it does not make sense
      if ($self->object->species_defs->SPECIES_SCIENTIFIC_NAME ne 'Saccharomyces cerevisiae')
      {
	foreach my $gt (@{$data->{'Genotypes'}}) {
	    my $genotype_count = shift @{$data->{'GenotypeCount'}} || undef;
	    $pop_row{'Genotype count'}{$gt}      = "$genotype_count <strong>($gt)</strong>" if defined $genotype_count;
#EG removed br
	    $pop_row{"Genotypes $gt"} = $self->format_number(shift @genotype_freq);
	}
      }
      
      $pop_row{'Genotype count'}   = join ' / ', sort {(split /\(|\)/, $a)[1] cmp (split /\(|\)/, $b)[1]} values %{$pop_row{'Genotype count'}} if $pop_row{'Genotype count'};
      $pop_row{'pop'}              = $self->pop_url($pop_info->{'Name'}, $pop_info->{'PopLink'});
      $pop_row{'Description'}      = $pop_info->{'Description'} if $is_somatic;
      $pop_row{'failed'}           = $data->{'failed_desc'}             if $tg_flag =~ /failed/i;
      $pop_row{'Super-Population'} = $self->sort_extra_pops($pop_info->{'Super-Population'});
      $pop_row{'Sub-Population'}   = $self->sort_extra_pops($pop_info->{'Sub-Population'});
      $pop_row{'detail'}           = $self->ajax_add($self->ajax_url(undef, { function => 'IndividualGenotypes', pop => $pop_id, update_panel => 1 }), $pop_id) if ($pop_info->{Size});;

      # force ALL population to be displayed on top
      if($pop_info->{'Name'} =~ /ALL/) {
        $pop_row{'pop'} = qq{<span class="hidden">0</span>}.$pop_row{'pop'};
      }

      push @rows, \%pop_row;

      $columns{$_} = 1 for grep $pop_row{$_}, keys %pop_row;
    }
  }

  # Format table columns
  my @header_row;
  
  foreach my $col (sort { $b cmp $a } keys %columns) {
    next if $col =~ /pop|ssid|submitter|Description|detail|count|failed/;
    unshift @header_row, { key => $col, align => 'left', title => $col, sort => 'numeric' };
  }
  
  if (exists $columns{'ssid'}) {
    unshift @header_row, { key => 'submitter', align => 'left', title => 'Submitter', sort => 'html'   };
    unshift @header_row, { key => 'ssid',      align => 'left', title => 'ssID',      sort => 'string' };
  }
  
  unshift @header_row, { key => 'Description',    align => 'left', title => 'Description',                           sort => 'none'   } if exists $columns{'Description'};
  unshift @header_row, { key => 'pop',            align => 'left', title => ($is_somatic ? 'Sample' : 'Population'), sort => 'html'   };
  push    @header_row, { key => 'Allele count',   align => 'left', title => 'Allele count',                          sort => 'none'   } if exists $columns{'Allele count'};
  push    @header_row, { key => 'Genotype count', align => 'left', title => 'Genotype count',                        sort => 'none'   } if exists $columns{'Genotype count'};
  push    @header_row, { key => 'detail',         align => 'left', title => 'Genotype detail',                       sort => 'none'   } if $self->object->counts->{'individuals'};
  push    @header_row, { key => 'failed',         align => 'left', title => 'Comment', width => '25%',               sort => 'string' } if $columns{'failed'};
  
  $table->add_columns(@header_row);
  $table->add_rows(@rows);
  
  push @table_array, [ sprintf('%s (%s)', $tg_flag || 'Other data', scalar @rows), $table ];

  return \@table_array;
}

1;