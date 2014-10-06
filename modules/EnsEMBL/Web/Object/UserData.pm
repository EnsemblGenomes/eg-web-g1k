package EnsEMBL::Web::Object::UserData;

use strict;
use LWP::UserAgent;
use Vcf;
use Bio::EnsEMBL::ExternalData::VCF::VCFAdaptor;
use Bio::EnsEMBL::Utils::Iterator;

sub move_to_user {
  my $self = shift;
  my %args = (
    type => 'upload',
    @_,
  );

  my $hub     = $self->hub;
  my $user    = $hub->user;
  my $session = $hub->session;

  my $data = $session->get_data(%args);
  my $record;
  
  $record = $user->add_to_uploads($data)
    if $args{'type'} eq 'upload';

  $record = $user->add_to_urls($data)
    if $args{'type'} eq 'url';
# 1kg
  $record = $user->add_to_bams($data)
    if $args{'type'} eq 'bam';

  $record = $user->add_to_vcfs($data)
    if $args{'type'} eq 'vcf';
# /1kg
  if ($record) {
    $session->purge_data(%args);
    return $record;
  }
  
  return undef;
}


sub compare_hashes {
  my ($self, $a, $b) = @_;
  my %a = %{$a};
  my %b = %{$b};

  if (%a != %b) {
    return 0;
  } else {
    my %cmp = map { $_ => 1 } keys %a;
    for my $key (keys %b) {
        last unless exists $cmp{$key};
        last unless $a{$key} eq $b{$key};
        delete $cmp{$key};
    }
    if (%cmp) {
        return 0;
    } else {
        return 1;
    }
  }
}

