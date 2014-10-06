package EnsEMBL::Web::Component::Search::Results;

sub content {
  my $self = shift;
  my $hub = $self->hub;
  my $search = $self->object->Obj;
  my $html;

  my $chr_list = $hub->species_defs->ENSEMBL_CHROMOSOMES || [];
  if ($hub->species ne 'Multi' && $hub->param('q')) {
    $html = "<p><strong>You searched for \'" . $hub->param('q')  . "\'</strong</p>";

    # Eagle change to order the results differently
    # we can either order the results by our own @order_results array, the species.ini files ( @idxs ), or just by sorting by keys as below.  
    # ## Filter by configured indices

    # # These are the methods for the current species that we want to try and run
    # # The array is ordered in the way that they are listed in the .ini file
    # my @idxs = @{$hub->species_defs->ENSEMBL_SEARCH_IDXS};
  
    # the first value is the search method/species ini term. The second value is the display label.
    my @order_results = ( ['Gene', 'Gene or Gene Product' ], [ 'Marker', 'Genetic Marker'], [ 'OligoProbe', 'Array Probe Set' ], [ 'SNP', 'SNP'], [ 'SV', 'Structural Variation'], [ 'Domain', 'Interpro Domain'], [ 'Family', 'Gene Family'], ['GenomicAlignment', 'Sequence Aligned to Genome, eg. EST or Protein' ], [ 'Sequence', 'Genomic Region, eg. Clone or Contig' ], [ 'QTL', 'QTL' ],  ['PH', 'Phenotype'] ); 

    my %group_results;
    foreach my $search_ref ( @order_results ) {
      my $search_index = $search_ref->[0];
      if ( $search->{'results'}{$search_index} ) { 
        my( $results, $count ) = @{ $search->{'results'}{$search_index} };
        my $unique_res = {};
        my $res_html   = '';
        $count         = 0;  #it should count only the unique results

        foreach my $result ( @$results ) {
          # EG label features on patch contigs
          my $adaptor = $hub->database('core')->get_adaptor($result->{'subtype'});
          my $stable_id = $result->{'ID'};
          if($result->{'subtype'} =~ /^Variations in gene (.+)$/i){
            $adaptor = $hub->database('core')->get_adaptor('Gene');
            $stable_id=$1;
          }
            
          if($adaptor && $adaptor->can('fetch_by_stable_id')){
            if(my $ftr = $adaptor->fetch_by_stable_id($stable_id)){
              $result->{'chrom'} = $ftr->slice->seq_region_name;
              $result->{'start'} = $ftr->start;
              $result->{'end'} = $ftr->end;
              if(my ($patch_version) = @{$ftr->slice->get_all_Attributes('patch_fix')}){ # we might also check patch_novel and non_ref
                $result->{'subtype'} .= sprintf(" (from Patch %s)", $patch_version->value) unless ($result->{'subtype'} =~ /from Patch/);
                if(!exists $result->{'eg-sorted'}){
                  $result->{'eg-sorted'}=1;
                  push(@$results,$result);
                  next;
                }
              }
            }
          }
          $group_results{$search_index} = $results;
        } 
            # /EG
      }
    }

    foreach my $search_ref ( @order_results ) {
      my $search_index = $search_ref->[0];
      my $display_term = $search_ref->[1]; 
      my $sorted_results = $group_results{$search_index};
      my $unique_res = {};
      my $res_html   = '';
      $count         = 0;  #it should count only the unique results
      foreach my $result (@$sorted_results) {
        #to avoid duplications:
        next if exists $unique_res->{$result->{'subtype'}.$result->{'URL'}.$result->{'ID'}};
        $unique_res->{$result->{'subtype'}.$result->{'URL'}.$result->{'ID'}} = 1;
        $count++;

        $res_html .= sprintf(qq(<li><strong>%s:</strong> <a href="%s">%s</a>),
        $result->{'subtype'}, $result->{'URL'}, $result->{'ID'});

        if( $result->{'URL_extra'} ) {
          foreach my $E ( @{[$result->{'URL_extra'}]} ) {
            $res_html .= sprintf(qq( %s [<a href="%s" title="%s">%s:%s-%s</a>]),
              $E->[0], $E->[2], $E->[1], $result->{'chrom'}, $result->{'start'}, $result->{'end'});
          }
        }
        if( $result->{'desc'} ) {
          $res_html .= sprintf(qq(<br />%s), $result->{'desc'});
        }
        $res_html .= '</li>';
      } #foreach for groups
               
      if ($count>0){ 
        $html .= "<h3>$display_term</h3><p>$count entrie(s) matched your search strings.</p><ol>";
        $html .= $res_html;
        $html .= '</ol>';
      }
    }
  }
  else {
    if ($hub->species eq 'Multi') {
      $html .= '<p class="space-below">Simple text search cannot be executed on all species at once. Please select a species from the dropdown list below and try again.</p>';
    }
    elsif (!$hub->param('q')) {
      $html .= '<p class="space-below">No query terms were entered. Please try again.</p>';
    }
    my $search = EnsEMBL::Web::Document::HTML::HomeSearch->new($self->hub);
    $html .= $search->render
  }

  return $html;
}

1;
