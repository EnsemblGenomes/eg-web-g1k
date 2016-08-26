package EnsEMBL::Web::Command::UserData::AlleleFreq;

use strict;
use warnings;

use EnsEMBL::Web::Tools::Misc qw(get_url_content);

use base qw(EnsEMBL::Web::Command::UserData);
use LWP::UserAgent;
use LWP::Simple;
use Digest::MD5 qw(md5_hex);
use File::Copy;
use EnsEMBL::Web::TmpFile;
use EnsEMBL::Web::TmpFile::Text;

sub process {
  my $self = shift;
  my $params;
  my $hub = $self->hub;
  my $method = $hub->param('url');

  # checking params
  my $error;

  foreach (qw(url region pop panelurl)) {
    my $value = $hub->param($_);
    if ($value) {
      $value =~ s/^\s+|\s+$//g;
      $params->{$_} = $value;
    }
  }
  $error = "Please provide VCF file, Sample-Population Mapping file and Chromosomal region."
    if ( !$params->{region} || !$params->{panelurl} || !$method);
  $error = "The chromosomal region value ".$params->{region}." is invalid."
    unless ($params->{region} =~ /^(\S+?):(\d+)-(\d+)$/ || $error);

  my $action_url;  
  if ($error) {
    $action_url = $hub->url({
                  type   => 'UserData',
                  action => 'Allele',
                  error => $error
              });
    $hub->session->add_data(
          'type'     => 'message',
          'code'     => 'Allele',
          'message'  => $error,
          'function' => '_error');
      
    return $self->ajax_redirect($action_url);
  }
  $self->hub->param('filter') ? $self->filter_screen : $self->final_screen;
} 

sub filter_screen {
  my $self = shift;

  # save panel file and parse its name as a param
  my $hub = $self->hub;
  my $params;
  my $error;

  foreach (qw(url region pop panelurl)) {
    if ($hub->param($_)) {
      $params->{$_} = $hub->param($_);
    }
  }
  
  # SAVING PANEL FILE
  my $panelurl = $params->{panelurl};
  $panelurl    =~ s/^\s+//;
  $panelurl    =~ s/\s+$//;

  unless ($panelurl =~ /^http/ || $panelurl =~ /^ftp:/) {
    $panelurl = ($panelurl =~ /^ftp/) ? "ftp://$panelurl" : "http://$panelurl";
  }
  my $response = get_url_content($panelurl);
  my $content = $response->{'content'};

  my $panelfile =  new EnsEMBL::Web::TmpFile::Text(
    extension    => 'txt',
    prefix       => '',
    content_type => 'text/plain; charset=utf-8');
  $panelfile->print($content);
  $params->{panelurl} = $panelfile->tmp_dir.'/'.$panelfile->prefix.'/'.$panelfile->filename;
    
  $error = $response->{'error'} ;

  if ($error) {
    $error .= " ( $panelurl ) ";
  }

  my $action_url;  
  if ($error) {
    $action_url = $hub->url({
                  type   => 'UserData',
                  action => 'Allele',
                  error => $error
              });
    $hub->session->add_data(
          'type'     => 'message',
          'code'     => 'Allele',
          'message'  => $error,
          'function' => '_error');
      
    return $self->ajax_redirect($action_url);
  }

  my $args = {'action' => 'AllelePop'};
  $args->{'region'} = $params->{region};
  $args->{'url'} = $params->{url};
  $args->{'panelurl'} = $params->{panelurl};
  ## Remove uploaded file record
  
  $self->ajax_redirect($hub->url($args));
}


