package EnsEMBL::Web::Component::UserData::AlleleFreqOutput;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Constants;
use EnsEMBL::Web::Utils::FileHandler;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  my $self = shift;
  return 'Allele Frequency Tool Output';
}

sub content {
  my $self = shift;
  my $hub = $self->hub;
  my %data_error = EnsEMBL::Web::Constants::USERDATA_MESSAGES;
  my ($html, $output, $error);

  if ($hub->param('error_code')) {
    $error = $data_error{$hub->param('error_code')};
  }
  else {
    my $record = $hub->session->get_data('code' => $hub->param('code'));

#    my $extension = $record->{'extension'};
#    my $filename = $record->{'filename'};
    my $current_species = $hub->species_path($hub->data_species);
    my $nm      = $self->hub->param('name');

    my $filename = $hub->species_defs->ENSEMBL_TMP_DIR.'/download/'.$nm;

    my $fsize = -s $filename;

    my $url = "/tmp/slicer/$nm";
    my $head;
    my $cnt;
    
    if (-e $filename) {
      my $name    = $record->{'name'} || 'allelefreq_output';
      my $url = "../../tmp/download/$nm"; 
      my $i;
      my @head = file_get_contents($filename);
      foreach my $line (@head){
        my $ll = join('&#09;', split(/\t/, $line ));
        last if $i >= 50;
        $head .=$ll;        
        $i++;
      }

      my $form = $self->modal_form('allele_output', $current_species ."/UserData/AlleleFreqOutput",{method=>'post', no_button=>1});
      $form->add_element(
        type  => 'Information',
        value => qq(Thank you - your file [<a href="$url">$nm</a>] [Size: $fsize] has been generated.<br />
             Right click  on the file name and choose "Save link as .." from the menu <br /> 
        <BR />
        <h3> Preview </h3>
        <textarea cols="80" rows="10" wrap="off" readonly="yes">$head</textarea>
        <br/><br/>
        ),
      );
     return $form->render;
    }
    else {
      $error = $data_error{'load_file'};
    }
  }

  if ($error) {
    $error->{'message'} .= sprintf(' Would you like to <a href="%s" class="modal_link">try again</a> with different region(s)?',
              $self->url($hub->species_path($hub->data_species) . '/UserData/Allele')
              );

    $html = $self->_info_panel($error->{'type'}, $error->{'title'}, $error->{'message'});
  }
  $html .= $output;

  return $html;
}

1;
