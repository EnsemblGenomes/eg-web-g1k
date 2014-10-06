package EnsEMBL::Web::Component::UserData::ForgeOutput;

use base qw(EnsEMBL::Web::Component::UserData);

use EnsEMBL::Web::Controller::SSI;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
    my $self = shift;

    my $hub    = $self->hub;
    my $job = $hub->param('jobid'); 

    my $form = $self->modal_form('forgeOutput', '#', {no_button => 1});

    my $fname = $hub->species_defs->ENSEMBL_SERVERROOT . "/tmp/user_upload/${job}/LOG";
    my $flog = '';
    if (open F, $fname) {
	$flog = join "<br/>", <F>;
	close F;
    }

    my $rname = $hub->species_defs->ENSEMBL_SERVERROOT . "/tmp/user_upload/${job}/table.htm";
    my $results = '';
    if (open F, $rname) {
	$results = join "\n", <F>;
	close F;
    } else {
	warn " can not open $rname ( $! ) ";
    }

    my $links = $hub->param('overlap') ? '' : " 
 <li><a target='forge' href='/tmp/user_upload/${job}/dchart.htm'> Interactive chart </a></li>
 <li><a target='forge' href='/tmp/user_upload/${job}/chart.pdf'> PDF </a> </li>
";

    $form->add_notes({ 
	'heading'=>'Forge Analysis Results',
	'text'=>qq(
<style>
#forge-log {
 border:0;	    
	  height:125px;
	    overflow:auto;

	    }
#forge-res {
	list-style:none;
      padding:0;
      margin:0;
		     }

#forge-res li {
		   display:inline;
		     padding-left:10px;
	}

</style>
<div id="forge-log">
$flog
</div>

<br/><b>You can also view results as </b>
<ul id="forge-res">
 $links
 <li><a target="forge" href="/tmp/user_upload/$job/chart.tsv"> TSV </a> </li>
</ul>
		)		   
});
    
    my $html = $form->render;

    $html .= qq{ <div style="border:0" id="forge-result">
$results
</div>
};
    return $html;
}

1;
