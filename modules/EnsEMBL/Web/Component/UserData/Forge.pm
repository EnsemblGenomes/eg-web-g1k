package EnsEMBL::Web::Component::UserData::Forge;

use strict;
use warnings;

no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $hub = $self->hub;

  my $sitename = $hub->species_defs->ENSEMBL_SITETYPE;
  my $current_species = $hub->data_species;
  my $action_url = $hub->species_path($current_species)."/UserData/ForgeRun";
  my $variation_limit = 750;


# Default values
  my $reps = $hub->param('reps') || 100;
  my $overlap = $hub->param('ovelap') || 1;
  my $overlap2 = $hub->param('ovelap') || 1;
  my $tmin = $hub->param('tmin') || 0.01;
  my $tmax = $hub->param('tmax') || 0.05;
  my $ld = $hub->param('ld') || 0.8;
  my $bkgd  = $hub->param('bkgd') || 'gwas';
  my $src = $hub->param('src') || 'erc';


  my $example = join "\n", qw(rs2395730 rs12914385 rs2865531 rs11168048 rs1529672 rs357394 rs13147758 rs3769124 rs2647044 rs12504628 rs1541374 rs2869967 rs1928168 rs3094548 rs3867498 rs6903823 rs4762767 rs9978142 rs11172113 rs9310995 rs2571445 rs2070600 rs11727189 rs3734729 rs2906966 rs1036429 rs16909898 rs3995090 rs2284746 rs2544527 rs12477314 rs2277027 rs993925 rs1344555 rs1455782 rs2855812 rs2838815 rs11001819 rs12716852 rs2798641 rs4129267 rs7068966 rs12899618 rs153916 rs1551943 rs730532 rs1980057 rs3820928 rs2036527 rs10516526 rs2857595 rs3817928 rs310558 rs808225 rs12447804);

  my $html;
  my $form = $self->modal_form('forge', $action_url,{method => 'post'});

  $form->add_notes({ 
    'heading'=>'Forge Analysis',
    'text'=>'
Welcome to the new version of Forge (1.1). The major changes are: <br/>

- Forge now reports enrichments as -log10 of the binomial p value. <br/>
- By default Forge filters the test SNPs for LD at r<sup>2</sup> >= 0.8, and retains only one test SNP of the LD cluster. This option can be turned off (warning - leads to over-estimation of enrichment) or set at a lower threshold (r<sup>2</sup> >= 0.1). <br/><br/>

You can still use the previous version of forge at <a href="/Homo_sapiens/UserData/Forge10">Forge Analysis v1.0</a>

      <p>
The Forge tool takes a list of variants and analyzes their enrichment in functional regions. See <a href="http://www.1000genomes.org/forge-analysis-11" target="_blank">full tool documentation</a> for more details.</p>

<table cellpadding="2">
<tr>
<td style="width:50%">
<a style="text-decoration:none" href="http://www.1000genomes.org/forge-analysis-11"><img align="absmiddle" src="/i/16/help.png" /> Help/Documentation </a>
</td>
<td rowspan="3" style="vertical-align:middle">
Problems or questions ? <br/>
Contact: <a href="mailto:dunhum@ebi.ac.uk"> dunham @ ebi.ac.uk </a>
</td>
</tr>
<tr>
<td>
<a style="text-decoration:none" href="http://www.1000genomes.org/forge-analysis-11#Options"> <img align="absmiddle" src="/i/16/tool.png" /> Options </a>
</td>
</tr>
<tr>
<td>
<a style="text-decoration:none" href="http://www.1000genomes.org/forge-gwas-catalog-example-gallery11"><img align="absmiddle" src="/i/16/documentation.png" /> Gallery of examples </a>
</td>
</tr>
</table>
<br/>
'
  });

  my $subheader = 'Input file';


  $form->add_field({ 'field_class'=>'form-field', 'type'=>'Text', 'name'=>'text', 
		      label => '<a href="http://www.1000genomes.org/forge-analysis-11#Inputs" class="popup constant help-header _ht" title="Click for help (opens in new window)"><span>Paste data</span><span class="sprite info_icon"></span></a>',
notes=>qq|<a href="javascript: void(0);" onClick="document.getElementById('forge').text.value ='';">Clear box</a>|, value=>$example,  style=>"font-size:12px;", class=>"_string optional ftext", rows=>2, cols=>70});


  $form->add_element( type => 'File', name => 'file',
		      label => '<a href="http://www.1000genomes.org/forge-analysis-11#Inputs" class="popup constant help-header _ht" title="Click for help (opens in new window)"><span>Upload file</span><span class="sprite info_icon"></span></a>');


  $form->add_element( type => 'URL',  name => 'url', 
		      label => '<a href="http://www.1000genomes.org/forge-analysis-11#Inputs" class="popup constant help-header _ht" title="Click for help (opens in new window)"><span>or provide file URL </span><span class="sprite info_icon"></span></a>',
		      size => 30, 
    notes => '<p style="font-size:85%"> Example files: <a href="/forge/Pulmonary_function.rsid.txt">rsid</a> <a href="/forge/Pulmonary_function.vcf.txt">vcf</a> <a href="/forge/Pulmonary_function.bed.txt">bed</a></p>'
 );
  
  $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'format',
      'label'   => 'Input file format',