sub final_screen {
  my $self = shift;

  my $hub = $self->hub;
  my $session = $hub->session;
  my $params;
  
  foreach (qw(url region ind_select panelurl)) {
    if ($hub->param($_)) {
      #$_ =~ s/^\s+|\s+$//g;
      $params->{$_} = $hub->param($_);
    }
  }

  my @multi_sel = $hub->param('ind_select');
  my $ind_select         = join(',', @multi_sel) if scalar @multi_sel;

  my ($fullpath);
  my $root    = $hub->species_defs->ENSEMBL_SERVERROOT;
  
  my $tmp_dir=$root."/tmp/user_upload/";

  my $url = $hub->param('url');
  $url    =~ s/^\s+//;
  $url    =~ s/\s+$//;

  ## Needs full URL to work, including protocol
  unless ($url =~ /^http/ || $url =~ /^ftp:/) {
    $url = ($url =~ /^ftp/) ? "ftp://$url" : "http://$url";
  }
  
  (my $prefix = $params->{region}) =~ s/[:\.-]/_/g;
  $url =~ m!([^/]+)$!;
  my $shortname = "${prefix}_$1";

  my $index_resp = system ("cd $tmp_dir; tabix -f -h -p vcf $url ".$params->{region}." > $shortname");
  if ($index_resp) {
    my $exitcode = $? >>8;
    $params->{'error_code'} = $exitcode;
    warn "!!! Allele Frequency Calculation ERROR, TABIX: ".$params->{'error_code'};

    # ensembl-4022, adding a delay and try again due to some weird behaviour of ftp server
    sleep(2);
    $index_resp = system ("cd $tmp_dir; tabix -f -h -p vcf $url ".$params->{region}." > $shortname");
    my $action_url;
    if  ($index_resp) {
      my $exitcode = $? >>8;
      $params->{'error_code'} = $exitcode;
      warn "!!! Second attempt, Allele Frequency Calculation ERROR, TABIX: ".$params->{'error_code'};
    
      # now redirecting
      $action_url = $hub->url({
                  type   => 'UserData',
                  action => 'Allele',
                  error => "File URL doesn't exist"
                });
      $hub->session->add_data(
          'type'     => 'message',
          'code'     => 'Allele',
          'message'  => "File URL doesn't exist",
          'function' => '_error');
      return $self->ajax_redirect($action_url);
    }
  }

  $index_resp = system ("cd $tmp_dir; bgzip -c $shortname>$shortname.gz");
  $shortname = $shortname.".gz";
  $fullpath = $tmp_dir.$shortname;


  if ($index_resp) {
    my $exitcode = $? >>8;
    $params->{'error_code'} = $exitcode;
    warn "!!! Allele Frequency Calculation ERROR ".$params->{'error_code'};
  } else {
    # creating index
    $index_resp = system ("cd $tmp_dir; tabix -f -p vcf $shortname");
    my $index_file = $tmp_dir.$params->{file}.".tbi";
  }

  my $script = '/nfs/public/rw/ensembl/tools/calculate_allele_frq_from_vcf.pl';
  my $libs    = join(',', @SiteDefs::ENSEMBL_LIB_DIRS);

  my $oneliner = 'perl';
  $oneliner .= " $script -vcf ".$fullpath;


  $oneliner .= " -sample_panel ".$params->{panelurl};
  # population
  $oneliner .= " -region ".$params->{region};
#  $oneliner .= " -pop ".$params->{'ind_select'} if $params->{'ind_select'};
 
  my $p;
  if ( $ind_select=~ /ALL/i || !$ind_select) {
    $p='all';
  }
  else {
    $p = $ind_select;
  }
  $oneliner .= " -pop ".$p;

  ## Pipe straight to output file, to conserve memory
  $params->{region} =~ s/^.*://;
  # output file name
  $p =~ s/,/_/g;
  my $short_name = 'calculated_fra' . "." . $params->{region} . "." . $p.".txt";

  my $output = $hub->species_defs->ENSEMBL_TMP_DIR.'/download/'.$short_name; 
  my $extension = 'all';
  my $directory = $self->make_directory($output);
  $oneliner .= " -out_file ".$output;
#  $oneliner .= " -no_tabix";

  warn "Allele frequency calc tool: ".$oneliner;


  $self->run($oneliner);

  my $args = {'action' => 'AlleleCalc'};
  ## Create new session record for output file 
  my $session = $hub->session;
  my $code    = join '_', md5_hex($output), $session->session_id;

  ## Attach data species to session
  my $new_data = $session->add_data(
      type      => 'upload',
      filename  => $output,
      code      => $code,
      md5       => md5_hex($output),
      name      => $hub->param('name') || 'Allele Frequency Calculation',
      species   => $hub->data_species,
      format    => $hub->param('output_format') || 'all',
      timestamp => time,
      extension => $extension,
      prefix    => 'download',
  );
    
  $session->configure_user_data('upload', $new_data);
  $args->{'code'} = $code;
  $args->{'name'} = $short_name;
  ## Remove uploaded file record
  $session->purge_data('code' => $hub->param('code'));

  #unlink $tmp_dir.$shortname;
  #unlink $tmp_dir.$shortname.".tbi";

  #$self->ajax_redirect($hub->url($args), $args);
  $self->ajax_redirect($hub->url($args),undef,undef,'page');
}

sub run {
  my ($self, $oneliner) = @_;
  my $hub = $self->hub;
  my %return = (
                1 => 'no_features',
                2 => 'location_unknown',
              );
  my ($return_code, $args);
  my $pid = fork();
  if (not defined $pid) {
    warn "FORK ERROR: Resources not available.";
  } elsif ($pid == 0) {
    sleep 2;
    $return_code= system($oneliner);
    if ($return_code) {
      my $exitcode = $? >>8;
      $args->{'error_code'} = $return{$exitcode};
      $args->{'code'} = $hub->param('code');
      warn "!!! Allele Frequency Calculation ERROR ".$args->{'error_code'};
    }
    exit(0);
  } else {
  #    waitpid($pid,0);
  }
  return $args;
  }

1;
