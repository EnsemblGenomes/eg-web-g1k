# $Id: Page.pm,v 1.2 2013-09-27 15:51:31 jk10 Exp $

package EnsEMBL::Web::Document::Page;

sub grch37_url {
  my $path = shift;
 
  my $rewrite = {
    '^/tools.*'                           => '"/info/docs/tools/index.html"',
    '^/info/website/help.*'               => '"/info/index.html"',
    '^/([^/]+)/UserData/SelectFeatures'   => '"/$1/Tools/AssemblyConverter"',
    '^/([^/]+)/UserData/UploadStableIDs'  => '"/$1/Tools/IDMapper"',
    '^/([^/]+)/UserData/UploadVariations' => '"/$1/Tools/VEP"',
    '^/([^/]+)/UserData/SelectSlice'      => '"/$1/Tools/DataSlicer"',
    '^/([^/]+)/UserData/VariationsMapVCF' => '"/$1/Tools/VariationPattern"',
    '^/([^/]+)/UserData/Haploview'        => '"/$1/Tools/VcftoPed"',
    '^/([^/]+)/UserData/Allele'           => '"/$1/Tools/AlleleFrequency"',
  };

  $path =~ s/$_/$rewrite->{$_}/ee for (keys %$rewrite);
  return 'http://grch37.ensembl.org' . $path;
}

sub html_template {
  ### Main page printing function
  
  my ($self, $elements) = @_;
  
  $self->set_doc_type('XHTML',  '1.0 Trans');
  $self->add_body_attr('id',    'ensembl-webpage');
  $self->add_body_attr('class', 'mac')                               if $ENV{'HTTP_USER_AGENT'} =~ /Macintosh/;
  $self->add_body_attr('class', "ie ie$1" . ($1 < 8 ? ' ie67' : '')) if $ENV{'HTTP_USER_AGENT'} =~ /MSIE (\d+)/ && $1 <  9;
  $self->add_body_attr('class', "ienew ie$1")                        if $ENV{'HTTP_USER_AGENT'} =~ /MSIE (\d+)/ && $1 >= 9;
  $self->add_body_attr('class', 'no_tabs')                           unless $elements->{'tabs'};
  $self->add_body_attr('class', 'static')                            if $self->isa('EnsEMBL::Web::Document::Page::Static');
  
  my $species_path        = $self->species_defs->species_path;
  my $species_common_name = $self->species_defs->SPECIES_COMMON_NAME;
  my $core_params         = $self->hub ? $self->hub->core_params : {};
  my $core_params_html    = join '',   map qq(<input type="hidden" name="$_" value="$core_params->{$_}" />), keys %$core_params;
  my $html_tag            = join '',   $self->doc_type, $self->html_tag;
  my $head                = join "\n", map $elements->{$_->[0]} || (), @{$self->head_order};  
  my $body_attrs          = join ' ',  map { sprintf '%s="%s"', $_, $self->{'body_attr'}{$_} } grep $self->{'body_attr'}{$_}, keys %{$self->{'body_attr'}};
  my $tabs                = $elements->{'tabs'} ? qq(<div class="tabs_holder print_hide">$elements->{'tabs'}</div>) : '';
  my $footer_id           = 'wide-footer';
  my $panel_type          = $self->can('panel_type') ? $self->panel_type : '';
  my $main_holder         = $panel_type ? qq(<div id="main_holder" class="js_panel">$panel_type) : '<div id="main_holder">';
  my $here = $ENV{'REQUEST_URI'};
  my $grch37_url = grch37_url($here);

  if ( ($self->isa('EnsEMBL::Web::Document::Page::Fluid') && $here !~ /\/Search\//)
        || ($self->isa('EnsEMBL::Web::Document::Page::Dynamic') && $here =~ /\/Info\//)
        || ($self->isa('EnsEMBL::Web::Document::Page::Static')
              && (($here =~ /Doxygen\/(\w|-)+/ && $here !~ /Doxygen\/index.html/) || $here !~ /^\/info/))
    ) {
    $main_class = 'widemain';
  }
  else {
    $main_class = 'main';
  }

#  my $main_class          = $self->isa('EnsEMBL::Web::Document::Page::Fluid') ? 'widemain' : 'main';
  my $nav;
  
  if ($self->include_navigation) {
    $nav = qq(<div id="page_nav" class="nav print_hide js_panel">
          $elements->{'navigation'}
          $elements->{'tool_buttons'}
          $elements->{'acknowledgements'}
          <p class="invisible">.</p>
        </div>
    );
    
    $footer_id = 'footer';
  }
  
  $html_tag = qq(<?xml version="1.0" encoding="utf-8"?>\n$html_tag) if $self->{'doc_type'} eq 'XHTML';
  return qq($html_tag
<head>
  $head
</head>
<body $body_attrs>
  <div id="min_width_container">
    <div id="min_width_holder">
<!-- redirection banner -->    
      <style>
        #redirect-banner {
          background-color: #3B5F75;
          padding: 8px 8px 12px 8px;
          color: white;
          text-align: center;
        }
        #redirect-banner a {
          color: #79C7E7;
        }
        .search_holder {
          top: 52px !important;
        }
      </style>
      <div id="redirect-banner">
        This website has been archived.
        The preferred way to access 1000 Genomes data is via the <a href="$grch37_url">Ensembl GRCh37</a> genome browser.
      </div>
<!-- /redirection banner -->         
<!-- 1kg -->
      <div id="header" class="print_hide">
      <div id="header_line" onclick="location.href='/'">1000 Genomes</div>
      <div id="tagline">A Deep Catalog of Human Genetic Variation</div>
      <div class="mh print_hide">
      <div class="search_holder print_hide">$elements->{'search_box'}</div>
      </div>
<!-- /1kg -->
      <div id="masthead" class="js_panel">
        <input type="hidden" class="panel_type" value="Masthead" />
<!-- 1kg -->
        <div class="content">
          $tabs
          <div style="float: right;padding-top:20px">
           <span style="padding: 0 10px;">
            <a href="/tools.html">Tools</a>
           </span>|
           <span style="padding: 0 10px;">
            <a href="/info/website/help/index.html">Help</a>
           </span>
          </div>
<!-- /1kg -->
        </div>
        $tabs
      </div>
      $main_holder
        $nav
        <div id="$main_class">
          $elements->{'breadcrumbs'}
          $elements->{'message'}
          $elements->{'content'}
        </div>
        <div id="$footer_id" class="column-wrapper">$elements->{'copyright'}$elements->{'footerlinks'}
          <p class="invisible">.</p>
        </div>
      </div>
    </div>
  </div>
  <form id="core_params" action="#" style="display:none">
    <fieldset>$core_params_html</fieldset>
  </form>
  <input type="hidden" id="species_path" name="species_path" value="$species_path" />
  <input type="hidden" id="species_common_name" name="species_common_name" value="$species_common_name" />
  $elements->{'modal'}
  $elements->{'body_javascript'}
</body>
</html>
);
}

1;
