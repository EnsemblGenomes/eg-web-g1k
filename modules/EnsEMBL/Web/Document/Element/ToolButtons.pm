# $Id: ToolButtons.pm,v 1.1.18.1 2014-09-12 09:39:14 jk10 Exp $

package EnsEMBL::Web::Document::Element::ToolButtons;

sub label_classes {
  return {
    'Configure this page' => 'config',
    'Manage your data'    => 'data',
    'Export data'         => 'export',
    'Bookmark this page'  => 'bookmark',
    'Get VCF data'        => 'data'
  };
}


sub init {
    my $self        = shift;
    my $controller  = shift;
    my $hub         = $controller->hub;
    my $object      = $controller->object;
    my @components  = @{$hub->components};
    my $view_config;
    my $region      = $hub->param('r') || '';
    my $url         = $hub->url;

    $view_config = $hub->get_viewconfig(shift @components) while !$view_config && scalar @components;

    if ($view_config) {
	my $component = $view_config->component;

	$self->add_entry({
      caption => 'Configure this page',
      class   => 'modal_link',
      rel     => "modal_config_$component",
      url     => $hub->url('Config', {
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
    caption => 'Manage your data',
    class   => 'modal_link',
    url     => $hub->url({
      time    => time,
      type    => 'UserData',
      action  => 'ManageData',
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
        type      => 'Account',
        action    => 'Bookmark/Add',
        __clear   => 1,
        name      => $title->get,
        shortname => $title->get_short,
        url       => $hub->species_defs->ENSEMBL_BASE_URL . $hub->url
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

    if ($url !~ /\/ExternalData\// && $url !~ /_g1k\?/) {
      $self->add_entry({
        caption => 'View in Ensembl',
        url     => 'http://GRCh37.ensembl.org'.$hub->url,
        rel     => 'external',
      });
    } else {
      $self->add_entry({
        caption => 'View in Ensembl',
        class   => 'disabled',
        url     => undef,
        title   => 'You cannot view the data from this page in Ensembl'
      });
    }
}


1;
