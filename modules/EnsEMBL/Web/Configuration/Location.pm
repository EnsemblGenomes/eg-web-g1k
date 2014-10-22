package EnsEMBL::Web::Configuration::Location;

use strict;
sub modify_tree {
    my $self = shift;
    
    $self->delete_node('Compara');
    $self->delete_node('OtherBrowsers');
}

1;
