package EnsEMBL::Web::Configuration::Info;

use strict;

# 1kg caption() from core webcode to override eg-plugins/common
sub caption { 
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $species      = $hub->species;
  my $path         = $hub->species_path;
  my $sound        = $species_defs->SAMPLE_DATA->{'ENSEMBL_SOUND'};
  my ($heading, $subhead);

  $heading .= qq(<a href="$path"><img src="/i/species/48/$species.png" class="species-img float-left" alt="" title="$sound" /></a>);
  my $common_name = $species_defs->SPECIES_COMMON_NAME;
  if ($common_name =~ /\./) {
    $heading .= $species_defs->SPECIES_BIO_NAME;
  }
  else {
    $heading .= $common_name;
    $subhead = '('.$species_defs->SPECIES_BIO_NAME.')';
  }
  return [$heading, $subhead];
}

sub modify_tree {
  my $self  = shift;

  $self->delete_node('IPtop40');
  $self->delete_node('IPtop500');
  $self->delete_node('WhatsNew');

#1kg put HomePage back, to override eg-plugins/common
  my $node = $self->get_node('Index');
  $node->set('components',[qw(
    homepage EnsEMBL::Web::Component::Info::HomePage
  )],);
}

1;
