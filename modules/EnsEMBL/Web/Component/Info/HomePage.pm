# $Id: HomePage.pm,v 1.4 2014-01-17 16:02:23 jk10 Exp $

package EnsEMBL::Web::Component::Info::HomePage;

use strict;

use EnsEMBL::Web::Document::HTML::HomeSearch;
use EnsEMBL::Web::DBSQL::ProductionAdaptor;

use base qw(EnsEMBL::Web::Component);


sub content {
  my $self              = shift;
  my $hub               = $self->hub;
  my $species_defs      = $hub->species_defs;
  my $species           = $hub->species;
  my $img_url           = $self->img_url;

  my $common_name       = $species_defs->SPECIES_COMMON_NAME;
  my $display_name      = $species_defs->SPECIES_SCIENTIFIC_NAME;
  my $sound             = $species_defs->SAMPLE_DATA->{'ENSEMBL_SOUND'};

  my $html = '
<div class="column-wrapper">  
  <div class="column-two">
    <div class="column-padding no-left-margin">
      <div class="species-badge">';

  $html .= qq(<img src="${img_url}species/64/$species.png" alt="" title="$sound" />);
  if ($common_name =~ /\./) {
    $html .= qq(<h1>$display_name</h1>);
  }
  else {
    $html .= qq(<h1>$common_name</h1><p>$display_name</p>);
  }
  
  $html .= '</div>'; #close species-badge

  $html .= EnsEMBL::Web::Document::HTML::HomeSearch->new($hub)->render;

  $html .= '
    </div>
  </div>
  <div class="column-two">
    <div class="column-padding no-right-margin">';

  if ($hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'}) {
    $html .= '<div class="round-box info-box unbordered">'.$self->_whatsnew_text.'</div>';  
  }

  $html .= '
    </div>
  </div>
</div>
<div class="column-wrapper">  
  <div class="column-two">
    <div class="column-padding no-left-margin">';

  $html .= '<div class="round-box tinted-box unbordered" style="background-color:#DAD9E5;">'.$self->_assembly_text.'</div>';

#  $html .= '<div class="round-box tinted-box unbordered">'.$self->_compara_text.'</div>';

  if ($hub->database('funcgen')) {
    $html .= '<div class="round-box tinted-box unbordered" style="background-color:#DAD9E5;">'.$self->_funcgen_text.'</div>';
  }

  $html .= '
    </div>
  </div>
  <div class="column-two">
    <div class="column-padding no-right-margin">';

  $html .= '<div class="round-box tinted-box unbordered" style="background-color:#DAD9E5;">'.$self->_variation_text.'</div>';

  $html .= '<div class="round-box tinted-box unbordered" style="background-color:#DAD9E5;">'.$self->_genebuild_text.'</div>';
 
 

  $html .= '
    </div>
  </div>
</div>';

  return $html;  
}

