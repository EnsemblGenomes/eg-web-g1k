package EnsEMBL::Web::Configuration::Gene;

sub modify_tree {
  my $self = shift;

  $self->delete_node('Compara');
  my $hub = $self->hub;

  return unless ($self->object || $hub->param('g'));

  my $species = $hub->species;

  my $gene_adaptor = $hub->get_adaptor('get_GeneAdaptor', 'core', $species);
  my $gene   = $self->object ? $self->object->gene : $gene_adaptor->fetch_by_stable_id($hub->param('g'));  

  my @transcripts  = sort { $a->start <=> $b->start } @{ $gene->get_all_Transcripts || [] };
  my $transcript   = @transcripts > 0 ? $transcripts[0] : undef;

  my $region = $hub->param('r');
  my ($reg_name, $start, $end) = $region =~ /(.+?):(\d+)-(\d+)/ ? $region =~ /(.+?):(\d+)-(\d+)/ : (undef, undef, undef);

  if ($transcript) {

    my @exons        = sort {$a->start <=> $b->start} @{ $transcript->get_all_Exons || [] };
    if (@exons > 0) {
      if (defined( $transcript->coding_region_start ) && defined( $transcript->coding_region_end) ) {
        foreach my $e (@exons) {
	  next if $e->start <= $transcript->coding_region_start && $e->end <= $transcript->coding_region_start;
          $start = $e->start <= $transcript->coding_region_start ? $transcript->coding_region_start : $e->start;
          $end   = $e->end   >= $transcript->coding_region_end   ? $transcript->coding_region_end   : $e->end;
          last;
        }
      } else {
        my $exon = $exons[0];
        ($start, $end) = ($exon->start, $exon->end); 
      }
    }

  }

  my $var_menu     = $self->get_node('Variation');

  my $r   = ($reg_name && $start && $end) ? $reg_name.':'.$start.'-'.$end : $gene->seq_region_name.':'.$gene->start.'-'.$gene->end;
  my $url = $hub->url({
                  type   => 'Gene',
                  action => 'Variation_Gene/Image',
                  g      => $hub->param('g') || $gene->stable_id,
                  r      => $r
                });

  my $variation_image = $self->get_node('Variation_Gene/Image');
  $variation_image->set('components', [qw(
    imagetop EnsEMBL::Web::Component::Gene::VariationImageTop
    imagenav EnsEMBL::Web::Component::Gene::VariationImageNav
    image EnsEMBL::Web::Component::Gene::VariationImage )
				       ]);
  $variation_image->set('availability', 'gene database:variation not_patch');
  $variation_image->set('url' =>  $url);

  $var_menu->append($variation_image);

}

1;
