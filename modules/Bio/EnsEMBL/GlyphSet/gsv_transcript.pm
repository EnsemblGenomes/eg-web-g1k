package Bio::EnsEMBL::GlyphSet::gsv_transcript;

sub init_label_off {
    my $self = shift;
  
    my $tid = $self->my_config('tid');
    return $self->label(undef) unless $tid;

    my $text = $tid;
    my $length  = $self->{'container'}->length;
    my $obj = $self->{'container'};
    my $config    = $self->{'config'};
    my $hub       = $config->hub;
    my $desc      = $tid . ",  ". $self->my_config('altname');
    my $style     = $config->species_defs->ENSEMBL_STYLE;
    my $font      = $style->{'GRAPHIC_FONT'};
    my $fsze      = $style->{'GRAPHIC_FONTSIZE'} * $style->{'GRAPHIC_LABEL'};
    my @res       = $self->get_text_width(0, $text, '', 'font' => $font, 'ptsize' => $fsze);
    my $track     = $self->_type;
    my $node      = $config->get_node($track);
    my $component = $config->get_parameter('component');
    
    my $hover     = $component && !$hub->param('export') && $node->get('menu') ne 'no';
    (my $class    = $self->species . "_$track") =~ s/\W/_/g;
    
    my $turl = $hub->url( {
	species  => $config->species,
	action   => 'Variation_Gene',
	function => 'Image',
    });

   

    $component = 'GeneSNPView';
    my $opt = "opt_ht_".lc($tid);
    $config->{'hover_labels'}->{$class} = {
	header    => $text,
	desc      => $desc,
	class     => $class,
	'on-off' => 1,
	off       => "$turl;config=$opt=on;$component=$opt=on",
    };


    my $trans_ref    = $config->{'transcript'};
    my $gene         = $trans_ref->{'gene'};
    my $transcript   = $trans_ref->{'transcript'};
    my $colour       = $self->my_colour($self->transcript_key( $transcript, $gene ));
    
    warn "COL : $colour \n";
        
    $self->label($self->Text({
	text      => $text,
	font      => $font,
	ptsize    => $fsze,
	colour    => $colour || $self->{'label_colour'} || 'black',
	absolutey => 1,
	height    => $res[3],
	class     => "label $class",
	alt       => $desc,
	hover     => 1
    })
		 );
}

