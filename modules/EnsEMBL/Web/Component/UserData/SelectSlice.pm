package EnsEMBL::Web::Component::UserData::SelectSlice;

use strict;
use warnings;
no warnings 'uninitialized';
use LWP::UserAgent;
use Vcf;
use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(1);  #ajaxable set to 1 enables the page to work properly in a non pop-up window mode 
}

sub caption {
  my $self = shift;
  return '';
}

sub content {
  my $self = shift;
  my $hub = $self->hub;

  my $current_species = $hub->species_path($hub->data_species);
  my $species_defs = $hub->species_defs;
  my $user = $hub->user;
  my $sitename = $hub->species_defs->ENSEMBL_SITETYPE;
  
  my $r        = $hub->param('r')   ||  '';
  my $url      = $hub->param('url') ||  '';
  my $panelurl = $hub->param('panelurl')         ||  $hub->species_defs->LATEST_RELEASE_SAMPLE || '';
  my $filter_screen = $hub->param('filter_screen')   ||  0;
  my $region   = $hub->param('region')   ||  '';
  my $bai      = $hub->param('bai')   || '';
  my $filter   = $hub->param('filter')   ||  0;
  my $defaults = $hub->param('defaults') ||  0;  #this param is passed from 'Get VCF data' button only
  my $regioneg = '1:1-50000';
  my ($chr)    = $r ? split /:/, $r : split /:/, $regioneg;
  my ($chreg)  = split /:/, $regioneg;
  my $vcfeg    = $species_defs->LATEST_RELEASE_VCF ? sprintf($species_defs->LATEST_RELEASE_VCF, $chreg) : '';
  my $paneleg  = $species_defs->LATEST_RELEASE_SAMPLE ? $species_defs->LATEST_RELEASE_SAMPLE : '';

  #VCF/BAM INPUT FORM 
  unless ($filter_screen) {
# data for different chromsomes can come at a later data and have a not that does not follow LATEST_RELEASE_VCF template
# in this case we set LATEST_RELEASE_VCF_$CHR  to point to the specific file
      my $chr_url = "LATEST_RELEASE_VCF_$chr";
      $url = $hub->species_defs->$chr_url;
 
      $url ||= $hub->species_defs->LATEST_RELEASE_VCF ? sprintf ($hub->species_defs->LATEST_RELEASE_VCF, $chr) : '';


    $region = $r ? $hub->param('r') : '';

    my $form = $self->modal_form( 'select_slice', $current_species . "/UserData/SelectSlice", {'label'=>'Next', class=>'check std', method=>'get'});
    my $text = qq{When slicing a VCF or BAM file, both the data file and its index file should be present on the web server and named correctly. <br />
      The VCF file should have a ".vcf.gz" extension, and the index file should have a ".vcf.gz.tbi" extension, E.g: MyData.vcf.gz, MyData.vcf.gz.tbi <br />
      The BAM file should have a ".bam" extension, and the index file should have a ".bam.bai" extension, E.g: MyData.bam, MyData.bam.bai
      <br/><br/>Click <a href="http://www.1000genomes.org/data-slicer" target=_blank>here</a> for more extensive documentation.
      };

    $form->add_notes({'location' => 'head', 'text' => $text, 'class' => 'notes', 'heading' => '<h4>Data Slicer:</h4>'});

    my $fs = $form->add_fieldset({legend=>'Upload files'});
    $fs->add_hidden({'name' => 'filter_screen', 'value' => 1});
    $fs->add_hidden({'name' => 'defaults', 'value' => $defaults});

    $fs->add_field({ 'field_class'=>'form-field', 'type'=>'Text', 'name'=>'url', 'label'=>'VCF File URL:', notes=>qq|<a href="javascript: void(0);" onClick="document.getElementById('select_slice').url.value ='';">Clear box</a>|, value=>$url,  style=>"font-size:12px;", class=>"_string optional ftext", rows=>2, cols=>70});

    $fs->add_notes({text =>"e.g. $vcfeg", class=>"fnotes"});
    $fs->add_field({ 'field_class' => 'form-field', 'type' => 'String', name=>"region", value=>"$region", style=>"font-size:12px;", size=>"80", 'label'=>"Region:", maxlength => 255});
    $fs->add_notes({text =>"e.g. $regioneg", class=>"fnotes"});
    $fs->add_field({type=>'checkbox', class=>"ff-checklist", name=>'bai', 'label' => qq{BAM options (this doesn't apply to VCF files):}, 'notes'=>"Generate .bai file *"});
    $fs->add_notes({text =>"*(please note that the generation of .bai file may take approximately 30 seconds)", class=>"fnotes"});

    $fs->add_field({type=>'radiolist', class=>"ff-checklist", name=>"filter", 'label'=>qq{VCF filters (this doesn't apply to BAM files):}, 'values'=>[{value=>0, caption=>"No filtering"},{value=>1, caption=>"By individual(s)"}, {value=>2, caption=>"By population(s) **"}] });
    $fs->add_notes({text =>"**(to filter by populations please provide URL to a Sample-Population Mapping File in the box below)", class=>"fnotes"});

    $fs->add_field({'field_class' => 'form-field', 'type' => 'Text', 'name' => 'panelurl', 'label' => 'Sample-Population Mapping File URL:', notes=>qq|<a href="javascript: void(0);" onClick="document.getElementById('select_slice').panelurl.value ='';">Clear box</a>|, value=>$panelurl,  style=>"font-size:12px;", class=>"_string optional ftext", rows=>2, cols=>70 });
    $fs->add_notes({text =>'<a target="_blank" href="http://www.1000genomes.org/faq/what-panel-file">What is a panel file?</a>', class=>"fnotes"});
    $fs->add_notes({text =>"e.g. $paneleg", class=>"fnotes"});

    return $form->render;
  }

  my ($error, $action_url);
  my ($vcf, $response);
  my $inds = [];

  my ($chr_region) = $region ? split /:/, $region : '';
  #Make sure that the chromosome number given in the region matches the VCF file chromosome:
  if ( $chr_region && $url && ($url =~ /ftp\:\/\/ftp\.1000genomes\.ebi\.ac\.uk\//) ) {
    $url =~ s/(chr)(\d+|X|Y)(\.)/$1$chr_region$3/;
  }

  if ($filter)  {  ##Check for errors:
      foreach ($url, $panelurl, $region) {
	  $_ =~ s/^\s+|\s+$//g;
      }

      $error = "VCF filters doesn't apply to BAM files."                                           if     ($url =~ /\.(bam)(\.gz)?$/); 
      $error = "Please provide VCF file and chromosomal region."                                   if     (!$url || !$region) && ($filter == 1);
      $error = "Please provide VCF file, chromosomal region and Sample-Population Mapping file."   if     (!$url || !$region || !$panelurl) && ($filter == 2);
      $error = "The chromosomal region value $region is invalid."                                  unless ($region =~ /^(\S+?):(\d+)-(\d+)$/ || $error);

      unless ($error) {
	if ($filter == 1)  {
	  eval {
	      $vcf = Vcf->new(file=>$url, region=>$region,  print_header=>1, silent=>1);  #print_header allows print sample name rather than column index                                             
	  };
          $error = "Error reading VCF file" unless ($vcf);

          if ($vcf) {    
            $vcf->parse_header();
            my $x=$vcf->next_data_hash();

            for my $individual (keys %{$$x{gtypes}}) {
              push @{$inds}, { value => $individual,  name => $individual };      
            }
            $error = "No data found in the uploaded VCF file within the region $region." unless (scalar @{$inds});
          }

        } else {
           if ($panelurl =~ /ftp:\/\/|http:\/\//) {
		my $ua = LWP::UserAgent->new;
		$ua->timeout(10);
		$ua->env_proxy;
		$response = $ua->get($panelurl);
		$error = "Sample-Population Mapping file has no content."             unless $response->is_success;
           } else { 
                $error = "Sample-Population Mapping file $panelurl can not be found." unless ( -e $panelurl );
           } 
	}
      }
  
      if($error) {
        $action_url = $hub->url({
                  type   => 'UserData',
                  action => 'SelectSlice',
                  url    => $url,
                  region => $region,
                  panelurl => $panelurl,
                  filter   => $filter
              });

        $hub->session->add_data(
          'type'     => 'message',
          'code'     => 'SelectSlice',
          'message'  => $error,
          'function' => '_error');
      }
  
  } else {  #No filter selected

      $action_url = $hub->url({
                  type   => 'UserData',
                  action => 'SliceFile',
                  url    => $url,
                  region => $region,
                  bai    => $bai,
              });
  }

  if ($error || !$filter) {
     return qq#                                                                                                                                                                                                  
      <html>
       <head>
        <script type="text/javascript">
	if (!window.parent.Ensembl.EventManager.trigger('modalOpen', { href: '$action_url', title: 'File uploaded' })) {
	    window.parent.location = '$action_url';
	} else {
            console.log('location ' + window.parent.location );
        }
        </script>
       </head>
      </html>#;              
  }

  #FILTER FORM 
  my $form = $self->modal_form('selectfilter', "$current_species/UserData/SliceFile", { 'wizard' => 1, 'back_button' => 1, 'method' => 'get'});
  $form->add_element(type =>  'Hidden', name => 'region',    'value' => $region);
  $form->add_element(type =>  'Hidden', name => 'url',       'value' => $url);
  $form->add_element(type =>  'Hidden', name => 'vcffilter', 'value' => '1');
  $form->add_element(type =>  'Hidden', name => 'defaults',  'value' => $defaults);

  if ($filter == 1)  {

      $form->add_element('type' => 'SubHeader', 'value' => 'VCF filter by individual(s)');
      $form->add_element('type' => 'String',
                      'name'    => 'ind_list',
                      'label'   => 'Enter comma separated list of individuals',
                      'notes'   =>'maximum 372 individuals',
                      'size'    => '60',
                      'value'   => '' );

      $form->add_element('type'  => 'MultiSelect',
                       'name'    => 'ind_select',
                       'label'   => 'Alternatively, select one or more individuals from the scrollable list',
                       'notes'   =>'maximum 416 individuals',
                       'values'  => $inds,
                       'size'    => '10');
      return $form->render;
  }

  if ($filter == 2) {
    my $sample_pop;
    if ( -e $panelurl) {
	open(SP, $panelurl);
	while (<SP>) {
            chomp;
	    s/^\s+|\s+$//g;
	    my ($sam, $pop, $plat) = split(/\t/, $_);
	    $sample_pop->{$pop} ||= [];
	    push @{$sample_pop->{$pop}}, $sam;
	}
	close SP;
    } elsif ($panelurl =~ /ftp:\/\//) {
      my @content = split /\n/, $response->content() ;    #$response->decoded_content;                              
      foreach (@content) {
        chomp;
	s/^\s+|\s+$//g;
	my ($sam, $pop, $plat) = split(/\t/, $_);
	$sample_pop->{$pop} ||= []; 
        push @{$sample_pop->{$pop}}, $sam;
      }
    } 

    my $pops = [];
    for my $population (sort {$a cmp $b} keys %{$sample_pop}) {
        my $ind_list = join(',' , @{$sample_pop->{$population}});
        push @{$pops}, { value => $ind_list,  name => $population };
    }
    $form->add_element('type'    => 'SubHeader', 'value' => 'VCF filter by population(s)');
    $form->add_element('type'    => 'MultiSelect',
                         'name'    => 'ind_select',
                         'label'   => 'Select one or more populations from the scrollable list',
                         'values'  => $pops,
		         'size'    => '10');
    return $form->render;
  } 

}

1;
