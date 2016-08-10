package EnsEMBL::Web::Command::UserData::SliceFile;

use strict;
use warnings;

use EnsEMBL::Web::Tools::Misc qw(get_url_filesize);
use base qw(EnsEMBL::Web::Command);

sub _slice_bam {
    my ($self, $url, $region) = @_;
    my $hub = $self->hub;

    my @path = split('/', $hub->param('url'));
    (my $newname = $region . '.' . $path[-1]) =~ s/\:/\./g;
    my $dir= $SiteDefs::ENSEMBL_SERVERROOT.'/tmp/slicer';
    my $fname = $dir.'/'.$newname;
    my $cmd = "cd $dir; samtools view $url $region -h -b -o $fname";
#    my $cmd = "samtools view $url $region -h -b -o $fname"; #output in sam format
#   my $cmd = "export TMPDIR=/tmp; samtools view $url $region -h -b > /tmp/$newname";

#    warn "CMD: $cmd \n";
    
    my $rc = `$cmd`;

#    warn "RC : $rc\n";

    my $cmi = "samtools index $fname";    
#    warn "CMi: $cmi \n";
    
    $rc = `$cmi`;
#    warn "RC : $rc\n";
  
    return $newname;
}

sub _slice_vcf {
    my ($self, $url, $region, $samples) = @_;
    my $hub = $self->hub;

    my @path = split('/', $hub->param('url'));
   
    (my $newname = $region . '.' . $path[-1]) =~ s/\:/\./g;
    my $fname = $SiteDefs::ENSEMBL_SERVERROOT.'/tmp/slicer/'.$newname;	  
    my $vcf_command;

    if($samples) {
      my $sam   = ($samples =~ tr/,//);
      $sam ++;
      $vcf_command = "tabix $url $region -h | sed -r 's/##samples=\([0-9]+\)/##samples=".$sam."/g;' | bgzip > $fname";
      system($vcf_command);

      my $fname_2  = $SiteDefs::ENSEMBL_SERVERROOT.'/tmp/slicer/filtered_' . $newname;
      $vcf_command = "vcf-subset -f -c $samples $fname | bgzip > $fname_2";
   #   warn "CMD 2: $vcf_command \n";
      system($vcf_command);
      $newname = 'filtered_' . $newname;

    } else {

      my $vcf_command = "tabix $url $region -h | bgzip > $fname";
      warn "CMD: $vcf_command \n";
      system($vcf_command);
    }

    return $newname;
}

sub process {
  my $self     = shift;
  my $hub      = $self->hub;
  my $session  = $hub->session;
  my $redirect = $hub->species_path($hub->data_species) . '/UserData/';
  my $name     = $hub->param('name');
  my $param    = {};
  my $ftype    = '';
  my $region   = $hub->param('region');
  my $vcffilter = $hub->param('vcffilter') || 0;
  my $samples = '';

  warn " Process ";

  #vcf filtering bof  
  if($vcffilter) {
    my @multi_sel = $hub->param('ind_select');

    foreach my $p(qw(    
      url
      region
      ind_list
      )
    ) {
      $param->{$p} = $hub->param($p) || '';
    }
    $param->{'ind_list'}   =~ s/\s+//g if $param->{'ind_list'};  
    my $ind_select         = join(',', @multi_sel) if scalar @multi_sel;
    $samples = $param->{'ind_list'} ? $param->{'ind_list'} :  $ind_select;
  }
  $param->{'bai'} = $hub->param('bai') || '';
  #vcf filtering eof

  if (!$name) {
    my @path = split('/', $hub->param('url'));
    $name = $path[-1];
  }

  if (my $url = $hub->param('url')) {
      if ($url =~ /\.(bam|vcf)(\.gz)?$/) {
	  $ftype = $1;
      }
      warn "Attach :$url : $ftype : $region\n";

      my $newname;

      if ($ftype eq 'bam') {
	  $newname = $self->_slice_bam($url, $region);
      } elsif ($ftype eq 'vcf') {
	  $newname = $self->_slice_vcf($url, $region, $samples);
      }
      
      if ($newname) {
	  $param->{region} = $region;
	  my $fname = $SiteDefs::ENSEMBL_SERVERROOT.'/tmp/slicer/'.$newname;	  
	  $param->{newsize} = -s $fname;
	  $param->{baisize} = -s $fname.".bai";

	  if(!$param->{newsize}) {
	    my $action_url = $hub->url({
                  type   => 'UserData',
                  action => 'SelectSlice',
                });

            $hub->session->add_data(
                  'type'     => 'message',
                  'code'     => 'SelectSlice',
 	          'message'  => "A subsection file could not be created. Either the system could not access the provided file or the region requested has no data.",
		  'function' => '_error');
	    $redirect = $action_url;

	  } else {
	    $param->{'newname'} = $newname;
	    $redirect .= 'SliceFeedback';
	  }

      } else {
         ## Set message in session
	  $session->add_data(
			     'type'  => 'message',
			     'code'  => 'SliceFile',
			     'message' => "Unable to open/index remote file: $url<br>Ensembl can only display sorted, indexed  files<br>Ensure you have sorted and indexed your file and that your web server is accessible to the Ensembl site",
			     function => '_error'
			     );
	  $redirect .= 'ManageData';
      }
  } else {
    $redirect .= 'SelectSlice';
    $param->{'filter_module'} = 'Data';
    $param->{'filter_code'} = 'no_url';
  }

  $self->ajax_redirect($redirect, $param); 
}

1;