sub _init {
  my ($self) = @_; 
  my $type = $self->check(); 

  return unless defined $type;
  return unless $self->strand() == -1;

  my $offset = $self->{'container'}->start - 1;
  my $Config        = $self->{'config'}; 

  my @transcripts   = $Config->{'transcripts'}; 
  my $y             = 0;
  my $h             = 8;   #Single transcript mode - set height to 30 - width to 8!
    
  my %highlights; 
  @highlights{$self->highlights} = ();    # build hashkeys of highlight list

  my $pix_per_bp    = $Config->transform->{'scalex'};
  my $bitmap_length = $Config->image_width();   #int($Config->container_width() * $pix_per_bp);

  my $length  = $Config->container_width();
  my $transcript_drawn = 0;

  my $voffset      = 0;
  my $trans_ref    = $Config->{'transcript'};
  my $gene         = $trans_ref->{'gene'};
  my $transcript   = $trans_ref->{'transcript'};
  my @exons        = sort {$a->[0] <=> $b->[0]} @{$trans_ref->{'exons'}};

  # For exon_structure diagram only given transcript
  my $Composite    = $self->Composite({'y'=>0,'height'=>$h});

  my $colour       = $self->my_colour($self->transcript_key( $transcript, $gene ));
  my $coding_start = $trans_ref->{'coding_start'};
  my $coding_end   = $trans_ref->{'coding_end'  };

  my( $fontname, $fontsize ) = $self->get_font_details( 'caption' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );

  my $th = $res[3];

  ## First of all draw the lines behind the exons..... 
  my $Y = $Config->{'_add_labels'} ? $th : 0;  

  unless ($Config->{'var_image'} == 1) {
    foreach my $subslice (@{$Config->{'subslices'}}) {
      $self->push( $self->Rect({
        'x' => $subslice->[0]+$subslice->[2]-1, 'y' => $Y+$h/2, 'h'=>1, 'width'=>$subslice->[1]-$subslice->[0], 'colour'=>$colour, 'absolutey'=>1
      }));
    }
  }  

  ## Now draw the exons themselves....
  my $drawn_exon = 0;
  foreach my $exon (@exons) { 
    next unless defined $exon;  #Skip this exon if it is not defined (can happen w/ genscans) 
      # We are finished if this exon starts outside the slice
    my($box_start, $box_end);
      # only draw this exon if is inside the slice

    if ($exon->[0] < 0 && $transcript->slice->is_circular) {  # Features overlapping chromosome origin
        $exon->[0] += $transcript->slice->seq_region_length;
        $exon->[1] += $transcript->slice->seq_region_length;
        $coding_start += $transcript->slice->seq_region_length;
        $coding_end += $transcript->slice->seq_region_length;
    }

    $box_start = $exon->[0];
    $box_start = 1 if $box_start < 1 ;
    $box_end   = $exon->[1];
    $box_end = $length if$box_end > $length;
    # Calculate and draw the coding region of the exon
    if ($coding_start && $coding_end) {
      my $filled_start = $box_start < $coding_start ? $coding_start : $box_start;
      my $filled_end   = $box_end > $coding_end  ? $coding_end   : $box_end;
       # only draw the coding region if there is such a region
       if( $filled_start <= $filled_end ) {

	   my $x     = $filled_start -1;
	   my $width = $filled_end - $filled_start + 1;

	   if (($x >= 0) && ($width >= 0)) {
	       $width = ($x + $width) > $length ? $length-$x : $width;
	   } elsif ( ($x <= 0) && (($x + $width) > 0) ) {
	       $width = ($x + $width) > $length ? $length : ($x + $width);
	       $x = 0;
	   }

	   if ($width > 0 ) {
             #Draw a filled rectangle in the coding region of the exon
             $self->push( $self->Rect({
             'x' =>         $x,     #$filled_start -1,
             'y'         => $Y,
             'width'     => $width, #$filled_end - $filled_start + 1,
             'height'    => $h,
             'colour'    => $colour,
             'absolutey' => 1,
             'href'     => $self->href( $transcript, $exon->[2] ),
             }));
	   } #if
      }
    }
     if($box_start < $coding_start || $box_end > $coding_end ) {
      # The start of the transcript is before the start of the coding
      # region OR the end of the transcript is after the end of the
      # coding regions.  Non coding portions of exons, are drawn as
      # non-filled rectangles

      my $x     = $box_start - 1;
      my $width = $box_end-$box_start  + 1;

      if (($x >= 0) && ($width >= 0)) {
        $width = ($x + $width) > $length ? $length-$x : $width;
      } elsif ( ($x <= 0) && (($x + $width) > 0) ) {
	$width = ($x + $width) > $length ? $length : ($x + $width);
	$x = 0;
      }

      if ($width > 0 ) {
        #Draw a non-filled rectangle around the entire exon
        my $G = $self->Rect({
        'x'         => $x,      #$box_start -1 ,
        'y'         => $Y,
        'width'     => $width,  #$box_end-$box_start +1,
        'height'    => $h,
        'bordercolour' => $colour,
        'absolutey' => 1,
        'title'     => $exon->[2]->stable_id,
        'href'     => $self->href( $transcript, $exon->[2] ),
        });
        $self->push( $G );
      } #if
     } 
  } #we are finished if there is no other exon defined


  if ($Config->{'var_image'} == 1) {      ## Drawing the lines behind the exons for Gene/Variation image  

      my @l_exons = sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } @exons;
    my $start_ex = @l_exons->[0];
    my $end_ex   = @l_exons->[$#l_exons];
    my $S = $start_ex->[0];
    my $E = $end_ex->[1];

    # In Gene/Variation image page it doesn't show the track unless there is a part of the trancript to be displayed
    return if ($E<1 || $S>$length) && ($Config->{'var_image'} == 1);
    $S = 1 if $S < 1;
    $E = $length if $E > $length;
    my $tglyph = $self->Rect({
      'x' => $S-1,
      'y' => $Y+$h/2, 
      'h'=>1,
      'width'  => $E-$S+1,
      'colour' => $colour,
      'absolutey'=>1
    });
    $self->push($tglyph);
  }

  if( $Config->{'_add_labels'} ) {   
      my $name =  ' '.$transcript->external_name;
      my $H = 0;

      my $hub       = $Config->hub;
      my $turl = $hub->url( {
	     species  => $Config->species,
	     action   => 'Variation_Gene',
	     function => 'Image',
	     submit   => 1,      
      });
      
      my $opt = "opt_ht_".lc($transcript->stable_id);
      my $component = 'GeneSNPView';
      my $href = "$turl;config=$opt=on;$component=$opt=on";

      $zmenu = {
	       'caption'         => $transcript->stable_id,
	       "10:Hide the transcript" => $href
	     };

      my $whmax = 0;
      
      foreach my $text_label ( $transcript->stable_id, $name ) {
	       next unless $text_label;
	       next if $text_label eq ' ';
	  
	       my @res2       = $self->get_text_width(0, $text_label, '', 'font' => $fontname, 'ptsize' => $fontsize);
	       my $tglyph = $self->Text({
	         'x'         => -104,
	         'y'         => $H + 10,
	         'height'    => $th,
	         textwidth => $res2[2],
	         width     => $res[2] / $pix_per_bp,       
	         'font'      => $fontname,
	         'ptsize'    => $fontsize,
	         'halign'    => 'left',
	         'colour'    => $colour,
	         'text'      => $text_label,
	         'absolutey' => 1,
	         'absolutex' => 1,
#	         'href' => $href,
#	         'title' => 'Hide the transcript'
#	      'zmenu' => $zmenu
	       });

	       $self->push($tglyph);

	       $H += $th + 1;
	  
	  
	       my $wh     = ($res2[2]  + 2) / $pix_per_bp;
	       if ($wh > $whmax) {
	         $whmax = $wh;
	       }

   #      warn "$text_label: ", join ' * ', @res2, "###", $wh, $whmax, "\n";
	    
	       my $h_line = $self->Line({
		        'x'         => -105,
		        'y'         => $H + 10,
		        'width'     => $wh,
		        'height'    => 1,
		        'colour'    => $colour,
		        'absolutey' => 1,
		        'absolutex' => 1,
		        'dotted' => 1, 
	       });
	       
	       $self->push( $h_line );
      }
	  
	    my $G = $self->Rect({
	      'x'         => -106, 
	      'y'         => 10,
	      'width'     => $whmax, 
	      'height'    => $H+2,
#	      'bordercolour' => 'blue',
	      'absolutey' => 1,
	      'absolutex' => 1,
	      'title'     => "Hide the transcript", 
	      'href'     => $href,
	   });
	   $self->push( $G );      
  }
}

1;
