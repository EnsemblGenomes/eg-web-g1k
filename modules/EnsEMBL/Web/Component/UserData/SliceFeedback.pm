package EnsEMBL::Web::Component::UserData::SliceFeedback;

sub content {
    my $self = shift;

    my $hub = $self->hub;

    my $current_species = $hub->species_path($hub->data_species);
    my $form = $self->modal_form('slicer_feedback', $current_species ."/UserData/SliceFeedback",{method=>'post', no_button=>1});

    my $nm      = $self->hub->param('newname');
    my $fsize   = $self->hub->param('newsize');
    my $bai     = $self->hub->param('bai')     || '';
    my $baisize = $self->hub->param('baisize') || 0;
    my $url = "/tmp/slicer/$nm";

    my $ftype = '';

    if ($nm =~ /\.(bam|vcf)(\.gz)?$/) {
	$ftype = uc($1);
    }

    my $region = $self->hub->param('region');
    my $fname = $SiteDefs::ENSEMBL_SERVERROOT.'/tmp/slicer/'.$nm;	  

    
    my ($head, $cnt);

    if ($ftype eq 'BAM') {
	my $header_command = "samtools view $fname -H ";
	warn "CMD 2: $header_command\n";

	my $body_command = "samtools view $fname $region | head -5 | egrep -v Fetch ";
	warn "CMD 3: $body_command\n";

	$head = `$header_command`;

	$cnt =  `$body_command`;
    } else {
	my $cmd1 = "tabix -f -p vcf $fname ";
	warn "CMD 1: $cmd1\n";
	`$cmd1`;

	my $header_command = "tabix -h $fname NonExistant";
	warn "CMD 2: $header_command\n";

	my $body_command = "tabix $fname $region | head -5";
	warn "CMD 3: $body_command\n";

	$head = `$header_command`;

	$cnt =  `$body_command`;
    }

    my $baidump = ($ftype eq 'BAM') && ($bai eq 'on') ? "Your .bai file [<a href='$url.bai'>$nm.bai</a>] [Size: $baisize] has been generated.<br />" : '';

    $form->add_element(
		       type  => 'Information',
		       value => qq(Thank you - your $ftype file [<a href="$url">$nm</a>] [Size: $fsize] has been generated.<br />$baidump
                                   Right click  on the file name and choose "Save link as .." from the menu <br /> 
				   <BR />
				   <h3> Preview </h3>
				   <textarea cols="80" rows="10" wrap="off" readonly="yes">
$head
			   
$cnt
				   </textarea>
				   <br/><br/>

				   ),
		       );
    
    return $form->render;
}

1;
