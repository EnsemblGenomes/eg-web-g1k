# $Id: GeneSNPImage.pm,v 1.1 2012-12-10 16:25:18 ek3 Exp $

package EnsEMBL::Web::Component::Gene::GeneSNPImage;

use Data::Dumper;

sub _init {
    my $self = shift;
    $self->cacheable(0);
    $self->ajaxable(1);
    $self->configurable(1);
    $self->has_image(1);
}

sub content {
  my $self    = shift;

  my $no_snps = shift;
  my $ic_type     = shift || 'GeneSNPView';
  my $object  = $self->object;
  my $image_width  = $self->image_width || 800;  
  my $context      = $object->param( 'context' ) || 100; 
  my $extent       = $context eq 'FULL' ? 1000 : $context;
  my $hub          = $self->hub;
  my $v            = $hub->param('v') || undef;

  my $region = $hub->param('r');
  my ($reg_name, $start, $end) = $region =~ /(.+?):(\d+)-(\d+)/ if $region =~ /:/;

  my $slice = $object->database('core')->get_SliceAdaptor->fetch_by_region(
      $object->seq_region_type, $reg_name, $start, $end, 1);

  # Padding-----------------------------------------------------------
  # Get 4 configs - and set width to width of context config
  # Get two slice -  gene (4/3x) transcripts (+-EXTENT)
  my $Configs;
  my @confs = qw(gene transcripts_top transcripts_bottom);
  push @confs, 'snps' unless $no_snps;  

  foreach( @confs ){ 
    $Configs->{$_} = $hub->get_imageconfig($_ eq 'gene' ? $ic_type : 'GeneSNPView', $_);
    $Configs->{$_}->set_parameters({ 'image_width' => $image_width, 'context' => $context });
  }

  my $get_munged_slices = $object->get_munged_slice2( 1, $slice);
  my $sub_slices       =  $get_munged_slices->[2]; 


  # Fake SNPs -----------------------------------------------------------
  # Grab the SNPs and map them to subslice co-ordinate
  # $snps contains an array of array each sub-array contains [fake_start, fake_end, B:E:Variation object] # Stores in $object->__data->{'SNPS'}

  my ($count_snps, $snps, $context_count) = $object->getVariationsOnSlice( $slice, $sub_slices  );
  my $start_difference =  0; 

  my @fake_filtered_snps;
  map { push @fake_filtered_snps,
     [ $_->[2]->start + $start_difference,
       $_->[2]->end   + $start_difference,
       $_->[2]] } @$snps;

  $Configs->{'gene'}->{'filtered_fake_snps'} = \@fake_filtered_snps unless $no_snps;


  # Make fake transcripts ----------------------------------------------
  $object->store_TransformedTranscripts($start);        ## Stores in $transcript_object->__data->{'transformed'}{'exons'|'coding_start'|'coding_end'}

  my @domain_logic_names = qw(Pfam scanprosite Prints pfscan PrositePatterns PrositeProfiles Tigrfam Superfamily Smart PIRSF);
  foreach( @domain_logic_names ) { 
    $object->store_TransformedDomains($_, $start);              ## Stores in $transcript_object->__data->{'transformed'}{'Pfam_hits'}
  }
  $object->store_TransformedSNPS() unless $no_snps;      ## Stores in $transcript_object->__data->{'transformed'}{'snps'}

  ### This is where we do the configuration of containers....
  my @transcripts            = ();
  my @containers_and_configs = (); ## array of containers and configs

## sort so trancsripts are displayed in same order as in transcript selector table  
  my $strand = $object->Obj->strand;
  my @trans = @{$object->get_all_transcripts};
  my @sorted_trans;
  if ($strand ==1 ){
    @sorted_trans = sort { $b->Obj->external_name cmp $a->Obj->external_name || $b->Obj->stable_id cmp $a->Obj->stable_id } @trans;
  } else {
    @sorted_trans = sort { $a->Obj->external_name cmp $b->Obj->external_name || $a->Obj->stable_id cmp $b->Obj->stable_id } @trans;
  } 

  foreach my $trans_obj (@sorted_trans ) {  
      my $tid = $trans_obj->stable_id;
      my $opt = "opt_ht_".lc($tid);
      warn "T: $tid * ", $hub->param($opt), " * ", $object->param($opt), "\n";

      if (my $opt_value = $hub->param($opt)) {
	       next if ($opt_value eq 'on');
      }
## create config and store information on it...
    $trans_obj->__data->{'transformed'}{'extent'} = $extent;
    my $CONFIG = $hub->get_imageconfig( "${ic_type}", $trans_obj->stable_id );
    $CONFIG->init_transcript;
    $CONFIG->{'geneid'}     = $object->stable_id;
    $CONFIG->{'snps'}       = $snps unless $no_snps;
    $CONFIG->{'subslices'}  = $sub_slices;
    $CONFIG->{'extent'}     = $extent;
    $CONFIG->{'var_image'}   = 1;
    $CONFIG->{'_add_labels'} = 1;
      ## Store transcript information on config....
    my $TS = $trans_obj->__data->{'transformed'};
#        warn Data::Dumper::Dumper($TS);
    $CONFIG->{'transcript'} = {
      'exons'        => $TS->{'exons'},
      'coding_start' => $TS->{'coding_start'},
      'coding_end'   => $TS->{'coding_end'},
      'transcript'   => $trans_obj->Obj,
      'gene'         => $object->Obj,
      $no_snps ? (): ('snps' => $TS->{'snps'})
    }; 
    
    $CONFIG->modify_configs( ## Turn on track associated with this db/logic name
      [$CONFIG->get_track_key( 'gsv_transcript', $object )],
			     {'display' => 'normal', 'show_labels' =>  'off',
			      'caption' => '',
			      'tid' => $tid,  
			      'altname' => $trans_obj->Obj->external_name,
			      'component' => 'GeneSNPImage'
			      }  ## also turn off the transcript labels...
    );

    foreach ( @domain_logic_names ) { 
      $CONFIG->{'transcript'}{lc($_).'_hits'} = $TS->{lc($_).'_hits'};
    }  

###   # $CONFIG->container_width( $object->__data->{'slices'}{'transcripts'}[3] ); 

    $CONFIG->set_parameters({'container_width' => $slice->length   });
    $CONFIG->tree->dump("Transcript configuration", '([[caption]])')
    if $object->species_defs->ENSEMBL_DEBUG_FLAGS & $object->species_defs->ENSEMBL_DEBUG_TREE_DUMPS;

   if( $object->seq_region_strand < 0 ) {
      #push @containers_and_configs, $transcript_slice, $CONFIG;
       push @containers_and_configs, $slice, $CONFIG;
    } else {
      ## If forward strand we have to draw these in reverse order (as forced on -ve strand)
      #unshift @containers_and_configs, $transcript_slice, $CONFIG;
      unshift @containers_and_configs, $slice, $CONFIG;  
    }
    push @transcripts, { 'exons' => $TS->{'exons'} };
  }

## -- Map SNPs for the last SNP display --------------------------------- ##
  my $SNP_REL     = 5; ## relative length of snp to gap in bottom display...
  my $fake_length = -1; ## end of last drawn snp on bottom display...
  my $slice_trans = $transcript_slice;

## map snps to fake evenly spaced co-ordinates...
  my @snps2;
  unless( $no_snps ) {
    @snps2 = map {
      $fake_length+=$SNP_REL+1;
      [ $fake_length-$SNP_REL+1 ,$fake_length,$_->[2], $slice->seq_region_name,
        $slice->strand > 0 ?
          ( $slice->start + $_->[2]->start - 1,
            $slice->start + $_->[2]->end   - 1 ) :
          ( $slice->end - $_->[2]->end     + 1,
            $slice->end - $_->[2]->start   + 1 )
      ]
    } sort { $a->[0] <=> $b->[0] } @{ $snps };
## Cache data so that it can be retrieved later...
    #$object->__data->{'gene_snps'} = \@snps2; fc1 - don't think is used
    foreach my $trans_obj ( @{$object->get_all_transcripts} ) {
      $trans_obj->__data->{'transformed'}{'gene_snps'} = \@snps2;
    }
  }

## -- Tweak the configurations for the five sub images ------------------ ##
## Gene context block;
  my $gene_stable_id = $object->stable_id;

## Transcript block
  $Configs->{'gene'}->{'geneid'}      = $gene_stable_id; 
  $Configs->{'gene'}->set_parameters({ 'container_width' => $slice->length });

  $Configs->{'gene'}->modify_configs( ## Turn on track associated with this db/logic name
    [$Configs->{'gene'}->get_track_key( 'transcript', $object )],
    {'display'=> 'off', 'menu' => 'no'}   #turn off transcript track - it is already displayed in the GeneSNPImageTop  
  );
 
## Intronless transcript top and bottom (to draw snps, ruler and exon backgrounds)
  foreach(qw(transcripts_top transcripts_bottom)) {
    $Configs->{$_}->{'extent'}      = $extent;
    $Configs->{$_}->{'geneid'}      = $gene_stable_id;
    $Configs->{$_}->{'transcripts'} = \@transcripts;
    $Configs->{$_}->{'snps'}        = $object->__data->{'SNPS'} unless $no_snps;
    $Configs->{$_}->{'subslices'}   = $sub_slices;
    $Configs->{$_}->{'fakeslice'}   = 1;
    $Configs->{$_}->set_parameters({ 'container_width' => $slice->length });
  }
  $Configs->{'transcripts_bottom'}->get_node('spacer')->set('display','off') if $no_snps;
## SNP box track...
  unless( $no_snps ) {
    $Configs->{'snps'}->{'fakeslice'}   = 1;
    $Configs->{'snps'}->{'snps'}        = \@snps2; 
    $Configs->{'snps'}->set_parameters({ 'container_width' => $fake_length });  #???
    $Configs->{'snps'}->{'snp_counts'} = [$count_snps, scalar @$snps, $context_count];
  } 

## -- Render image ------------------------------------------------------ ##
  my $image    = $self->new_image([
    $slice, $Configs->{'gene'},
    $slice, $Configs->{'transcripts_top'}, 
    @containers_and_configs,
    $slice, $Configs->{'transcripts_bottom'},  
    $no_snps ? ():
    ($slice, $Configs->{'snps'})
  ],
  [ $object->stable_id, $v]
  );
  return if $self->_export_image($image, 'no_text');

  $image->imagemap = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button( 'drag', 'title' => 'Drag to select region' );

  my $html = $image->render; 
  if ($no_snps){
    $html .= $self->_info(
      'Configuring the display',
      "<p>Tip: use the '<strong>Configure this page</strong>' link on the left to customise the protein domains  displayed above.</p>"
    );
    return $html;
  }
  my $info_text = config_info($Configs->{'snps'});
  $html .= $self->_info(
    'Configuring the display',
    "<p>Tip: use the '<strong>Configure this page</strong>' link on the left to customise the protein domains and types of variations displayed above.<br />Please note the default 'Context' settings will probably filter out some intronic SNPs.<br />" .$info_text.'</p>'
 );

  return $html;
}

1;