sub variations_map_table {
  my ($self, $all_pops, $cols, $loc, $tran, $samp, $pattern, $freq, $refs) = @_;

  my $columns   = [];
  my $columns1  = [];
  my $columns2  = [];
  my @rows      = ();
  my @rows1     = ();
  my @rows2     = ();
  my $row       = [];  
  my $row1      = [];
  my $row2      = [];
  my $hash_pops = {};
  my $exp_row   = [];
  my $key_title = {};
  my $variations = [];

  $all_pops = [ sort { $a cmp $b } @$all_pops ];
  foreach my $pop (@$all_pops) {
    push @$columns2, { key => $pop, title => $pop, align => 'left',  style => {'white-space'=>'nowrap','min-height','20px'}};
    push @{$exp_row->[0]}, $pop;
    $key_title->{$pop} = $pop;
  }

  my $total_tran = 0;
  my $doubler    = {};
  foreach my $tvar (keys %{$tran}) {
    $total_tran = (scalar @{$tran->{$tvar}}) unless ($total_tran > (scalar @{$tran->{$tvar}}));
    my $rind = 1;
    foreach my $tran_con (@{$tran->{$tvar}}) {
      #variation table rows containing <br> are vertically stretched; their height should be in sync with the height of the corresponding rows in the population table
      if ($tran_con =~ /<br>/) {
        $doubler->{$rind} = 1;
      } else {
  $doubler->{$rind} = 0 unless exists $doubler->{$rind};
      }
      $rind++;
    }
  }

  my $all_variations = 0;
  my $exist_ind      = {};
  my @sorted_v = sort {$loc->{$b} cmp $loc->{$a}} keys %{$samp};

  push @$columns1, { key => 'freq', title => 'Freq', align => 'left', style => {'white-space'=>'nowrap','min-height','20px'} };
  push @{$exp_row->[0]}, 'freq';
  $key_title->{'freq'} = 'Freq';
  my @sorted_f     = sort { $freq->{$b} <=> $freq->{$a} } keys %{$freq}; 

  #$all_patterns contains all unique patterns (apart from '-----' pattern in collapsed view - that one is skipped)
  my $all_patterns = [];
  foreach my $sorted_by_f (@sorted_f) {
    push @{$all_patterns || []}, $pattern->{$sorted_by_f} unless grep { $self->compare_hashes($pattern->{$sorted_by_f}, $_) } @{$all_patterns || []};      
  }

  foreach my $var (@sorted_v) {
    foreach my $ind (keys %{$samp->{$var}}) {
      my $rowind = 0;
      if (!$row->[$rowind]->{$var}) {
        $all_variations++;
  unshift @$columns, { key => $var, title => $var.':'.$refs->{$var}, align => 'left', style => {'white-space'=>'nowrap','min-height','20px'}};
        unshift @$variations, $var;
        $key_title->{$var} = $var.':'.$refs->{$var};
        $row1->[$rowind]->{'freq'} = "&nbsp;";
  $row->[$rowind++]->{$var} = $loc->{$var};

        foreach my $tran_con (@{$tran->{$var}}) {
          $row1->[$rowind]->{'freq'} = ($tran_con =~ /<br>/) ? "&nbsp;<br>&nbsp;" : "&nbsp;";
    $row->[$rowind++]->{$var} = $tran_con;            
        }
      } 

      #calculate the row index:       
      my $index_ind = 0;
      my $jj = 0 ;
      foreach (@{$all_patterns}) {      
        $index_ind = $self->compare_hashes($_, $pattern->{$ind}) ? $jj : "N/A";        
        last if      $self->compare_hashes($_, $pattern->{$ind});       
        $jj++;
      }

      #if $pattern->{$ind} is not found in $all_patterns, it means this pattern is containing '-' in all the positions and we need to skip it:
      next if $index_ind eq "N/A";
      
      #each unique pattern is displayed on a separate row; in the very last column of this row the frequency for that pattern is shown
      $rowind = $total_tran + 1 + $index_ind;    
      $row->[$rowind]->{$var}   = $samp->{$var}->{$ind};   #genotype
      $row1->[$rowind]->{'freq'} = $freq->{$ind} unless exists $row->[$rowind]->{'freq'};  #frequency

      #all the individuals which share the same pattern are listed in one and the same row in Population table, grouped in separate columns according their population
      push @{$hash_pops->{$rowind}->{$cols->{$var}->{$ind}}}, $ind unless grep { $ind eq $_ } @{$hash_pops->{$rowind}->{$cols->{$var}->{$ind}}};
    }
  }

  my @sorted = sort {$a <=> $b} keys %{$hash_pops};
  foreach my $rowindex (keys %{$hash_pops}) {
    foreach my $pop (keys %{$hash_pops->{$rowindex}}) {
      $row2->[$rowindex]->{'options'}->{'class'}='td_nowrap';
      foreach my $rowindex2 (0..($sorted[0] - 1)) {
        #population table rows' height should be in sync with the height of the corresponding rows in the variation table            
       $row2->[$rowindex2]->{$pop} = $rowindex2 && (exists $doubler->{$rowindex2}) && $doubler->{$rowindex2}  ? "&nbsp;<br>&nbsp;" : "&nbsp;";
      }
      my $indgens = @{$hash_pops->{$rowindex}->{$pop}} - 2;
      $row2->[$rowindex]->{$pop} = join(', ' , @{$hash_pops->{$rowindex}->{$pop}}) if @{$hash_pops->{$rowindex}->{$pop}} <= 2;            
      $row2->[$rowindex]->{$pop} = join(', ' , ($hash_pops->{$rowindex}->{$pop}->[0], $hash_pops->{$rowindex}->{$pop}->[1])) . " and $indgens other(s)" if @{$hash_pops->{$rowindex}->{$pop}} > 2;     
    }
  }

  my $ii;
  push @{$exp_row->[0]}, @{$variations};
  for($ii = 1; $ii <= (scalar @{$row}); $ii++) {
    my $rind = $ii - 1;
    foreach my $col (@{$exp_row->[0]}) { 
      my $val = ' ';
      if (exists $row->[$rind]->{$col}) {
  $val = $row->[$rind]->{$col};
      } elsif (exists $row1->[$rind]->{$col}) {  
  $val = $row1->[$rind]->{$col};
      } elsif(exists $row2->[$rind]->{$col}) {
        $val = $row2->[$rind]->{$col};
      }
      $val =~ s/&nbsp;<br>&nbsp;/ /g;
      $val =~ s/(<br>|&nbsp;)/ /g;
      $val =~ s/,/;/g;
      $val =~ s/<[^>]+>//g;
      push @{$exp_row->[$ii]}, $val;
    }
  }
  
  for($ii = 0; $ii < (scalar @{$exp_row->[0]}); $ii++) {
    $exp_row->[0]->[$ii] = $key_title->{$exp_row->[0]->[$ii]}; 
  }

  my $v_table = $self->subtable_rows($row,  $columns,  'Variation info',  $total_tran, $all_variations, 'ta1');
  my $f_table = $self->subtable_rows($row1, $columns1, '&nbsp;&nbsp;',   $total_tran, '1', 'ta2'); #Freq
  my $p_table = $self->subtable_rows($row2, $columns2, 'Population', $total_tran, scalar @$all_pops, 'ta3');

  my $html = qq();

 $html .= qq(<div id="divMainH" style="overflow-x: hidden; overflow-y: hidden; padding: 0; margin: 0;">
               <div id="divHeaderTables" style="overflow-x: hidden; overflow-y: scroll; padding: 0; margin: 0;">
                 <div id="divHeadTableV" style="width: 30%; float: left;  overflow-x: scroll; overflow-y: hidden; padding: 0; margin: 0; display: inline;" class="TabBoxV">
                   $p_table->[0]
                 </div>
                 <div id="divHeadTableF" style="width: 8%;  float: left;  overflow-x: scroll; overflow-y: hidden; padding: 0; margin: 0; display: inline;" class="TabBoxF">
                   $f_table->[0]
                 </div>
                 <div id="divHeadTableP" style="width: 62%; float: right; overflow-x: scroll; overflow-y: hidden; padding: 0; margin: 0; display: inline;" class="TabBoxP">
                   $v_table->[0]
                 </div>
               </div>
               <div id="divBodyTables" style="overflow-x: hidden; overflow-y: scroll; padding: 0; margin: 0;">
                 <div id="divBodyTableV" style="width: 30%; float: left;  overflow-x: hidden; overflow-y: hidden; padding: 0; margin: 0; display: inline;" class="TabBoxV">
                   $p_table->[1]
                 </div>
                 <div id="divBodyTableF" style="width: 8%;  float: left;  overflow-x: hidden; overflow-y: hidden; padding: 0; margin: 0; display: inline;" class="TabBoxF">
                   $f_table->[1]
                 </div>
                 <div id="divBodyTableP" style="width: 62%; float: right; overflow-x: hidden; overflow-y: hidden; padding: 0; margin: 0; display: inline;" class="TabBoxP">
                   $v_table->[1]
                 </div>
               </div>
       </div>);

  return ($html, $exp_row);

}

