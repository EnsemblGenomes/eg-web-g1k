package EnsEMBL::Web::Component::UserData::AlleleCalc;

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

  $self->progress();
}


sub progress {
    my $self = shift;

    my $hub    = $self->hub;

    my $job = $hub->param('code');
    my $jobname = $hub->param('name');
    return unless $jobname;

    my $jobstatus = $hub->param('jobstatus') || 'new';

    my $current_species = $hub->data_species;
    my $action_url = $hub->species_path($current_species)."/UserData/AlleleFreqOutput?jobname=$jobname";
    my $form = $self->modal_form('alstatusForm', $action_url, {no_button => 1});
    
    $form->add_element( type => 'Hidden', name => 'jobid', 'value' => $job, id=>"jobid");
    $form->add_element( type => 'Hidden', name => 'jobname', 'value'=>$jobname, id=>"jobname");
    $form->add_element( type => 'Hidden', name => 'jobstatus', id=>'jobstatus');
    $form->add_notes({ 
	'heading'=>'Allele Frequency Tool',
	'text'=>qq(
<style>
#progress-msg {
 z-index:20; 
 text-align: left; 
 vertical-align:middle; 
 height: 20px; 
 float:left; 
 position:relative;
 top:6px;
 left:10px;
 font:bold 13px Arial;
 	  border:0;
}
#progress-div {
      border:1px solid green;
      float:left; 
      margin: 0px; 
      width:100%; 
      height: 28px; 
	border-radius: 5px;
	padding-right:2px;
}

#progress-bar {
		     border-radius: 5px;
		     z-index:10; 
		   position:relative; 
		   height: 24px;top:1px;left:0; 
		     background-color:a8bb80;
		     vertical-align:top;
		   width:0%;
		     margin-right:2px;
	     margin-right:2px;
	}
.report th {
  width:200px;
  height:30px;
}
</style>
<table class="report">
<tr><th> Name for the data</th><td> $jobname </td></tr>
<tr><th> Job ID </th><td> $job </td></tr>
<tr><th> Status </th><td style="width:200px;">
<div id="progress-div">
<div id="progress-msg"></div>
<div id="progress-bar">&nbsp;</div>
</div>
</td>
</tr>
</table>
	    )});


    my $html = $form->render;

    if (1) {
    $html .=qq{

 <script type="text/javascript">

var forgeInterval;

function forgeUpdate(pFile) {
  \$.ajaxSetup({ cache: false });
  \$.getJSON(pFile, function(pData, textStatus) {
	  var prog = pData.progress;
	  var c = pData.count;
	  var s = pData.status;
	  
	  var pb = \$("#progress-bar");
	  if (pb) {
	  var message = 'Contacting ENA ...';
	  
	  if (s == 'COMPLETE') {
	      message = "Completed.";
	      pb.addClass("completed");
	  } else {
	      if (s == 'LOAD') {
	        message = 'Loading data ...';
              }
              if (s == 'RESULTS') {
	        message = 'Generating results [ ' + prog + '% ]';
              }
              if (s == 'RUNNING') {
	        if (prog > -1) {
		  message = 'Running analysis [ ' + prog + ' ]';
                }
	      }
	  }
	  
	  pb.css('width', prog + '%');
	  
	  var pm = \$("#progress-msg");
	  pm.html(message);
         }	  
      });
  var pb = \$("#progress-bar");
  if (pb) {
  if (pb.hasClass("completed")) {
      return 1;
  }
  }
}



function forgeSetUpdate(jobid) {
  var pm = \$("#progress-msg");
  pm.html('Loading data ...');
  forgeInterval = setInterval(function () {
    var url = '/Multi/allelefreqstatus?name='+jobid;
    console.log(url);
    var c = forgeUpdate(url);
    if (c > 0) {
        clearInterval(forgeInterval);
        document.getElementById("jobstatus").value='ready'; 
        document.getElementById("alstatusForm").submit();
    }
 }, 750);
}
</script>

<script>\$(document).ready(
function(){
  forgeSetUpdate('$jobname');
}
);
</script>

};
    }
    return $html;
}

1;
