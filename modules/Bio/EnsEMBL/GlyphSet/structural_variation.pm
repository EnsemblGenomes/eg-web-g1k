package Bio::EnsEMBL::GlyphSet::structural_variation;

sub tag {
  my ($self, $f) = @_;
  
  my $core_colour  = '#000000';
  my $bound_colour = '#AFAFAF';
  my $arrow_colour = $bound_colour;
  
  my @g_objects;
  
  my $inner_crossing = 0;
  
  my $outer_start = ($f->seq_region_start - $f->outer_start) - $f->start if (defined($f->outer_start));
  my $inner_start = ($f->inner_start - $f->seq_region_start) + $f->start if (defined($f->inner_start));
  my $inner_end   = $f->end - ($f->seq_region_end - $f->inner_end) if (defined($f->inner_end));
  my $outer_end   = $f->end + ($f->outer_end - $f->seq_region_end) if (defined($f->outer_end));
  
  my $core_start = $f->start;
  my $core_end   = $f->end;
  
  
  # Check if inner_start < inner_end
  if ($f->inner_start and $f->inner_end) {
    $inner_crossing = 1 if ($f->inner_start >= $f->inner_end);
  }

  ## START ##
  # outer & inner start
  if ($f->outer_start and $f->inner_start) {
    if ($f->outer_start != $f->inner_start && $inner_crossing == 0) {
      push @g_objects, {
        style  => 'rect',
        colour => $bound_colour,
        start  => $f->start,
        end    => $inner_start
      };
      $core_start = $inner_start;
    }
  }
  # Only outer start
  elsif ($f->outer_start) {
    if ($f->outer_start == $f->seq_region_start || $inner_crossing) {
      push @g_objects, {
        style  => 'bound_triangle_right',
        colour => $arrow_colour,
        start  => $f->start,
        out    => 1
      };
    }
  }
  # Only inner start
  elsif ($f->inner_start) {
    if ($f->inner_start == $f->seq_region_start && $inner_crossing == 0) {
      push @g_objects, {
        style  => 'bound_triangle_left',
        colour => $arrow_colour,
        start  => $f->start
      };
    }
  }
  
  ## END ##
  # outer & inner end
  if ($f->outer_end and $f->inner_end) {
    if ($f->outer_end != $f->inner_end && $inner_crossing == 0) {
      push @g_objects, {
        style  => 'rect',
        colour => $bound_colour,
        start  => $inner_end,
        end    => $f->end
      };
      $core_end = $inner_end;
    }
  }
  # Only outer end
  elsif ($f->outer_end) {
    if ($f->outer_end == $f->seq_region_end || $inner_crossing) {
      push @g_objects, {
        style  => 'bound_triangle_left',
        colour => $arrow_colour,
        start  => $f->end,
        out    => 1
      };
    }
  }
  # Only inner end
  elsif ($f->inner_end) {
    if ($f->inner_end == $f->seq_region_end && $inner_crossing == 0) {
      push @g_objects, {
        style  => 'bound_triangle_right',
        colour => $arrow_colour,
        start  => $f->end
      };
    }
  }
  

  # Central part of the structural variation
  unshift @g_objects, {
      style  => 'rect',
      # 1kg colour of structural variation tracks changed:
      colour => $self->my_colour($f->source),  # $core_colour
      # 1kg
      start  => $core_start,
      end    => $core_end
    };
  
  return @g_objects;
} 

1;
