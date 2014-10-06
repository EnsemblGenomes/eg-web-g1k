package EnsEMBL::Web::Configuration::Variation;

use strict;

sub modify_tree {
  my $self  = shift;

## Don't need the item in release 13 - all data come from the DB
  return;

  my $ind = $self->get_node('Individual');
  $ind->set('caption', 'Ensembl ([[counts::individuals]])');
  
  my $menu = $self->create_submenu( 'Genotypes', 'Individual genotypes' );
  
  my $somatic = $self->object ? $self->object->Obj->is_somatic : undef;
  
  $menu->append ( $ind ); 
  
  $menu->append ( $self->create_node('Individual_g1k', '1000Genomes ([[counts::individuals1kg]])',
    [qw( summary EnsEMBL::Web::Component::Variation::IndividualGenotypesG1K )],
    { 'availability' => 'variation has_individuals1kg not_somatic', 'concise' => 'Individual genotypes', 'no_menu_entry' => $somatic }
  )); 
  
  my $node = $self->get_node('Populations');  
  $node->after($menu);
  
    
}

1;
