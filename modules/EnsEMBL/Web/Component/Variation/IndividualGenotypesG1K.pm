package EnsEMBL::Web::Component::Variation::IndividualGenotypesG1K;

use strict;

use base qw(EnsEMBL::Web::Component::Variation::IndividualGenotypes);

## 1kg: overwrite the EG plugin

sub content {
  my $self = shift;
  return $self->SUPER::content('1000genomes');
}


1;