sub _variation_text {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $species         = $hub->species;
  my $img_url         = $self->img_url;
  my $sample_data     = $species_defs->SAMPLE_DATA;
  my $ensembl_version = $self->_site_release;

  my $html;

  if ($hub->database('variation')) {
    $html .= '
<div class="homepage-icon">
    ';

    my $var_url  = $species_defs->species_path.'/Variation/Explore?v='.$sample_data->{'VARIATION_PARAM'};
    my $var_text = $sample_data->{'VARIATION_TEXT'}; 
    $html .= qq(
      <a class="nodeco _ht" href="$var_url" title="Go to variant $var_text"><img src="${img_url}96/variation.png" class="bordered" /><span>Example variant</span></a>
    );

    if ($sample_data->{'PHENOTYPE_PARAM'}) {
      my $phen_text = $sample_data->{'PHENOTYPE_TEXT'}; 
      my $phen_url  = $species_defs->species_path.'/Phenotype/Locations?ph='.$sample_data->{'PHENOTYPE_PARAM'};
      $html .= qq(
        <a class="nodeco _ht" href="$phen_url" title="Go to phenotype $phen_text"><img src="${img_url}96/phenotype.png" class="bordered" /><span>Example phenotype</span></a>
    );
  }

    $html .= '
</div>
';

    $html .= '<h2>Variation</h2>
<p><strong>What can I find?</strong> Short sequence variants';

    #my $dbsnp = $species_defs->databases->{'DATABASE_VARIATION'}{'dbSNP_VERSION'};
    #if ($dbsnp) {
    #  $html .= " (e.g. from dbSNP $dbsnp)";
    #}
    if ($species_defs->databases->{'DATABASE_VARIATION'}{'STRUCTURAL_VARIANT_COUNT'}) {
      $html .= ' and longer structural variants';
    }
    if ($sample_data->{'PHENOTYPE_PARAM'}) {
      $html .= '; disease and other phenotypes';
    }
    $html .= '.</p>';

    my $site = $species_defs->ENSEMBL_SITETYPE;
    $html .= qq(<p><a href="/info/docs/variation/" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about variation in $site</a></p>);
# 1KG
#    if ($species_defs->ENSEMBL_FTP_URL) {
#      my $ftp_url = sprintf '%s/release-%s/variation/gvf/%s/', $species_defs->ENSEMBL_FTP_URL, $ensembl_version, lc $species;
    my $ftp_url = 'http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/phase1/analysis_results/';
      $html   .= qq(
<p><a href="$ftp_url" class="nodeco"><img src="${img_url}24/download.png" alt="" class="homepage-link" />Explore 1000 genomes raw data files</a> (VCF)</p>);
#    }
  }
  else {
    $html .= '<h2>Variation</h2>
<p>This species currently has no variation database. However you can process your own variants using the Variant Effect Predictor:</p>';
  }

   my $vep_url = $hub->url({'type'=>'UserData','action'=>'UploadVariations'});
    $html .= qq(<p><a href="$vep_url" class="modal_link nodeco"><img src="${img_url}24/tool.png" class="homepage-link" />Variant Effect Predictor<img src="${img_url}vep_logo_sm.png" style="vertical-align:top;margin-left:12px" /></a></p>);

  return $html;
}

sub _funcgen_text {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $species         = $hub->species;
  my $img_url         = $self->img_url;
  my $sample_data     = $species_defs->SAMPLE_DATA;
  my $ensembl_version = $species_defs->ENSEMBL_VERSION;
  my $site            = $species_defs->ENSEMBL_SITETYPE;
  my $html;

  my $sample_data = $species_defs->SAMPLE_DATA;
  if ($sample_data->{REGULATION_PARAM}) {
    $html = '<div class="homepage-icon">';

    my $reg_url  = $species_defs->species_path . '/Regulation/Cell_line?db=funcgen;rf=' . $sample_data->{'REGULATION_PARAM'};
    my $reg_text = $sample_data->{'REGULATION_TEXT'};
    $html .= qq(<a class="nodeco _ht" href="$reg_url" title="Go to regulatory feature $reg_text"><img src="${img_url}96/regulation.png" class="bordered" /><span>Example regulatory feature</span></a>);

    $html .= '</div>';
    $html .= '<h2>Regulation</h2><p><strong>What can I find?</strong> DNA methylation, transcription factor binding sites, histone modifications, and regulatory features such as enhancers and repressors, and microarray annotations.</p>';

    # EG add a link to about_[spp]#regulation
    my $display_name = $species_defs->SPECIES_SCIENTIFIC_NAME;
    if ($self->_other_text('regulation', $species)) {
      $html .= qq(<p><a href="/$species/Info/Annotation#regulation" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about regulation in $display_name</a></p>);
    }

    $html .= qq(<p><a href="/info/docs/funcgen/" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about the $site regulatory build</a> and <a href="/info/docs/microarray_probe_set_mapping.html" class="nodeco">microarray annotation</a></p>);

    if ($species_defs->ENSEMBL_FTP_URL) {
      my $ftp_url = sprintf '%s/release-%s/regulation/%s/', $species_defs->ENSEMBL_FTP_URL, $ensembl_version, lc $species;
      $html .= qq(<p><a href="$ftp_url" class="nodeco"><img src="${img_url}24/download.png" alt="" class="homepage-link" />Download all regulatory features</a> (GFF)</p>);
    }
  }
  else {
    $html .= '<h2>Regulation</h2><p><strong>What can I find?</strong> Microarray annotations.</p>';
  warn "XX Noparam";
    # EG add a link to about_[spp]#regulation
    my $display_name = $species_defs->SPECIES_SCIENTIFIC_NAME;
    if ($self->_other_text('regulation', $species)) {
      $html .= qq(<p><a href="/$species/Info/Annotation#regulation" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about regulation in $display_name</a></p>);
    }
    $html .= qq(<p><a href="/info/docs/microarray_probe_set_mapping.html" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about the $site microarray annotation strategy</a></p>);

    # EG add a link to about_[spp]#regulation
    my $display_name = $species_defs->SPECIES_SCIENTIFIC_NAME;
    if ($self->_other_text('regulation', $species)) {
      $html .= qq(<p><a href="/$species/Info/Annotation#regulation" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about regulation in $display_name</a></p>);
    }
  }

  return $html;
}

