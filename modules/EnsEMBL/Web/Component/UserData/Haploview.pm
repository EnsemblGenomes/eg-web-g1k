package EnsEMBL::Web::Component::UserData::Haploview;

use strict;
use warnings;
no warnings 'uninitialized';
use LWP::UserAgent;
use Net::FTP;
use Vcf;
use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(1);  #ajaxable set to 1 enables the page to work properly in a non pop-up window mode 
}

sub content {
  my $self = shift;
  my $hub = $self->hub;
  my $species_defs = $hub->species_defs;
  my $param;
  my $current_species = $hub->species_path($hub->data_species);
  my $user = $hub->user;
  my $sitename = $species_defs->ENSEMBL_SITETYPE;
 
  my $r        = $hub->param('r')         ||  '';
  my $vcfurl   = $hub->param('vcfurl')    ||  $species_defs->LATEST_RELEASE_VCF || '';
  my $panelurl = $hub->param('panelurl')  ||  $species_defs->LATEST_RELEASE_SAMPLE || '';

  my $pop_list   = $hub->param('pop_list')   ||  '';
  my $region     = $hub->param('region')     || $r ||  '';
  my $check_data = $hub->param('check_data') ||  0;
  my $process    = $hub->param('process')    ||  0;
  my $regioneg   = '6:46620015-46620998';
  my ($chreg)    = split /:/, $regioneg;
  my $vcfeg      = $species_defs->LATEST_RELEASE_VCF ? sprintf($species_defs->LATEST_RELEASE_VCF, $chreg) : '';
  my $paneleg    = $species_defs->LATEST_RELEASE_SAMPLE ? $species_defs->LATEST_RELEASE_SAMPLE : '';
  my $sample_pop;

  #INPUT FORM 
  if (!$check_data && !$process) {

    my ($chr) = $r ? split /:/, $r : split /:/, $regioneg;
    $vcfurl   = $species_defs->LATEST_RELEASE_VCF ? sprintf ($species_defs->LATEST_RELEASE_VCF, $chr) : '';

      my $html= qq(<div id="VCFtoPEDconverter" class="js_panel __h __h_comp_VCFtoPEDconverter" style="overflow-x: auto;">
       <form name="haploview" class="check std" method="get" action="$current_species/UserData/Haploview">
       <div class="notes">
         <h4>VCF to PED converter:</h4>
         <div>
           <p class="space-below">
      When providing a VCF file, both the data file and its index file should be present on the web server and named correctly. <br />
      The VCF file should have a ".vcf.gz" extension, and the index file should have a ".vcf.gz.tbi" extension, E.g: MyData.vcf.gz, MyData.vcf.gz.tbi <br />
      Click <a href="http://www.1000genomes.org/vcf-ped-converter" target=_blank>here</a> for more extensive documentation.
           </p>
         </div>
       </div>
       <fieldset>
          <legend>Upload files</legend>
          <input type="hidden" name="check_data" value="1">
          <div class="form-field">
            <label class="ff-label" for="_FC9fDoaR_1">VCF File URL:</label>
            <div class="ff-right">
              <textarea  class="_string optional ftext" rows="2" cols="70"style="font-size:12px;" name="vcfurl">$vcfurl</textarea><br/>
              <a href="javascript: void(0);"  onClick="document.haploview.vcfurl.value ='';">Clear box</a>
            </div>
          </div>
         <div class="fnotes">e.g. $vcfeg</div>
         <div class="form-field">
           <label class="ff-label" for="_FC9fDoaR_2">Sample-Population Mapping File URL:</label>
           <div class="ff-right">
             <textarea  class="_string optional ftext" rows="2" cols="70" style="font-size:12px;" name="panelurl">$panelurl</textarea><br/>
             <a href="javascript: void(0);"  onClick="document.haploview.panelurl.value ='';">Clear box</a>
           </div>
         </div>
         <div class="fnotes"><a target="_blank" href="http://www.1000genomes.org/faq/what-panel-file">What is a panel file?</a></div>
         <div class="fnotes">e.g. $paneleg</div>
         <div class="form-field">
           <label class="ff-label" for="_FC9fDoaR_3">Region:</label>
           <div class="ff-right">
             <input id="_FC9fDoaR_3" class="_string optional ftext" type="text" size="80" style="font-size:12px;" name="region" value="$region">
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

  #CHECK DATA
  if ($check_data && !$process)  {  ##Check for errors:
      my ($vcf, $response);
      my ($error, $action_url);
      foreach ($vcfurl, $panelurl, $region) {
	  $_ =~ s/^\s+|\s+$//g;
      }

      $error = "Please provide VCF file, Sample-Population Mapping file and Chromosomal region."   if (!$vcfurl || !$region || !$panelurl);
      $error = "The chromosomal region value $region is invalid." unless ($region =~ /^(\S+?):(\d+)-(\d+)$/ || $error);

      my ($chr) = split /:/, $region;
      #Make sure that the chromosome number given in the region matches the VCF file chromosome:
      if ($vcfurl =~ /ftp\:\/\/ftp\.1000genomes\.ebi\.ac\.uk\//) {
        $vcfurl =~ s/(chr)(\d+|X|Y)(\.)/$1$chr$3/;
      }

      unless ($error) {
	  eval {
	      $vcf = Vcf->new(file=>$vcfurl, region=>$region,  print_header=>1, silent=>1);  #print_header allows print sample name rather than column index                        
          };
          $error = "Error reading VCF file. " if $@;

          my $inds = [];
          if ((!$@) && ($vcf)) {    
            $vcf->parse_header();
            my $x=$vcf->next_data_hash();
            for my $individual (keys %{$$x{gtypes}}) {
              push @{$inds}, { value => $individual,  name => $individual };      
            }
            $error = "No data found in the uploaded VCF file within the region $region. " unless (scalar @{$inds});
          } 
               
          if ($panelurl =~ /ftp:\/\//) {
		my $ua = LWP::UserAgent->new;
		$ua->timeout(10);
		$ua->env_proxy;
		$response = $ua->get($panelurl);
		$error .= "Sample-Population Mapping file has no content. "             unless $response->is_success;
	
          } else { 
                $error .= "Sample-Population Mapping file $panelurl can not be found. "; # unless ( -e $panelurl );
          }  
      } #unless error

      $action_url = $hub->url({
            type      => 'UserData',
            action    => 'Haploview',
            url       => $vcfurl,
            region    => $region,
            panelurl  => $panelurl,
          });

          if($error) {
            $hub->session->add_data(
             'type'     => 'message',
             'code'     => 'Haploview',
             'message'  => $error,
             'function' => '_error');
            

          
            return qq#                                                                                                                                                                                                  
             <html>
              <head>
               <script type="text/javascript">
	        if (!window.parent.Ensembl.EventManager.trigger('modalOpen', { href: '$action_url', title: 'File uploaded' })) {
	          window.parent.location = '$action_url';
	        }
               </script>
              </head>
             </html>#;  
	  } #if($error)


      #FILTER FORM
      my $form = $self->modal_form('selectfilter', "$current_species/UserData/Haploview", { 'wizard' => 1, 'back_button' => 0, 'method' => 'get'});
      $form->add_element(type =>  'Hidden', name => 'region',    'value' => $region);
      $form->add_element(type =>  'Hidden', name => 'vcfurl',    'value' => $vcfurl);
      $form->add_element(type =>  'Hidden', name => 'panelurl',  'value' => $panelurl);
      $form->add_element(type =>  'Hidden', name => 'check_data','value' => 1);
      $form->add_element(type =>  'Hidden', name => 'process',   'value' => 1);

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
        push @{$pops}, { value => $population,  name => $population };
      }
      $form->add_element(type =>  'Hidden', name => 'all_pops',   'value' => join ',' , keys %{$sample_pop});
      $form->add_element('type'    => 'SubHeader', 'value' => 'VCF filter by population(s)');
      $form->add_element('type'    => 'MultiSelect',
                         'name'    => 'pop_list',
                         'label'   => 'Select one or more populations from the scrollable list',
                         'values'  => $pops,
                         'size'    => '10');
      $form->add_element(
        'type'    => 'RadioGroup',
        'name'    => 'base_format',
        'label'   => "Base format",
        'values'  => [
          { value => 'let', name => 'Bases' },
          { value => 'num', name => 'Numbers' },
        ],
        'value'   => 'let',
        'select'  => 'select',
      );


      return $form->render;   

   } #check data && process
  
   #If no population is selected from the Multi Select list, then all the populations from the Sample-Population Mapping File are taken:
   my @populations  =  $hub->referer->{params}->{pop_list} ? @{$hub->referer->{params}->{pop_list}} : split /,/, $hub->param('all_pops');
   my ($output_ped_, $output_info_);
   my $output_dir = $SiteDefs::ENSEMBL_SERVERROOT.'/tmp/slicer';  

   $output_ped_ = "$region.ped";
   $output_ped_ =~ s{:}{_};

   $output_info_ = "$region.info";
   $output_info_ =~ s{:}{_};

   my $output_ped = $output_dir . '/' . $output_ped_;
   $output_ped =~ s{//}{/}g;

   my $output_info = $output_dir . '/' . $output_info_;
   $output_info =~ s{//}{/}g;


   my $individuals = $self->get_individuals($panelurl, \@populations);
   my ($markers, $genotypes) = $self->get_markers_genotypes($vcfurl, $region, $individuals);

   $self->print_info($markers,  $output_info);
   $self->print_ped($genotypes, $output_ped);

  my $url_output_ped  = "/tmp/slicer/$output_ped_";
  my $url_output_info = "/tmp/slicer/$output_info_";

   my $html = "Your linkage pedigree and marker information files have been generated:</br>";
   $html   .= "Right click on the file name and choose \"Save link as ..\" from the menu:</br><a href='$url_output_info' target=_blank>Marker Information File</a>&nbsp;&nbsp;&nbsp;<a href='$url_output_ped' target=_blank>Linkage Pedigree File</a>";

   return $html;
}

sub get_markers_genotypes {
    my ($self, $vcf, $region, $individuals) = @_;

    my $hub = $self->hub;
    my $base_format = $hub->param('base_format');

    my %base_codes = $base_format =~ /num/ ? ('A' => 1,   'C' => 2,   'G' => 3,   'T' => 4)
                : ('A' => 'A', 'C' => 'C', 'G' => 'G', 'T' => 'T');

    my @markers;
    my %genotypes;

    open my $VCF, "tabix -h $vcf $region |"
        or die("cannot open vcf $!");

    my %column_indices;

  LINE:
    while (my $line = <$VCF>) {
        next LINE if ($line =~ /^\#\#/);
        chomp $line;
        my @columns  = split(/\t/, $line);

        if ($line =~ /^\#/) {
            foreach my $i (0..$#columns) {
                $column_indices{$columns[$i]} = $i;
            }
            next LINE;
        }

        my ($chromosome, $position, $name, $ref_allele, $alt_alleles) = @columns;

        my @allele_codes = map {$base_codes{$_} || 0} $ref_allele, (split(/,/, $alt_alleles));
        next LINE if ((scalar grep {$_} @allele_codes) < 2);

        my %marker_genotypes;
        my %alleles_present;
        foreach my $population (keys %$individuals) {
	  INDIVIDUAL:
            foreach my $individual (@{$individuals->{$population}}) {
                next INDIVIDUAL if (! $column_indices{$individual});
                my $genotype_string = $columns[ $column_indices{$individual} ];
                if ($genotype_string =~ /(\d+)(?:\/|\|)(\d+)/) {
                    my @genotype_codes = ($allele_codes[$1], $allele_codes[$2]);

                    $alleles_present{$_} = 1 foreach (grep {$_} @genotype_codes);
                    $marker_genotypes{$population}{$individual} = \@genotype_codes;
                }
                else {
                    $marker_genotypes{$population}{$individual} = [0,0];
                }
            }
        }

        next LINE if ((scalar grep {$_} keys %alleles_present) < 2);

        foreach my $population (keys %marker_genotypes) {
            foreach my $individual (keys %{$marker_genotypes{$population}}) {
                push(@{$genotypes{$population}{$individual}}, $marker_genotypes{$population}{$individual});
            }
        }

        if ($name eq '.') {
            $name = "$chromosome:$position";
        }
        push(@markers, [$name,$position]);
    }
    close $VCF;
    return \@markers, \%genotypes;
}

sub print_ped {
    my ($self, $genotypes, $file) = @_;

    open my $FILE, '>', $file
        or die "cannot open $file $!";
    foreach my $population (keys %$genotypes) {
        my $pedigree_counter = 1;
        foreach my $individual (keys %{$genotypes->{$population}}) {
            my $pedigree = $population . '_' . $pedigree_counter;
            print $FILE join("\t", $pedigree, $individual, 0, 0, 0, 0,);
            foreach my $genotype_codes (@{$genotypes->{$population}->{$individual}}) {
                print $FILE "\t", $genotype_codes->[0], ' ', $genotype_codes->[1];
            }
            print $FILE "\n";
            $pedigree_counter ++;
        }
    }
    close $FILE;
}

sub print_info {
    my ($self, $markers, $file) = @_;

    open my $FILE, '>', $file
        or die "cannot open $file $!";
    foreach my $marker (@$markers) {
        print $FILE join("\t", @$marker), "\n";
    }
    close $FILE;
    return;
}


sub get_individuals {
    my ($self, $sample_panel, $allowed_pops) = @_;

    my @sample_panel_lines;

    if ($sample_panel =~ /ftp:\/\/([\w.]+)(\/\S+)/) {
        my $ftp_host = $1;
        my $path = $2;

        my $ftp = Net::FTP->new($ftp_host);
        $ftp->login or die('Cannot login ' , $ftp->message);

        my $sample_panel_content;
        open my $PANEL, '>', \$sample_panel_content;
        $ftp->get($path, $PANEL) or die ('could not $sample_panel ' , $ftp->message);
        $ftp->quit;
        close $PANEL;

        @sample_panel_lines = split(/\n/, $sample_panel_content);
    }
    else {
        open my $FILE, '<', $sample_panel
            or die("cannot open $sample_panel $!");
        @sample_panel_lines = <$FILE>;
        close $FILE;
    }

    my %allowed_pops_hash;
    my %individuals;
    foreach my $pop (@$allowed_pops) {
        $allowed_pops_hash{$pop} = 1;
        $individuals{$pop} = [];
    }

    foreach my $line (@sample_panel_lines) {
        my ($individual, $population) = split(/\s+/, $line);
        if ($allowed_pops_hash{$population}) {
            push(@{$individuals{$population}}, $individual);
        }
    }
    return \%individuals;
}


1;