#      'label'   => 'Input file format <p style="font-size:80%">Example files</p>',
      'values'  => [
        { value => 'rsid',     name => 'RSID (List of variations)'     },
        { value => 'vcf', name => 'VCF'                 },
        { value => 'bed',  name => 'BED'              },
      ],
      'value'   => 'rsid',
      'select'  => 'select',
  );
  
  
  ## OPTIONS
  $form->add_element('type' => 'SubHeader', 
		      value => '<a href="http://www.1000genomes.org/forge-analysis-11#Options" class="popup constant help-header _ht" title="Click for help (opens in new window)"><span>Options</span><span class="sprite info_icon"></span></a>',
      );
#'value' => 'Options');



  $form->add_element( type => 'String', name => 'name', label => 'Name for this data (optional)' );

  $form->add_element(
      'type'    => 'CheckBox',
      'name'    => 'overlap',
      'label'   => "Find overlaps only",
      'value'   => 'overlap'
  );

  $form->add_element(
      'type'    => 'RadioGroup',
      'name'    => 'src',
      'label'   => "Analysis data from",

#      label => '<a href="#" class="constant help-header _ht" title="Choose the analysis"><span>Analysis data from</span><span class="sprite info_icon"></span></a>',

      'values'  => [
        { value => 'erc', name => 'Epigenome Roadmap' },
        { value => 'encode',          name => 'ENCODE'          },
      ],
      'value'   => $src,
      'select'  => 'select',
  );
  $form->add_element(
      'type'    => 'RadioGroup',
      'name'    => 'bkgd',
      'label'   => "Background selection",
      'values'  => [
        { value => 'gwas', name => 'GWAS typing arrays'          },
        { value => 'omni', name => 'Omni array SNPs' },
      ],
      'value'   => $bkgd,
      'select'  => 'select',
  );


  $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'ld',
      'label'   => "LD filter ( r<sup>2</sup> )",
      'values'  => [
        { value => '0.8',     name => '0.8'     },
        { value => '0.1', name => '0.1'                 },
        { value => '0.0',  name => 'No filter'              },
      ],
      'value'   => $ld,
      'select'  => 'select',
  );
  
  $form->add_element( type => 'String', name => 'reps', label => 'Background repetitions (<span style="font-size:80%">setting of 1000 would give more accurate backgrounds but the job will be 3-4 times slower </span> )', value => $reps );

  $form->add_element( type => 'NoEdit', label => 'Significance thresholds (<span style="font-size:80%">P values before Bonferroni correction </span> ) ');
#  $form->add_element( type => 'NoEdit', label => '<span style="padding-left:20px;font-size:80%"> ( enter zero values for both to disable filtering by significance ) </span>' );
  $form->add_element( type => 'String', name => 'tmin', label => '<span style="padding-left:20px;font-size:80%">Min</span>', value => $tmin );
  $form->add_element( type => 'String', name => 'tmax', label => '<span style="padding-left:20px;font-size:80%">Max</span>', value => $tmax );

  
  $form->add_element('type' => 'SubHeader', 'value' => ' ');
  
  my $render = $form->render;

  $html .= $render;
  return $html;
}

1;