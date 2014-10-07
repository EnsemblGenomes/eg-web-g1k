# $Id: ToolButtons.pm,v 1.1.18.1 2014-09-12 09:39:14 jk10 Exp $

package EnsEMBL::Web::Document::Element::ToolButtons;

sub label_classes {
  return {
    'Configure this page' => 'config',
    'Manage your data'    => 'data',
    'Add your data'       => 'data',
    'Export data'         => 'export',
    'Bookmark this page'  => 'bookmark',
    'Share this page'     => 'share',
    'Get VCF data'        => 'data'
  };
}

sub init {
  my $self       = shift;  
  my $controller = shift;
  my $hub        = $controller->hub;
  my $object     = $controller->object;
  my @components = @{$hub->components};
  my $session    = $hub->session;
  my $user       = $hub->user;
  my $has_data   = grep($session->get_data(type => $_), qw (upload url das)) || ($user && (grep $user->get_records($_), qw(uploads urls dases)));
  my $view_config;
     $view_config = $hub->get_viewconfig(@{shift @components}) while !$view_config && scalar @components; 
  
  if ($view_config) {
    my $component = $view_config->component;
    
    $self->add_entry({
      caption => 'Configure this page',
      class   => 'modal_link',
      rel     => "modal_config_$component",
      url     => $hub->url('Config', {
        type      => $view_config->type,
        action    => $component,
        function  => undef,
      })
    });
  } else {
    $self->add_entry({
      caption => 'Configure this page',
      class   => 'disabled',
      url     => undef,
      title   => 'There are no options for this page'
    });
  }
  
  $self->add_entry({
    caption => $has_data ? 'Manage your data' : 'Add your data',
    class   => 'modal_link',
    rel     => 'modal_user_data',
    url     => $hub->url({
      time    => time,
      type    => 'UserData',
      action  => $has_data ? 'ManageData' : 'SelectFile',
      __clear => 1
    })
  });
 
  if ($object && $object->can_export) {
    $self->add_entry({
      caption => 'Export data',
      class   => 'modal_link',
      url     => $self->export_url($hub)
    });
  } else {
    $self->add_entry({
      caption => 'Export data',
      class   => 'disabled',
      url     => undef,
      title   => 'You cannot export data from this page'
    });
  }

  #vcf BOF                                                                                                                                                                                                   
  if (($url !~ /Info\/Index/) && ($region =~ /^(.+?):(\d+)-(\d+)$/)) {
    $self->add_entry({
      caption => 'Get VCF data',
      class   => 'modal_link',
      url     => $hub->url({
        time   => time,
        type   => 'UserData',
        action => 'SelectSlice',
        defaults => 1
      })
    });
  } else {
      $self->add_entry({
      caption => 'Get VCF data',
      class   => 'disabled',
      url     => undef,
      title   => 'You cannot get VCF data from this page'
      });
  }
  #vcf EOF                                 
  
  if ($hub->user) {
    my $title = $controller->page->title;
    
    $self->add_entry({
      caption => 'Bookmark this page',
      class   => 'modal_link',
      url     => $hub->url({
        type        => 'Account',
        action      => 'Bookmark/Add',
        __clear     => 1,
        name        => uri_escape($title->get_short),
        description => uri_escape($title->get),
        url         => uri_escape($hub->species_defs->ENSEMBL_BASE_URL . $hub->url)
      })
    });
  } else {
    $self->add_entry({
      caption => 'Bookmark this page',
      class   => 'disabled',
      url     => undef,
      title   => 'You must be logged in to bookmark pages'
    });
  }
  
  $self->add_entry({
    caption => 'Share this page',
    url     => $hub->url('Share', {
      __clear => 1,
      create  => 1,
      time    => time
    })
  });
}


1;
