package EnsEMBL::Web::Component::UserData::Allele;

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

  my $sitename = $hub->species_defs->ENSEMBL_SITETYPE;
  my $current_species = $hub->data_species;
  my $action_url = $hub->species_path($current_species)."/UserData/AlleleFreq";
  my $region   = $hub->param('region')   ||  '';
  my $panelurl = $hub->param('panelurl')         ||  $hub->species_defs->LATEST_RELEASE_SAMPLE || '';

  my $html;
  my $form = $self->modal_form('select', $action_url,  {method => 'post', enctype=>"multipart/form-data"});
  $form->add_notes({
    'heading'=>'Allele Frequecy Calculator',
    'text'=>'
      <p>
This tool takes a VCF file, a matching sample panel file, a chromosomal region, a population name, it then calculates population-wide allele 
frequency for sites within the chromosomal region defined.

When no population is specified, allele fequences will be calcuated for all populations in the VCF files, one at a time.

The allele frequency of an user-specified population for sites within the user-specified chromosomal region is written to a file. The total allele 
count, alternate allele count for the population is also included in the output file. Click <a href="http://www.1000genomes.org/allele-frequency-calculator-documentation" target="_blank">here</a> for full tool documentation.

'
  });

  $form->add_field({ 
    field_class => 'form-field',
    type => 'Text',
    name => 'url', 
    label => '<span>Provide file URL</span>',
    value => $hub->param('url') || ($hub->species_defs->LATEST_RELEASE_VCF ? sprintf ($hub->species_defs->LATEST_RELEASE_VCF, 1) : ''),
    style=>"font-size:12px;", class=>"_string optional ftext", rows=>2, cols=>70 });
  $form->add_notes({text =>'<p style="font-size:85%"> Example file: <a href="/forge/Pulmonary_function.vcf.txt">vcf</a></p>', class=>"fnotes"});

  my $paneleg  = $hub->species_defs->LATEST_RELEASE_SAMPLE ? $hub->species_defs->LATEST_RELEASE_SAMPLE : '';
  my $regioneg = '1:1-50000';

  $form->add_field({ 'field_class' => 'form-field', 'type' => 'String', name=>"region", value=>"$region", style=>"font-size:12px;", size=>"30", 'label'=>"Region:", maxlength => 255});
  $form->add_notes({text =>"e.g. $regioneg", class=>"fnotes"});

  $form->add_field({'field_class' => 'form-field', 'type' => 'Text', 'name' => 'panelurl', 'label' => 'Sample-Population Mapping File URL:', notes=>qq|<a href="javascript: void(0);" onClick="document.getElementById('select').panelurl.value ='';">Clear box</a>|, value=>$panelurl,  style=>"font-size:12px;", class=>"_string optional ftext", rows=>2, cols=>70 });
  $form->add_notes({text =>'<a target="_blank" href="http://www.1000genomes.org/faq/what-panel-file">What is a panel file?</a>', class=>"fnotes"});
  $form->add_notes({text =>"e.g. $paneleg", class=>"fnotes"});
  $form->add_element(type =>  'Hidden', name => 'filter', 'value' => 1 );

  my $render = $form->render;

  $html .= $render;
  return $html;
}

1;
