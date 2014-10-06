# $Id: ViewConfig.pm,v 1.1 2012-12-10 16:25:18 ek3 Exp $

package EnsEMBL::Web::ViewConfig;

use strict;

use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities);
use JSON qw(from_json);
use URI::Escape qw(uri_unescape);

# Loop through the parameters and update the config based on the parameters passed
sub update_from_input {
  my $self         = shift;
  my $hub          = $self->hub;
  my $input        = $hub->input;
  my $image_config = $hub->get_imageconfig($self->image_config) if $self->image_config;
  
  return $self->reset($image_config) if $input->param('reset');
  
  my $diff = $input->param('view_config');
  my $flag = 0;
  my $altered;
  
  if ($diff) {
    $diff = from_json($diff);
#1kg    
#    foreach my $key (grep exists $self->{'options'}{$_}, keys %$diff) {
    foreach my $key (grep {exists $self->{'options'}{$_} || $_ =~ /^opt_ht/} keys %$diff) {
#1kg
      my @values  = ref $diff->{$key} eq 'ARRAY' ? @{$diff->{$key}} : ($diff->{$key});
      my $current = ref $self->{'options'}{$key}{'user'} eq 'ARRAY' ? join '', @{$self->{'options'}{$key}{'user'}} : $self->{'options'}{$key}{'user'};
      my $new     = join('', @values);
      
      if ($new ne $current) {
        $flag = 1;
        
        if (scalar @values > 1) {
          $self->set($key, \@values);
        } else {
          $self->set($key, $values[0]);
        }
        
        $altered ||= $key if $new !~ /^(off|no)$/;
      }
    }
  }
  
  $self->altered = $image_config->update_from_input if $image_config;
  $self->altered = $altered || 1 if $flag;
  
  return $self->altered;
}

# Loop through the parameters and update the config based on the parameters passed
sub update_from_url {
  my ($self, $r, $delete_params) = @_;
  my $hub          = $self->hub;
  my $session      = $hub->session;
  my $input        = $hub->input;
  my $species      = $hub->species;
  my $config       = $input->param('config');
  my @das          = $input->param('das');
  my $image_config = $self->image_config;
  my $params_removed;
  
  if ($config) {
    foreach my $v (split /,/, $config) {
      my ($k, $t) = split /=/, $v, 2;
      
      if ($k =~ /^(cookie|image)_width$/ && $t != $ENV{'ENSEMBL_IMAGE_WIDTH'}) {
        # Set width
        $hub->set_cookie('ENSEMBL_WIDTH', $t);
        $self->altered = 1;
      }
#1kg
      my $force = ($k =~ /^opt_ht_/) ? 1 : 0;
#     warn "Set $k to $t\n";
      $self->set($k, $t, $force);  
#/1kg
    }
    
    if ($self->altered) {
      $session->add_data(
        type     => 'message',
        function => '_info',
        code     => 'configuration',
        message  => 'Your configuration has changed for this page',
      );
    }
    
    if ($delete_params) {
      $params_removed = 1;
      $input->delete('config');
    }
  }
  
  if (scalar @das) {
    my $action = $hub->action;
    
    $hub->action = 'ExternalData'; # Change action so that the source will be added to the ExternalData view config
    
    foreach (@das) {
      my $source     = uri_unescape($_);
      my $logic_name = $session->add_das_from_string($source);
      
      if ($logic_name) {
        $session->add_data(
          type     => 'message',
          function => '_info',
          code     => 'das:' . md5_hex($source),
          message  => sprintf('You have attached a DAS source with DSN: %s%s.', encode_entities($source), $self->get($logic_name) ? ', and it has been added to the External Data menu' : '')
        );
      }
    }
    
    $hub->action = $action; # Reset the action
    
    if ($delete_params) {
      $input->delete('das');
      $params_removed = 1;
    }
  }
  
  my @values = split /,/, $input->param($image_config);
  
  $hub->get_imageconfig($image_config)->update_from_url(@values) if @values;
  
  $session->store;
  
  if (@values) {
    $input->delete($image_config, 'format', 'menu'); 
    $params_removed = 1;
  }
  
  if ($delete_params && $input->param('toggle_tracks')) {
    $input->delete('toggle_tracks');
    $params_removed = 1;
  }
  
  return $params_removed;
}


1;
