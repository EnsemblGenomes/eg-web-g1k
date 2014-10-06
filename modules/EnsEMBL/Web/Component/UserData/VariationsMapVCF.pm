package EnsEMBL::Web::Component::UserData::VariationsMapVCF;
  
use base qw(EnsEMBL::Web::Component::UserData);
use HTML::Entities qw(encode_entities);
use EnsEMBL::Web::TmpFile::Text;

sub _init {
    my $self = shift;
    $self->cacheable(0);
    $self->ajaxable(1);
}

sub content {
    my $self  = shift;
    my $object = $self->object;
    my $hub    = $object->hub;
    my $species_defs = $hub->species_defs;

    my $variation_mapper = $hub->param('variation_mapper') || 0;
    my $vregion          = $hub->param('vregion')          || $hub->param('r') || '';
    my $r                = $hub->param('r')   ||  '';
    my $url              = $hub->param('url') ||       $hub->species_defs->LATEST_RELEASE_VCF || '';
    my $panelurl         = $hub->param('panelurl') ||  $hub->species_defs->LATEST_RELEASE_SAMPLE || '';
    my $collapsed        = $hub->param('collapsed')        || 0;
    my $current_species = $object->data_species;
    my $action_url      = $object->species_path($current_species)."/UserData/VariationsMapVCF";

    my $subheader = 'Upload files';    
    my $heading   = 'Variation Pattern Finder';
    my $regioneg  = '6:46620015-46620998';
    my ($chr)     = $r ? split /:/, $r : split /:/, $regioneg;
    my ($chreg)   = split /:/, $regioneg;
    my $url_value = $hub->species_defs->LATEST_RELEASE_VCF ? sprintf ($hub->species_defs->LATEST_RELEASE_VCF, $chr)    : '';
    my $url_note  = $hub->species_defs->LATEST_RELEASE_VCF ? sprintf ($hub->species_defs->LATEST_RELEASE_VCF, $chreg)  : ''; 	     

    unless ($variation_mapper) {
      #not using the standard Form module because too many additional features need to be fit in this web form 
      my $html= qq(<div id="VariationsMapVCF" class="js_panel __h __h_comp_VariationsMapVCF" style="overflow-x: auto;"> 
       <form name="snpform" class="check std" method="get" action="/Homo_sapiens/UserData/VariationsMapVCF">
       <div class="notes">
         <h4>Variation Pattern Finder:</h4>
         <div>
           <p class="space-below">
The Variation Pattern Finder allows one to look for patterns of shared variation between individuals in the same vcf file. The finder looks for distinct variation combinations within the region, as well as individuals associated with each variation combination pattern. Only variants which have potentially functional consequences are considered, both intergenic and intronic snps are excluded. Click
<a target="_blank" href="http://www.1000genomes.org/variation-pattern-finder">here</a>
for more extensive documentation.
<br>
<br>
The search will be performed on any VCF file you provided. It should be a URL for the file location. Please refer to
<a href="http://vcftools.sourceforge.net/specs.html">http://vcftools.sourceforge.net/specs.html</a>
for VCF format specification. A URL for the latest VCF file for variation calls and genotypes released by the 1000 Genomes Project is displayed as an example below the input box. A mapping file between individual sample and population is required as well. The latest mapping file between individual sample and population released by the 1000 Genomes Project is displayed as well below the input box.
           </p>
         </div>
       </div>        
       <fieldset>
          <legend>Upload files</legend>
          <input type="hidden" name="variation_mapper" value="1">
          <div class="form-field">
            <label class="ff-label" for="_FC9fDoaR_1">VCF File URL:</label>
            <div class="ff-right">
              <textarea  class="_string optional ftext" rows="2" cols="70"style="font-size:12px;" name="url">$url_value</textarea><br/>
              <a href="javascript: void(0);"  onClick="document.snpform.url.value ='';">Clear box</a>
            </div>
          </div>
         <div class="fnotes">e.g. $url_note</div>
         <div class="form-field">
           <label class="ff-label" for="_FC9fDoaR_2">Sample-Population Mapping File URL:</label>
           <div class="ff-right">
  	     <textarea  class="_string optional ftext" rows="2" cols="70" style="font-size:12px;" name="panelurl">$panelurl</textarea><br/>
             <a href="javascript: void(0);"  onClick="document.snpform.panelurl.value ='';">Clear box</a>
           </div>
         </div>
         <div class="fnotes"><a target="_blank" href="http://www.1000genomes.org/faq/what-panel-file">What is a panel file?</a></div>
         <div class="fnotes">e.g. $panelurl</div>
         <div class="form-field">
           <label class="ff-label" for="_FC9fDoaR_3">Region:</label>
           <div class="ff-right">
             <input id="_FC9fDoaR_3" class="_string optional ftext" type="text" size="80" style="font-size:12px;" name="vregion" value="$vregion">
           </div>
         </div>
         <div class="fnotes">e.g. $regioneg</div>
         <div class="form-field">
           <div class="ff-right">
             <input id="_FC9fDoaR_4" class="fbutton" type="submit" name="submit" value="Next >">
           </div>
         </div>
       </fieldset>
       </form>
       </div>);

      return $html;
    }

    my ($chr_region) = $vregion ? split /:/, $vregion : '';
    #Make sure that the chromosome number given in the region matches the VCF file chromosome:
    if ( $chr_region && $url && ($url =~ /ftp\:\/\/ftp\.1000genomes\.ebi\.ac\.uk\//) ) {
	$url =~ s/(chr)(\d+|X|Y)(\.)/$1$chr_region$3/;
    }

    my ($table, $export) = $object->variations_map_vcf($url, $panelurl, $vregion, $collapsed);

    my $ii;
    my ($exported1, $exported2) = ('', '');
    for($ii = 0; $ii < (scalar @{$export}); $ii++) {
      $exported1 .= join(",",  @{$export->[$ii]}) . "\n";
      $exported2 .= join("\t", @{$export->[$ii]}) . "\n";
    }

    my ($temp_file1, $temp_file2) = ( new EnsEMBL::Web::TmpFile::Text(
    extension    => 'txt',
    prefix       => '',
    content_type => 'text/plain; charset=utf-8'), 
    new EnsEMBL::Web::TmpFile::Text(
    extension    => 'xls',
    prefix       => '',
    content_type => 'text/plain; charset=utf-8') );
    $temp_file1->print($exported1);
    $temp_file2->print($exported2);
    my ($exported_data1, $exported_data2) = ($species_defs->ENSEMBL_TMP_URL."/".$temp_file1->filename, $species_defs->ENSEMBL_TMP_URL."/".$temp_file2->filename);


    my $html;
    if ($table && ($table !~ /error:/)) {     
      my $collapsed_new   = $collapsed ? 0 : 1;
      my $collapsed_label = $collapsed ? 'Go to expanded view' : 'Go to collapsed view'; 
      my $collapsed_link  = $collapsed ? "<p>Click the button to see expanded view</p>" : "<p>Click the button to see collapsed view</p>";
      my $form = $self->modal_form('select', $action_url, { label => $collapsed_label, buttons_align => 'left', 'method' => 'get' });
      $form->add_element('type' => 'SubHeader',                         'value' => $heading);
      $form->add_element( type => 'Hidden', name => 'variation_mapper', 'value' => $variation_mapper);
      $form->add_element( type => 'Hidden', name => 'url',              'value' => $url);
      $form->add_element( type => 'Hidden', name => 'panelurl',         'value' => $panelurl);
      $form->add_element( type => 'Hidden', name => 'vregion',          'value' => $vregion);
      $form->add_element( type => 'Hidden', name => 'collapsed',        'value' => $collapsed_new);
      $form->add_element( type => 'Information', 'value' => "Export data:&nbsp;&nbsp;<a href='$exported_data1' target=_blank>CSV</a>&nbsp;&nbsp;&nbsp;<a href='$exported_data2' target=_blank>Excel</a>");
      $form->add_element( type => 'Hidden', class => "panel_type",      'value' => "SNPPanel");
      $html .=  $form->render;
      return "$html$table";   

   } else {
      
      $table =~ s/error://;
      my $msg = "$table";

      $hub->session->add_data(
          'type'  => 'message',
          'code'  => 'Variation map',
          'message' => $msg,
          function => '_error'
      );

      return qq#                                                                                                                                                                                                
      <html>
       <head>
        <script type="text/javascript">
	 if (!window.parent.Ensembl.EventManager.trigger('modalOpen', { href: '$action_url?msg=$msg&url=$url&panelurl=$panelurl&vregion=$vregion', title: 'File uploaded' })) {
	   window.parent.location = '$action_url?msg=$msg&url=$url&panelurl=$panelurl&vregion=$vregion';
	 }        
        </script>
       </head>
      </html>#;                                                       

   }


}

1;