sub _genebuild_text {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $species         = $hub->species;
  my $img_url         = $self->img_url;
  my $sample_data     = $species_defs->SAMPLE_DATA;
  my $ensembl_version = $self->_site_release;
  my $vega            = $species_defs->get_config('MULTI', 'ENSEMBL_VEGA');
  my $has_vega        = $vega->{$species};

  my $html = '<div class="homepage-icon">';

  my $gene_text = $sample_data->{'GENE_TEXT'};
  my $gene_url  = $species_defs->species_path . '/Gene/Summary?g=' . $sample_data->{'GENE_PARAM'};
  $html .= qq(<a class="nodeco _ht" href="$gene_url" title="Go to gene $gene_text"><img src="${img_url}96/gene.png" class="bordered" /><span>Example gene</span></a>);

  my $trans_text = $sample_data->{'TRANSCRIPT_TEXT'};
  my $trans_url  = $species_defs->species_path . '/Transcript/Summary?t=' . $sample_data->{'TRANSCRIPT_PARAM'};
  $html .= qq(<a class="nodeco _ht" href="$trans_url" title="Go to transcript $trans_text"><img src="${img_url}96/transcript.png" class="bordered" /><span>Example transcript</span></a>);

  $html .= '</div>'; #homepage-icon

  $html .= '<h2>Gene annotation</h2><p><strong>What can I find?</strong> Protein-coding and non-coding genes, splice variants, cDNA and protein sequences, non-coding RNAs.</p>';
  $html .= qq(<p><a href="/$species/Info/Annotation/#genebuild" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about this genebuild</a></p>);


  if ($species_defs->ENSEMBL_FTP_URL) {
    foreach my $format ('fasta', 'gtf'){
      my $ftp_url;
      $ftp_url = sprintf '%s/release-%s/%s/%s/', $species_defs->ENSEMBL_FTP_URL, $ensembl_version, $format, lc $species;
      $html .= qq(<p><a href="$ftp_url" class="nodeco"><img src="${img_url}24/download.png" alt="" class="homepage-link" />Download genes, cDNAs, ncRNA, proteins</a> ($format)</p>);
    }
  }

  my $im_url = $hub->url({'type' => 'UserData', 'action' => 'UploadStableIDs'});
  $html .= qq(<p><a href="$im_url" class="modal_link nodeco"><img src="${img_url}24/tool.png" class="homepage-link" />Update your old Ensembl IDs</a></p>);
  if ($has_vega) {
    $html .= qq(
      <a href="http://vega.sanger.ac.uk/$species/" class="nodeco">
      <img src="/img/vega_small.gif" alt="Vega logo" style="float:left;margin-right:8px;width:83px;height:30px;vertical-align:center" title="Vega - Vertebrate Genome Annotation database" /></a>
      <p>
        Additional manual annotation can be found in <a href="http://vega.sanger.ac.uk/$species/" class="nodeco">Vega</a>
      </p>
    );
  }
  return $html;
}

sub _site_release {
  my $self = shift;
  return $self->hub->species_defs->ENSEMBL_VERSION;
}

1;
