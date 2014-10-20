package EnsEMBL::Web::Configuration::Location;

use strict;
sub modify_tree {
    my $self = shift;
    
    $self->delete_node('Compara');
    $self->delete_node('OtherBrowsers');
    $self->delete_node('SequenceAlignment'); # the view does not seem to work at all , even at grch37.ensembl.org
}

1;