sub subtable {
    my ($self, $columns, $rows, $row_style, $colspan, $id, $title) = @_;
    my $table   = new EnsEMBL::Web::Document::Table($columns,  $rows,    { margin => '0px', style => $row_style,  no_skip => '1', id => $id  });
    $table->add_spanning_headers({ title => $title,  colspan => $colspan   }) if ($title =~ /.+/);
    return $table->render;
}

sub subtable_rows {
    my ($self, $row, $columns, $title, $total_tran, $colspan, $id) = @_;
    my (@rows, @hrows);

    my $hindex = 0;

    foreach my $vrow (@$row) {
      if ($hindex <= $total_tran) {
        #@hrows contains the data for the header table
        push @hrows, $vrow; 
      } else { 
        #@rows contains the data for the genotype table
        push @rows, $vrow;
      }
      $hindex++;
    }

    my ($row_style, $hrow_style);
    foreach my $row_count (0..($#$row)) {
      foreach my $counter (0..($#$columns)) {
        my $fontsize = $row_count <= $total_tran && $row_count ? '10px':'';
  $row_style->[$row_count]->[$counter] = {'white-space'=>'nowrap', 'min-height'=>'20px'};         
        $hrow_style->[$row_count]->[$counter] = {'white-space'=>'nowrap', 'min-height'=>'20px','font-size'=>$fontsize};
      }
    }

    my $bcolumns;
    #Hide the column titles in the genotype table
    foreach (@$columns) {
      push @$bcolumns, { key => $_->{'key'}, title => $_->{'title'}, align => $_->{'align'}, style => {%{$_->{'style'}},display=>'none'}};
    }

    my $htable = $self->subtable($columns,   \@hrows,   $hrow_style, $colspan, 'head'.$id, $title);
    my $table  = $self->subtable($bcolumns,  \@rows,  $row_style,  $colspan, $id);

    return [ $htable, $table ];
}

sub predict_snp_func {
    my ($self, $transcript_adaptor, $gene_adaptor, $vf) = @_;

    # get the consequence types                                                                                                                                                                               
    my %tc_string;
    my (@list_g, @list_t, @list_c);
    foreach my $tv (@{$vf->get_all_TranscriptVariations}) {
  foreach my $string (@{$tv->consequence_type}) {
            next if (       $string eq "DOWNSTREAM" ||
                                                $string eq "UPSTREAM" ||
                                                                $string eq "WITHIN_NON_CODING_GENE" ||
                                                                $string eq "SYNONYMOUS_CODING" ||
                                                                $string eq "INTERGENIC" ||
                                                                $string eq "INTRONIC" ||
                                                                $string eq "NMD_TRANSCRIPT"
      ); ##### NMD_TRANSCRIPT is more an annotation of the transcript than that of a SNP        

            my $consequence_pep = $string;
            eval {
              $consequence_pep = $tv->pep_allele_string ? $string . ":" .  $tv->pep_allele_string : $string;
      };

      push @{$tc_string{$tv->transcript->stable_id}},  $consequence_pep;

      if ($tv->transcript) {
    my $gene_id       = '-';
    my $transcript_id = '-';
    my $tr_slice;

    $transcript_id   = $tv->transcript->stable_id;
                my $tran_con     = $transcript_id. '<br>'. $consequence_pep;
    my $transcript   = $transcript_adaptor->fetch_by_stable_id($transcript_id);
    $tr_slice        = $transcript->feature_Slice;
    $tr_slice        = $tr_slice->invert if $tr_slice->strand < 1;  ## Put back onto correct strand                                                                                                    

    if (($tr_slice->start <= $vf->seq_region_start) && ($vf->seq_region_start <= $tr_slice->end)) {
        my $gene = $gene_adaptor->fetch_by_transcript_id($tv->transcript->dbID);
        $gene_id = $gene ? $gene->stable_id : '';

        push @list_t, $tran_con          unless (grep { $tran_con          eq $_ } @list_t);
        push @list_c, $consequence_pep   unless (grep { $consequence_pep   eq $_ } @list_c);
    }
      } #if if ($tv->transcript)                             
  }
    }

    my $list_t = scalar @list_t ? join(',', @list_t) : '&nbsp;';
    my $list_c = scalar @list_c ? join(',', @list_c) : '&nbsp;';

    return (scalar @list_t) || (scalar @list_c) ? [$list_t, $list_c] : [];
}



sub variations_map_vcf {

    my ($self, $file, $sample_panel, $region, $collapsed) = @_;

    foreach ($file, $sample_panel, $region) {
  $_ =~ s/^\s+|\s+$//g;
    }

    return "error:Please provide VCF file, chromosomal region and Sample-Population Mapping file." if (!$file || !$region || !$sample_panel);
    return "error:The chromosomal region value $region is invalid."                            unless ($region =~ /^(.+?):(\d+)-(\d+)$/);

    my ($host, $directory, $sample_file) = $sample_panel =~ /ftp:\/\/(.*?)\/(.*)\/(.*)$/;  

    my %sample_pop;
    if ( -e $sample_panel ) {
      open(SP, $sample_panel);
      while (<SP>) {
        chomp;
  s/^\s+|\s+$//g;
  my ($sam, $pop, $plat) = split(/\t/, $_);
  $sample_pop{$sam} = $pop;
      }
      close SP;
    } elsif ($sample_panel =~ /ftp:\/\//) {
      my $ua = LWP::UserAgent->new;
      $ua->timeout(10);
      $ua->env_proxy;
    
      my $response = $ua->get($sample_panel);
      return "error:Sample-Population Mapping file has no content." unless $response->is_success;

      my @content = split /\n/, $response->content(); #$response->decoded_content;   
      foreach (@content) {
        chomp;
        s/^\s+|\s+$//g;
        my ($sam, $pop, $plat) = split(/\t/, $_);
        $sample_pop{$sam} = $pop;
      }
    } else {
      return "error:Sample-Population Mapping file $sample_panel can not be found.";
    }

    my ($chr, $s, $e) = $region =~ /(.+?):(\d+?)-(\d+?)/;
    my $vcf;
    eval {
      $vcf = Vcf->new(file=>$file, region=>$region,  print_header=>1, silent=>1); #print_header allows print sample name rather than column index
    };

    return "error:Error reading VCF file" unless ($vcf);

    $vcf->parse_header();
  
    my $species     =  $self->species;
    my %species_dbs =  %{$self->species_defs->get_config($species, 'databases')};
    my $vfa;
    if (exists $species_dbs{'DATABASE_VARIATION'} ){
      $vfa = $self->get_adaptor('get_VariationFeatureAdaptor', 'variation', $species);
    } else  {
      $vfa = Bio::EnsEMBL::Variation::DBSQL::VariationFeatureAdaptor->new_fake($species);
    }

    my $gene_adaptor  = $self->get_adaptor('get_GeneAdaptor', 'core', $species);
    my $transcript_adaptor  = $self->get_adaptor('get_TranscriptAdaptor', 'core', $species);
    my $slice_adaptor = $self->get_adaptor('get_SliceAdaptor', 'core', $species);

    my ($cols, $loc, $tran, $con, $freq, $refs, $samp, $pattern, $skip_p)  = ({}, {}, {}, {}, {}, {}, {}, {}, {});
    my $all_pops  = [];
    my $exist_pop = {};
    my $conflag   = 0;
    my $indflag1  = 0;
    my $varflag   = 0;
    my $all_gt    = 0;

    while (my $x=$vcf->next_data_hash()) {
        $varflag++;
  my $genotype   = $x->{REF}   . "/" . $x->{ALT}->[0];   ##In SNP predictor, the phase information is not kept.                                                    
  my $identifier = $x->{CHROM} . ":" . $x->{POS};
        my $pos        = $x->{POS};
  my $ref        = $x->{REF};
        my $variation_name = $identifier;
        $variation_name    = $x->{'ID'} unless $x->{'ID'} =~ /^\.$/;

        # get a slice for the new feature to be attached to                                                                                                                                                   
        my $slice = $slice_adaptor->fetch_by_region('chromosome', $chr);

        # create a new VariationFeature object                                                                                                                                                  
        my $vf = Bio::EnsEMBL::Variation::VariationFeature->new(
          -start => $pos,
          -end => $pos,
          -slice => $slice,                     # the variation must be attached to a slice                                                                                                         
          -allele_string => $genotype,          # the first allele should be the reference allele                                                                                           
          -strand => 1,                         # For 1KG SNPs, use 1                                                                                    
          -map_weight => 1,
          -adaptor => $vfa,                     # we must attach a variation feature adaptor                                                          
          -variation_name => $identifier,
  );

        my $list = $self->predict_snp_func($transcript_adaptor, $gene_adaptor, $vf);
        next unless scalar @$list;
        my ($list_t, $list_c) = @$list;

        $conflag++;
        my @tran_con = split(/,/, $list_t);

        $cols->{$variation_name}  = {};
        $loc->{$variation_name}   = $chr.':'.$pos;
        $tran->{$variation_name}  = [@tran_con];

        #For snps there will never be more than 3 possibilities - $x->{REF}, $x->{ALT}->[0], $x->{ALT}->[1]: 
        $refs->{$variation_name}  = exists $x->{ALT}->[1] ? $ref.'/'.$x->{ALT}->[0].'/'.$x->{ALT}->[1] : $ref.'/'.$x->{ALT}->[0];

        my $allele_0 = $x->{REF};
        my $allele_1 = $x->{ALT}->[0];
        my $allele_2 = exists $x->{ALT}->[1] ? $x->{ALT}->[1] : '';
        my $allele_colors = { $allele_0 => 'blue', $allele_1 => 'red', $allele_2 => 'green' };

        $all_gt = scalar keys %{$$x{gtypes}} if !$all_gt;
        for my $individual (keys %{$$x{gtypes}}) {
          my ($al1,$sep,$al2) = $vcf->parse_alleles($x,$individual);
          my $indgenotype = $collapsed && (($al1 eq $x->{REF} && $al2 eq $x->{REF}) || ($al1 eq "." && $al2 eq ".")) ? 
                            '-' : 
                            '<span style="color:'.$allele_colors->{$al1}.';">'.$al1.'</span>'.$sep.'<span style="color:'.$allele_colors->{$al2}.';">'.$al2.'</span>';
          
          $indflag1++;
          my $pop = $sample_pop{$individual} || '';
          next unless $pop;

          $cols->{$variation_name}->{$individual}    = $pop;
          $samp->{$variation_name}->{$individual}    = $indgenotype; 
          $pattern->{$individual}->{$variation_name} = $indgenotype;
          $skip_p->{$individual}->{$variation_name}  = (($al1 eq $x->{REF} && $al2 eq $x->{REF}) || ($al1 eq "." && $al2 eq ".")) ? "-" : $al1.$sep.$al2; 
        }
    } # while (my $x=$vcf->next_data_hash())

    my %unique_allele_strings;
    foreach my $ind (keys %{$pattern}) {  
      my $allele_string;
      my @sorted_v = sort {$a cmp $b} keys %{$pattern->{$ind}};
      my $all_v    = scalar @sorted_v;
      my $flag_nonsign = 0;
      foreach (@sorted_v) {
  $allele_string .= $pattern->{$ind}->{$_} . "\t";
        $flag_nonsign++ if $skip_p->{$ind}->{$_} eq "-";
      }

      #Don't store pattern which contains no alternative alleles:
      $unique_allele_strings{$allele_string}{$ind} = 1 unless $all_v == $flag_nonsign;
    }

    foreach my $allele_chain (keys %unique_allele_strings) {
      my @samples =  keys %{$unique_allele_strings{$allele_chain}};

      my $frequency = @samples/$all_gt;
      my $tmp = sprintf ("%.3f", $frequency);
      foreach (keys %{$unique_allele_strings{$allele_chain}}) {
        $freq->{$_} = $tmp;
        my $pop = $sample_pop{$_} || '';
        push @$all_pops, $pop  unless exists $exist_pop->{$pop};
  $exist_pop->{$pop} = 1 unless exists $exist_pop->{$pop};
      }
    }

    return "error:No variation of functional significance is found in VCF file $file in the region $region."   unless ($varflag && $conflag);
    return "error:No variations with individual genotypes in VCF file $file in the region $region."            unless ($indflag1);
    return "error:No variations related to a population in VCF file $file in the region $region."              unless (scalar @$all_pops);

    return $self->variations_map_table($all_pops, $cols, $loc, $tran, $samp, $pattern, $freq, $refs);
}

#------------------------------- Variation functionality -------------------------------
sub calculate_consequence_data {
  my ($self, $file, $size_limit) = @_;
  my $data = $self->hub->fetch_userdata_by_id($file);
  my %slice_hash;
  my %consequence_results;
  my ($f, @snp_effects, @vfs);
  my $count =0;
  my $feature_count = 0;
  my $file_count = 0;
  my $nearest;
  my %slices;
  
  # build a config hash - used by all the VEP methods
  my $vep_config = $self->configure_vep;
  
  ## Convert the SNP features into SNP_EFFECT features
  if (my $parser = $data->{'parser'}){ 
    foreach my $track ($parser->{'tracks'}) {
      foreach my $type (keys %{$track}) { 
        my $features = $parser->fetch_features_by_tracktype($type);
        
        # include failed variations
        $vep_config->{vfa}->db->include_failed_variations(1) if defined($vep_config->{vfa}->db) && $vep_config->{vfa}->db->can('include_failed_variations');
        
        while ( $f = shift @{$features}){
          $file_count++;
          next if $feature_count >= $size_limit; # $size_limit is max number of v to process, if hit max continue counting v's in file but do not process them
          $feature_count++;
          
          # if this is a variation ID or HGVS, we can use VEP.pm method to parse into VFs
          if($f->isa('EnsEMBL::Web::Text::Feature::ID') || $f->isa('EnsEMBL::Web::Text::Feature::VEP_VCF')) {
            push @vfs, @{parse_line($vep_config, $f->id)};
            next;
          }
          
          # Get Slice
          my $slice = get_slice($vep_config, $f->seqname);
          next unless defined($slice);
          
          unless ($f->can('allele_string')){
            my $html ='The uploaded data is not in the correct format.
# 1kg
              See <a href="/info/docs/variation/vep/index.html">here</a> for more details.';   #1kg: a link to vep; this is the only change in this function (revision 1.106.2.4); 
            my $error = 1;
            return ($html, $error);
          }
          
          # name for VF can be specified in extra column or made from location
          # and allele string if not given
          my $new_vf_name = $f->extra || $f->seqname.'_'.$f->rawstart.'_'.$f->allele_string;
          
          # Create VariationFeature
          my $vf = Bio::EnsEMBL::Variation::VariationFeature->new_fast({
            start          => $f->rawstart,
            end            => $f->rawend,
            chr            => $f->seqname,
            slice          => $slice,
            allele_string  => $f->allele_string,
            strand         => $f->strand,
            map_weight     => 1,
            adaptor        => $vep_config->{vfa},
            variation_name => $new_vf_name,
          });
          
          next unless &validate_vf($vep_config, $vf);
          
          push @vfs, $vf;
        }
        
        foreach my $line(@{get_all_consequences($vep_config, \@vfs)}) {
          foreach (@OUTPUT_COLS) {
            $line->{$_} = '-' unless defined($line->{$_});
          }
          
          $line->{Extra} = join ';', map { $_.'='.$line->{Extra}->{$_} } keys %{ $line->{Extra} || {} };
          
          my $snp_effect = EnsEMBL::Web::Text::Feature::VEP_OUTPUT->new([
            $line->{Uploaded_variation},
            $line->{Location},
            $line->{Allele},
            $line->{Gene},
            $line->{Feature},
            $line->{Feature_type},
            $line->{Consequence},
            $line->{cDNA_position},
            $line->{CDS_position},
            $line->{Protein_position},
            $line->{Amino_acids},
            $line->{Codons},
            $line->{Existing_variation},
            $line->{Extra},
          ]);
          
          push @snp_effects, $snp_effect;
          
          # if the array is "full" or there are no more items in @features
          if(scalar @snp_effects == 1000 || scalar @$features == 0) {
            $count++;
            next if scalar @snp_effects == 0;
            my @feature_block = @snp_effects;
            $consequence_results{$count} = \@feature_block;
            @snp_effects = ();
          }
        }
        
        if(scalar @snp_effects) {
          $count++;
          my @feature_block = @snp_effects;
          $consequence_results{$count} = \@feature_block;
          @snp_effects = ();
        }
      }
    }
    $nearest = $parser->nearest;
  }
  
  if ($file_count <= $size_limit){
    return (\%consequence_results, $nearest);
  } else {  
    return (\%consequence_results, $nearest, $file_count);
  }
}


1;
