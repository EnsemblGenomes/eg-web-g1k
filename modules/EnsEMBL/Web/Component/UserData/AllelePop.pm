package EnsEMBL::Web::Component::UserData::AllelePop;

use strict;
use warnings;

no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $hub = $self->hub;

  my $sample_pop;
  if ( -e $hub->param('panelurl') ){
    open(SP, $hub->param('panelurl'));
    while (<SP>) {
      chomp;
      s/^\s+|\s+$//g;
      my ($sam, $pop, $plat) = split(/\t/, $_);
      $sample_pop->{$pop} ||= [];
      push @{$sample_pop->{$pop}}, $sam;
    }
    close SP;
  } 

  my $pops = [];
  push @$pops, { caption =>'ALL', value=>'ALL' };
  for my $population (sort {$a cmp $b} keys %{$sample_pop}) {
    push @{$pops}, { value => $population,  caption => $population };    
  }

  my $current_species = $hub->data_species;
  my $action_url = $hub->species_path($current_species)."/UserData/AlleleFreq";

  my $form = $self->modal_form('selectfilter', $action_url, { 'wizard' => 1, back_button=>0, 'method' => 'get'});
  $form->add_element(type =>  'Hidden', name => 'region',    'value' => $hub->param('region'));
  $form->add_element(type =>  'Hidden', name => 'url',       'value' => $hub->param('url'));
  $form->add_element(type =>  'Hidden', name => 'panelurl',   'value' => $hub->param('panelurl'));
  $form->add_element(type =>  'Hidden', name => 'vcffilter', 'value' => '1');

  $form->add_element('type'    => 'SubHeader', 'value' => 'VCF filter by population(s)');

  $form->add_element('type'  => 'MultiSelect',
                       'name'    => 'ind_select',
                       'label'   => 'Please select a population; the allele frequency will be calculated based on the selected populations.  If ALL is selected, allele frequency will be calculated for each and every population in the input files',
                       'values'  => $pops,
                       'size'    => '10');

  return $form->render;
}

1;
