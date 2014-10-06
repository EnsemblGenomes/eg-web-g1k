package EnsEMBL::Web::Document::HTML::HomeSearch;

### Generates the search form used on the main home page and species
### home pages, with sample search terms taken from ini files

use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Document::HTML);


sub new {
  return shift->SUPER::new(
    '_home_url' => $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_WEB_ROOT,
    '_default'  => $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEFAULT_SEARCHCODE,
  );
}

sub home_url { return $_[0]{'_home_url'};  }

sub default_search_code { return $_[0]{'_default'}; }

sub search_url {
    my $species = $_[0]->home_url.$ENV{'ENSEMBL_SPECIES'};
    $species = 'Homo_sapiens';
    return "/$species/Search/Results";
    return $species ? "/$species/psychic" : '/common/psychic';

}

sub render {
  my $self = shift;
  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $page_species = $ENV{'ENSEMBL_SPECIES'};
  $page_species = '' if $page_species eq 'common';

  my $species_name = '';
  $species_name = $species_defs->SPECIES_COMMON_NAME if $page_species;
  if( $species_name =~ /\./ ) {
    $species_name = '<i>'.$species_name.'</i>'
  }
  my $html = q(
<div class="center">);

  $html .= q(<h1 class="first">Search 1000 Genomes</h1>);

  $html .= sprintf q(
  <form action="%s" method="get"><div>
    <input type="hidden" name="site" value="%s" />
),
    $self->search_url, 
    'ensembl',
;


  my $input_size = 50;

   if (!$page_species) {
  }
  else {
    $html .= q(
    <label for="q">Search for</label>:);
  }

  $html .= qq(
    <input id="q" name="q" size="$input_size" value="" />
    <input type="submit" value="Go" class="input-submit" />);

  ## Examples
  my %sample_data = %{$species_defs->SAMPLE_DATA};
  my @examples;
  if (!$page_species && ! %sample_data) {
      @examples = ('gene PKH_030400', 'AL844502:1.1060087', 'synthetase');
  }
  else {
    @examples = ('gene '.$sample_data{'GENE_TEXT'}, 'Chromosome '.$sample_data{'LOCATION_TEXT'});
  }
  $html .= '
    <p>e.g. ' . join(' or ', map {'<strong>'.$_.'</strong>'} @examples) . '</p>';

  $html .= qq(
  </div></form>
</div>);

  return $html;

}

1;
