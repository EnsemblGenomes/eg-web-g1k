package EnsEMBL::Web::Command::UserData::ForgeRun;

use strict;
use warnings;

use EnsEMBL::Web::Tools::Misc qw(get_url_filesize);
use EnsEMBL::Web::Tools::Misc qw(get_url_content);
use Data::Dumper;
use base qw(EnsEMBL::Web::Command::UserData);

use Bio::Analysis::Forge 1.1;

sub process {
  my $self     = shift;
  my $hub      = $self->hub;
  my $session  = $hub->session;
  my $redirect = $hub->species_path($hub->data_species) . '/UserData/';

  my $params         = { __clear => 1, action => 'ForgeFeedback' };
  my ($method)           = grep $hub->param($_), qw(file url text);
  my $MIN_SNPS = 5;

  foreach (qw(ld tmin tmax reps ctrls src bkgd name overlap overlap2)) {
      if ($hub->param($_)) {
	  $params->{$_} = $hub->param($_);
      }
  }

  my $format = $hub->param('format');
  my $num = 0;

  my @snps;
  my $error = '';
  my $content = '';

  if ($method eq 'text') {
      $content = $hub->param($method);
  } elsif ($method eq 'url') {
      my $url = $hub->param('url');
      $url    =~ s/^\s+//;
      $url    =~ s/\s+$//;

    ## Needs full URL to work, including protocol
      unless ($url =~ /^http/ || $url =~ /^ftp:/) {
	  $url = ($url =~ /^ftp/) ? "ftp://$url" : "http://$url";
      }
      my $response = get_url_content($url);
      $content = $response->{'content'};
      $error           = $response->{'error'} ;
      if ($error) {
	  $error .= " ( $url ) ";
      }
  } else {
      my %args;
      my @orig_path = split('/', $hub->param($method));
      $args{'filename'} = $orig_path[-1];

      $args{'tmp_filename'} = $hub->input->tmpFileName($hub->param($method));
      my $file = EnsEMBL::Web::TmpFile::Text->new(prefix => 'user_upload', %args);

      if ($content = $file->content) {
      } else {
	  $error = "Could not upload file: $!";
      }
  }

  my $forge ; 

  unless ($error) {
      my $fname = $SiteDefs::ENSEMBL_SERVERROOT.'/tmp/user_upload';

      $forge = Bio::Analysis::Forge->new(
	  {
	      output => $fname,
        bkgd => $params->{'bkgd'},
        data =>  $params->{'src'},
	      label => $params->{'name'} || '',
	      ld  => $params->{'ld'},
	      tmin  => $params->{'tmin'},
	      tmax  => $params->{'tmax'},
	      repetitions => $params->{'reps'},
	      overlap => $params->{'overlap'},
	      datadir => $SiteDefs::FORGE_DATA,
	      dsn => $SiteDefs::FORGE_DSN,
	      user => $SiteDefs::FORGE_USER,
	      pass => $SiteDefs::FORGE_PASS,
	      r_libs => $SiteDefs::R_LIBS
		  
	  });

      unless ($forge) {
	  my $helpdesk = $SiteDefs::ENSEMBL_HELPDESK_EMAIL;
	  $error .= "<br/> System error: Failed to initialise Forge analysis. Please report this to <a href=\"mailto:$helpdesk\">$helpdesk</a>."; 
      }

  }

  unless ($error) {
      if ($format eq 'rsid') {
	  @snps = grep {/^rs\d+/} split /\n|\r/, $content;
      } elsif ($format eq 'vcf') {
	  foreach my $snp (split /\n|\r/, $content) {
	      next unless $snp;
	      next if ($snp =~ /^#/);
	      my ($chr, $beg, $rsid) = split "\t", $snp;
	      unless ($chr =~ /^chr/){
		  $chr = "chr". $chr;
	      }
	      if ($rsid =~/^rs\d+/){
		  push @snps, $rsid;
	      }
	      else {
		  my $loc = "$chr:$beg-$beg";
		  #get the rsid from the db
		  $rsid = $forge->fetch_rsid($loc);
		  push @snps, $rsid if defined $rsid;
	      }
	  }
      } elsif ($format eq 'bed' ){
	  foreach my $snp (split /\n|\r/, $content) {
	      my $loc;
	      next unless $snp;
	      my ($chr, $beg, $end) = split "\t", $snp;
	      unless ($chr =~ /^chr/){
		  $chr = "chr". $chr;
	      }
	      $loc = "$chr:$end-$end";
            #get the $rsid from the db
	      my $rsid = $forge->fetch_rsid($loc);
	      push @snps, $rsid if defined $rsid;
	  }
      }

      if ($params->{overlap}) {
	  $MIN_SNPS = 1;
      }
      $num = scalar(@snps);  
      if ($num  < $MIN_SNPS) {
	  $error = $num ? "Only $num" : 'No';
	  $error .= " SNPs have been uploaded. Analysis requires at least $MIN_SNPS variations to work. ";
      }
  }



  unless ($error) {
      if ( my $job = $forge->submit(\@snps)) {
	  $params->{jobid} = $job;
	  $params->{num} = $num;
	  $params->{name} = $hub->param('name');
      } else {
	  $error = $forge->error;
      }
  }

  if ($error) {
      $hub->session->add_data(
	  'type'     => 'message',
	  'code'     => 'Forge',
	  'message'  => $error,
	  'function' => '_error');
      $params->{'action'} = 'Forge';
  }
 # warn Dumper $params;
  $self->ajax_redirect($hub->url($params));
}


1;
