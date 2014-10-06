# $Id: SpreadSheet.pm,v 1.1 2012-12-10 16:25:19 ek3 Exp $

package EnsEMBL::Web::Document::SpreadSheet;

sub _process {
  my $self = shift;

  my $counter = 0;
  my $data    = $self->{'_data'}    || [];
  my $columns = $self->{'_columns'} || [];
  my $options = $self->{'_options'} || {};

  my $no_cols = @$columns;
  
  # Start the table...
  my $return = [];
  
  foreach (0..($no_cols-1)) {
    my $col = $columns->[$_];
    $col = $columns->[$_] = { key => $col } unless ref $col eq 'HASH';
    $counter++;
  }

  # Draw the header row unless the "header" options is set to "no"
  if ($options->{'header'} ne 'no') {
    $counter = 0;
    my $border;
    my $row = { style => 'header', cols => [] };
    my $average = int(100 / scalar $columns);
    
    foreach (@$columns) {
      push @{$row->{'cols'}}, {
        style => 'text-align:' . ($options->{'alignheader'} || $_->{'align'} || 'auto') . ';width:' . ($_->{'width'} || $average . '%') . ($_->{'nowrap'} || ''), 
        value => defined $_->{'title'} ? $_->{'title'} : $_->{'key'}, 
        class => $_->{'class'} . ($_->{'sort'} ? " sort_$_->{'sort'}" : '')
      };
    }
    
    push @$return, $row;
  }

  # Display each row in the table
  my $row_count    = 0;  
  my @previous_row = ();
  my @totals       = ();
  my $row_colours  = $options->{'data_table'} ? [] : exists $options->{'rows'} ? $options->{'rows'} : [ 'bg1', 'bg2' ];

  foreach my $row (@$data) {
    my $flag       = 0;
    my $class = ref $row eq 'HASH' ? $row->{'class'} : {};
    my $out_row    = { style => 'row', class => join(' ', $row_colours->[0], $class), col => [] }; 
    $counter       = 0;
    
    foreach my $col (@$columns) {
      my $value        = $self->get_value($row, $counter, $col->{'key'});
      my $hidden_value = lc (exists $col->{'hidden_key'} ? $self->get_value($row, $counter, $col->{'hidden_key'}) : $value);
      my $style        = exists $col->{'align'} ? "text-align:$col->{'align'};" : ($col->{'type'} eq 'numeric' ? 'text-align:right;' : '');
      $style          .= exists $col->{'width'} ? "width:$col->{'width'};" : '';
      $style          .= exists $options->{'row_style'} && $options->{'row_style'}->[$row_count] ? $options->{'row_style'}->[$row_count]->[$counter] : '';
      
      if ($flag == $counter && $hidden_value eq $previous_row[$counter]) {
        $flag  = $counter + 1;
        $value = '' if $options->{'triangular'};
      }
      
      $previous_row[$counter] = $hidden_value;
      
      my $val = $value;
      my $f   = $col->{'format'};
      
      if ($value ne '' && $f) {
        if (ref $f eq 'CODE') {
          $val = $f->($value, $row);
        } elsif ($self->can($f)) {
          $val = $self->$f($value, $row);
        }
      }
      
      push @{$out_row->{'cols'}}, { 
        value => $val,
        style => $style
      };
      
      $counter++;
    }
    
    next if ($flag == $counter) && ($options->{'no_skip'} ne '1'); # SKIP WHOLLY BLANK LINES
    
    push @$row_colours, shift @$row_colours;

    $row_count++;
    
    if ($options->{'total'} > 0) { # SUMMARY TOTALS
      if ($flag < $options->{'total'}) {
        for (my $i = $options->{'total'} - 1; $i > $flag; $i--) {
          next unless @totals;
          
          my $TOTAL_ROW = pop @totals;
          my $total_row = { style => 'total', cols => [] };
          my $counter   = 0;
          
          foreach my $col (@$columns) {
            my $value = '';
            my $style = '';
            
            if ($counter == @totals) {
              $value = 'TOTAL';
            } elsif ($counter > @totals && $col->{'type'} eq 'numeric') {
              $style = 'text-align:right';
              $value = $self->thousandify($TOTAL_ROW->[$counter]);
            }
            
            push @{$total_row->{'cols'}}, { value => $value, style => $style };
            
            $counter++;
          }
          
          push @$return, $total_row;
        }
      }
      
      my $counter = 0;
      
      foreach my $col (@$columns) {
        if ($col->{'type'} eq 'numeric') {
          my $value = $self->get_value($row, $counter, $col->{'key'});
            
          for (my $i = 0; $i < $options->{'total'}; $i++) {
            $totals[$i][$counter] += $value;
          }
        }
        
        $counter++;
      }
    }
    
    push @$return, $out_row;
  }
  
  if ($options->{'total'} > 0) { # SUMMARY TOTALS
    while (@totals) {
      my $TOTAL_ROW = pop @totals;
      my $total_row = { style => 'total', cols => [] };
      my $counter   = 0;
      
      foreach my $col (@$columns) {
        my $value = '';
        my $style = '';
        
        if ($counter == @totals) {
          $value = 'TOTAL';
        } elsif ($counter > @totals && $col->{'type'} eq 'numeric') {
          $value = $self->thousandify($TOTAL_ROW->[$counter]);
          $style = 'text-align:right';
        }
        
        push @{$total_row->{'cols'}}, { value => $value, style => $style };
        
        $counter++;
      }
      
      push @$return, $total_row;
    }
  }
  
  return $return;
}
   
1;
