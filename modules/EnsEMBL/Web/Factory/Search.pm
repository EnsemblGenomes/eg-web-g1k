package EnsEMBL::Web::Factory::Search;
use strict;
use URI::Escape qw(uri_escape);
use base qw(EnsEMBL::Web::Factory);

sub search_ALL {
  my( $self, $species ) = @_;
  #  1kg first look to see if the query describes a seq region

  return if $self->redirect_if_seq_region;
  # /1kg 
  my $package_space = __PACKAGE__.'::';

  no strict 'refs';
  # This gets all the methods in this package ( begining with search and excluding search_all ) 
  my @methods = map { /(search_\w+)/ && $1 ne 'search_ALL' ? $1 : () } keys %$package_space;

   ## Filter by configured indices
  my $SD = EnsEMBL::Web::SpeciesDefs->new();
  
  # These are the methods for the current species that we want to try and run
  my @idxs = @{$SD->ENSEMBL_SEARCH_IDXS};

  # valid methods will contain the methods that we want to run and that are contained in this package
  my @valid_methods;

  if (scalar(@idxs) > 0) {
    foreach my $m (@methods) {
      (my $index = $m) =~ s/search_//;
      foreach my $i (@idxs) {
        if (lc($index) eq lc($i)) {
          push @valid_methods, $m;
          last;
        }
      }
    }
  }
  else {
    @valid_methods = @methods;
  }

  my @ALL = ();

  foreach my $method (@valid_methods) {
    $self->{_result_count} = 0;
    $self->{_results}      = [];
    $self->{to_return} = 50;
    if( $self->can($method) ) {
      $self->$method;
    }
  }
  return @ALL;
}

# check if the query describes a seq region, and if so, redirect there
# the logic for this sub originally came from psychic - nickl
sub redirect_if_seq_region {
  my( $self) = @_;
  my $species = $self->species;
  my $query = $self->param('q');
  return unless $species and $query;

  my ($index, $url);

  if ($query =~ s/^(chromosome|chr)\s+//i) {
    $index = 'Chromosome';
  } elsif ($query =~ s/^(contig|clone|supercontig|region)//i) {
    $index = 'Sequence';
  }
  
  my $species_path = $self->species_defs->species_path($species) || "/$species";
  
  ## match any of the following:
  if ($query =~ /^\s*([-\.\w]+)[: ]([\d\.]+?[MKG]?)( |-|\.\.|,)([\d\.]+?[MKG]?)$/i || $query =~ /^\s*([-\.\w]+)[: ]([\d,]+[MKG]?)( |\.\.|-)([\d,]+[MKG]?)$/i) {
    my ($seq_region_name, $start, $end) = ($1, $2, $4);
    $seq_region_name =~ s/chr//;
    $start = $self->evaluate_bp($start);
    $end   = $self->evaluate_bp($end);
    
    ($end, $start) = ($start, $end) if $end < $start;
       
    my $script = 'Location/View';
    $script    = 'Location/Overview' if $end - $start > 1000000;
    
    if ($index eq 'Chromosome' and (!$start or !$end)) {
      $url  = "$species_path/Location/Chromosome?r=$seq_region_name";
    } else {
      $url  = "$species_path/$script?r=" . uri_escape($seq_region_name . ($start && $end ? ":$start-$end" : ''));
    }
  } else {
    if ($index eq 'Chromosome') {
      $url  = "$species_path/Location/Chromosome?r=$query";
    } elsif ($index eq 'Sequence') {
      $url  = "$species_path/Location/View?r=$query";
    }
  }

  $self->hub->redirect($url) if $url;
  return $url;
}

sub search_SEQUENCE {
  my $self = shift;
  my $dbh = $self->database('core');
  return unless $dbh;  
  
  my $species = $self->species;
  my $species_path = $self->species_path;
  
  $self->_fetch_results( 
    [ 'core', 'Sequence',
      "select count(*) from seq_region where name [[COMP]] '[[KEY]]'",
      "select sr.name, cs.name, 1, length, sr.seq_region_id from seq_region as sr, coord_system as cs where cs.coord_system_id = sr.coord_system_id and sr.name [[COMP]] '[[KEY]]'" ],
    [ 'core', 'Sequence',
      "select count(distinct misc_feature_id) from misc_attrib join attrib_type as at using(attrib_type_id) where at.code in ( 'name','clone_name','embl_acc','synonym','sanger_project') 
       and value [[COMP]] '[[KEY]]'", # Eagle change, added at.code in count so that it matches the number of results in the actual search query below. 
      "select ma.value, group_concat( distinct ms.name ), seq_region_start, seq_region_end, seq_region_id
         from misc_set as ms, misc_feature_misc_set as mfms,
              misc_feature as mf, misc_attrib as ma, 
              attrib_type as at,
              (
                select distinct ma2.misc_feature_id
                  from misc_attrib as ma2, attrib_type as at2
                 where ma2.attrib_type_id = at2.attrib_type_id and
                       at2.code in ('name','clone_name','embl_acc','synonym','sanger_project') and
                       ma2.value [[COMP]] '[[KEY]]'
              ) as tt
        where ma.misc_feature_id   = mf.misc_feature_id and 
              mfms.misc_feature_id = mf.misc_feature_id and
              mfms.misc_set_id     = ms.misc_set_id     and
              ma.misc_feature_id   = tt.misc_feature_id and
              ma.attrib_type_id    = at.attrib_type_id  and
              at.code in ('name','clone_name','embl_acc','synonym','sanger_project')
        group by mf.misc_feature_id" ]
  );


  my $sa = $dbh->get_SliceAdaptor(); 

  foreach ( @{$self->{_results}} ) {
    my $KEY =  $_->[2] < 1e6 ? 'contigview' : 'cytoview';
    $KEY = 'cytoview' if $self->species_defs->NO_SEQUENCE;
    # The new link format is usually 'r=chr_name:start-end'
    my $slice = $sa->fetch_by_seq_region_id($_->[4], $_->[2], $_->[3] ); 

    $_ = {
      'URL'       => "$species_path/Location/View?r=" . $slice->seq_region_name . ":" . $slice->start . "-" . $slice->end,   # v58 format
      'URL_extra' => [ 'Region overview', 'View region overview', "$species_path/Location/Overview?r=" . $slice->seq_region_name . ":" . $slice->start . "-" . $slice->end ],
      'idx'       => 'Sequence',
      'subtype'   => ucfirst( $_->[1] ),
      'ID'        => $_->[0],
      'desc'      => '',
      'species'   => $species
    };
  }
  @{$self->{_results}} ? $self->{'results'}{ 'Sequence' }  = [ $self->{_results}, $self->{_result_count} ] : '';
}

sub search_GENE {
  my $self = shift;
  my $species = $self->species;
  my $species_path = $self->species_path;
  my @databases = ('core');
  push @databases, 'vega' if $self->species_defs->databases->{'DATABASE_VEGA'};
  push @databases, 'est' if $self->species_defs->databases->{'DATABASE_OTHERFEATURES'};
  foreach my $db (@databases) {
  $self->_fetch_results(

      # Search Gene, Transcript, Translation stable ids.. 
    [ $db, 'Gene',
      "select count(*) from gene WHERE stable_id [[COMP]] '[[KEY]]'",
      "SELECT g.stable_id, g.description, '$db', 'Gene', 'gene' FROM gene as g WHERE g.stable_id [[COMP]] '[[KEY]]'" ],
# EG 1kg add search against description
    [ $db, 'Gene',
      "select count(*) from gene WHERE match(description) against('+[[FULLTEXTKEY]]' IN BOOLEAN MODE)",
      "SELECT g.stable_id, g.description, '$db', 'Gene', 'gene' FROM gene as g WHERE match(g.description) against('+[[FULLTEXTKEY]]' IN BOOLEAN MODE)" ],
# /EG 1kg add search against description
    [ $db, 'Gene',
      "select count(*) from transcript WHERE stable_id [[COMP]] '[[KEY]]'",
      "SELECT g.stable_id, g.description, '$db', 'Transcript', 'transcript' FROM transcript as g WHERE g.stable_id [[COMP]] '[[KEY]]'" ],
    [ $db, 'Gene',
      "select count(*) from translation WHERE stable_id [[COMP]] '[[KEY]]'",
      "SELECT g.stable_id, x.description, '$db', 'Transcript', 'peptide' FROM translation as g, transcript as x WHERE g.transcript_id = x.transcript_id and g.stable_id [[COMP]] '[[KEY]]'" ],

      # search by primary chr

    [ $db, 'Gene',
      "select count(*) from object_xref as ox, xref as x,gene as g, seq_region as sr  where g.gene_id = ox.ensembl_id and  ox.ensembl_object_type = 'Gene' and ox.xref_id = x.xref_id and sr.seq_region_id=g.seq_region_id and x.dbprimary_acc [[COMP]] '[[KEY]]' order by length(name);",
      "SELECT g.stable_id, concat( display_label, ' - ', g.description ), '$db', 'Gene', 'gene' from gene as g, object_xref as ox, xref as x, seq_region as sr
        where g.gene_id = ox.ensembl_id and ox.ensembl_object_type = 'Gene' and
              ox.xref_id = x.xref_id and x.dbprimary_acc = '[[KEY]]' and sr.seq_region_id=g.seq_region_id order by length(name)" ],

      # search dbprimary_acc ( xref) of type 'Gene'
    [ $db, 'Gene',
      "select count( * ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Gene' and ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'",
      "SELECT g.stable_id, concat( display_label, ' - ', g.description ), '$db', 'Gene', 'gene' from gene as g, object_xref as ox, xref as x
        where g.gene_id = ox.ensembl_id and ox.ensembl_object_type = 'Gene' and
              ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'" ],
      # search display_label(xref) of type 'Gene' where NOT match dbprimary_acc !! - could these two statements be done better as one using 'OR' ?? !! 
      # Eagle change  - added 2 x distinct clauses to prevent returning duplicate stable ids caused by multiple xref entries for one gene
    [ $db, 'Gene',
      "select count( distinct(ensembl_id) ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Gene' and ox.xref_id = x.xref_id and
              x.display_label [[COMP]] '[[KEY]]' and not(x.dbprimary_acc [[COMP]] '[[KEY]]')",
      "SELECT distinct(g.stable_id), concat( display_label, ' - ', g.description ), '$db', 'Gene', 'gene' from gene as g, object_xref as ox, xref as x
        where g.gene_id = ox.ensembl_id and ox.ensembl_object_type = 'Gene' and
              ox.xref_id = x.xref_id and x.display_label [[COMP]] '[[KEY]]' and
              not(x.dbprimary_acc [[COMP]] '[[KEY]]')" ],

      # Eagle added this to search gene.description.  Could really do with an index on description field, but still works. 
      [ $db, 'Gene', 
      "SELECT count(distinct(g.gene_id)) from  gene as g, object_xref as ox, xref as x where g.gene_id = ox.ensembl_id and ox.ensembl_object_type = 'Gene' 
           and ox.xref_id = x.xref_id and match(g.description) against('+[[FULLTEXTKEY]]' IN BOOLEAN MODE) and not(x.display_label [[COMP]] '[[KEY]]' ) and not(x.dbprimary_acc [[COMP]] '[[KEY]]')",
      "SELECT distinct(g.stable_id), concat( display_label, ' - ', g.description ), 'core', 'Gene', 'gene' from gene as g, object_xref as ox, xref as x
         where g.gene_id = ox.ensembl_id and ox.ensembl_object_type = 'Gene' and ox.xref_id = x.xref_id 
         and match(g.description) against('+[[FULLTEXTKEY]]' IN BOOLEAN MODE) and not(x.display_label [[COMP]] '[[KEY]]' ) and not(x.dbprimary_acc [[COMP]] '[[KEY]]')" ],

      # Eagle added this to search external_synonym.  Could really do with an index on description field, but still works. 
      [ $db, 'Gene', 
      "SELECT count(distinct(g.gene_id)) from  gene as g, object_xref as ox, xref as x, external_synonym as es  where g.gene_id = ox.ensembl_id and ox.ensembl_object_type = 'Gene' 
           and ox.xref_id = x.xref_id and es.xref_id = x.xref_id and es.synonym [[COMP]] '[[KEY]]' and not(match(g.description) against('+[[FULLTEXTKEY]]' IN BOOLEAN MODE)) and not(x.display_label [[COMP]] '[[KEY]]' ) and not(x.dbprimary_acc [[COMP]] '[[KEY]]')",
      "SELECT distinct(g.stable_id), concat( display_label, ' - ', g.description ), 'core', 'Gene', 'gene' from gene as g, object_xref as ox, xref as x, external_synonym as es
         where g.gene_id = ox.ensembl_id and ox.ensembl_object_type = 'Gene' and ox.xref_id = x.xref_id  and es.xref_id = x.xref_id
         and es.synonym [[COMP]] '[[KEY]]' and not( match(g.description) against('+[[FULLTEXTKEY]]' IN BOOLEAN MODE)) and not(x.display_label [[COMP]] '[[KEY]]' ) and not(x.dbprimary_acc [[COMP]] '[[KEY]]')" ],


      # search dbprimary_acc ( xref) of type 'Transcript' - this could possibly be combined with Gene above if we return the object_xref.ensembl_object_type rather than the fixed 'Gene' or 'Transcript' 
      # to make things simpler and perhaps faster
    [ $db, 'Gene',
      "select count( * ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Transcript' and ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'",
      "SELECT g.stable_id, concat( display_label, ' - ', g.description ), '$db', 'Transcript', 'transcript' from transcript as g, object_xref as ox, xref as x
        where g.transcript_id = ox.ensembl_id and ox.ensembl_object_type = 'Transcript' and
              ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'" ],
      # search display_label(xref) of type 'Transcript' where NOT match dbprimary_acc !! - could these two statements be done better as one using 'OR' ?? !! -- See also comment about combining with Genes above
    [ $db, 'Gene',
      "select count( distinct(ensembl_id) ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Transcript' and ox.xref_id = x.xref_id and
              x.display_label [[COMP]] '[[KEY]]' and not(x.dbprimary_acc [[COMP]] '[[KEY]]')",
      "SELECT distinct(g.stable_id), concat( display_label, ' - ', g.description ), '$db', 'Transcript', 'transcript' from transcript as g, object_xref as ox, xref as x
        where g.transcript_id = ox.ensembl_id and ox.ensembl_object_type = 'Transcript' and
              ox.xref_id = x.xref_id and x.display_label [[COMP]] '[[KEY]]' and
              not(x.dbprimary_acc [[COMP]] '[[KEY]]')" ],


      ## Same again but for Translation - see above
    [ $db, 'Gene',
      "select count( * ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Translation' and ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'",
      "SELECT g.stable_id, concat( display_label ), '$db', 'Transcript', 'peptide' from translation as g, object_xref as ox, xref as x
        where g.translation_id = ox.ensembl_id and ox.ensembl_object_type = 'Translation' and 
              ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'" ],
    [ $db, 'Gene',
      "select count( distinct(ensembl_id) ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Translation' and ox.xref_id = x.xref_id and
              x.display_label [[COMP]] '[[KEY]]' and not(x.dbprimary_acc [[COMP]] '[[KEY]]')",
      "SELECT distinct(g.stable_id), concat( display_label ), '$db', 'Transcript', 'peptide' from translation as g, object_xref as ox, xref as x
        where g.translation_id = ox.ensembl_id and ox.ensembl_object_type = 'Translation' and 
              ox.xref_id = x.xref_id and x.display_label [[COMP]] '[[KEY]]' and
              not(x.dbprimary_acc [[COMP]] '[[KEY]]')" ]
  );
  }

  ## Remove duplicate hits
  my (%gene_id, @unique);

  foreach ( @{$self->{_results}} ) {

      next if $gene_id{$_->[0]};
      $gene_id{$_->[0]}++;

      # $_->[0] - Ensembl ID/name
      # $_->[1] - description 
      # $_->[2] - db name 
      # $_->[3] - Page type, eg Gene/Transcript 
      # $_->[4] - Page type, eg gene/transcript

      my $KEY = 'Location'; 
      $KEY = 'cytoview' if $self->species_defs->NO_SEQUENCE;

      my $page_name_long = $_->[4]; 
      (my $page_name_short = $page_name_long )  =~ s/^(\w).*/$1/; # first letter only for short format. 

      my $summary = 'Summary';  # Summary is used in URL for Gene and Transcript pages, but not for protein
      $summary = 'ProteinSummary' if $page_name_short eq 'p'; 

      push @unique, {
        'URL'       => "$species_path/$_->[3]/$summary?$page_name_short=$_->[0];db=$_->[2]",
        'URL_extra' => [ 'Region in detail', 'View marker in LocationView', "$species_path/$KEY/View?$page_name_long=$_->[0];db=$_->[2]" ],
        'idx'       => 'Gene',
        'subtype'   => ucfirst($_->[4]),
        'ID'        => $_->[0],
        'desc'      => $_->[1],
        'species'   => $species
      };

      # 1kg Add "Variations in gene" link:
      if ($_->[4] =~ /gene/) {
        push @unique, {
          'URL'       => "$species_path/Gene/Variation_Gene/Table?$page_name_short=$_->[0];db=$_->[2]",
          'URL_extra' => [ 'Variations in gene', 'Variations in gene', "$species_path/Gene/Variation_Gene/Table?$page_name_short=$_->[0];db=$_->[2]" ],
          'idx'       => 'Gene',
          'subtype'   => 'Variations in gene '.$_->[0],
          'ID'        => '',
          'desc'      => '',
          'species'   => $species
        };
        $self->{_result_count}++;
      }
      # 1kg
  }
  $self->{'results'}{'Gene'} = [ \@unique, $self->{_result_count} ];
}

sub search_SV {
  my $self = shift;
  my $species = $self->species;
  my $species_path = $self->species_path;
  
  $self->_fetch_results(
   [ 'variation' , 'SV',
     "select count(*) from structural_variation as sv where variation_name = '[[KEY]]'",
     "select s.name as source, sv.variation_name
        from source as s, structural_variation as sv
        where s.source_id = sv.source_id and sv.variation_name = '[[KEY]]'"
   ]);

  foreach ( @{$self->{_results}} ) {
    $_ = {
      'idx'     => 'SV', 
      'subtype' => "$_->[0] SV",
      'ID'      => $_->[1],
      'URL'     => "$species_path/StructuralVariation/Summary?source=$_->[0];sv=$_->[1]", # v58 link format
      'desc'    => '',
      'species' => $species
    };
  }
  @{$self->{_results}} ? $self->{'results'}{'SV'} = [ $self->{_results}, $self->{_result_count} ] : '';
}

## Result hash contains the following fields...
## 
## { 'URL' => ?, 'type' => ?, 'ID' => ?, 'desc' => ?, 'idx' => ?, 'species' => ?, 'subtype' =>, 'URL_extra' => [] } 

sub search_PHENOTYPE {
  my $self = shift;

  my $species = $self->species;
  my $species_path = $self->species_path;

  $self->_fetch_results(
   [ 'variation' , 'PH',
      '',
      "select pf.object_id,p.phenotype_id,p.description 
        from phenotype_feature pf
        left join  phenotype p using(phenotype_id) where p.description [[COMP]] '[[KEY]]' and pf.type = 'Gene' group by phenotype_id"
   ]);

  my $count = 0;
  foreach ( @{$self->{_results}} ) {
    $_ = {
      'idx'     => 'PH',
      'subtype' => "$_->[0] PH",
      'ID'      => $_->[1],
      'URL'     => "$species_path/Phenotype/Locations?ph=$_->[1]", # v58 link format
      'desc'    => $_->[2],
      'species' => $species
    };
    $count++;
  }
  @{$self->{_results}} ? $self->{'results'}{'PH'} = [ $self->{_results}, $count ] : '';

}

sub _fetch_results {
  my $self = shift;
  my @terms = $self->terms();
  foreach my $query (@_) {
    my( $db, $subtype, $count_SQL, $search_SQL ) = @$query;

    foreach my $term (@terms ) {
      my $results = $self->_fetch( $db, $search_SQL, $term->[0], $term->[1], $self->{to_return} );

      push @{$self->{_results}}, @$results;
    }
  }
}

sub _fetch {
  my( $self, $db, $search_SQL, $comparator, $kw, $limit ) = @_;
  my $dbh = $self->database( $db );

  return [] unless $dbh;
  my $full_kw = $kw;
  $full_kw =~ s/\%/\*/g;

  if (($search_SQL =~ /phenotype/ || $search_SQL =~ /gene/) && $search_SQL !~ /order by length/){
    $comparator = 'like';
    $kw = '%'.$kw.'%';
  }
  $kw = $dbh->dbc->db_handle->quote($kw);
  (my $t = $search_SQL ) =~ s/'\[\[KEY\]\]'/$kw/g;
  $t =~ s/\[\[COMP\]\]/$comparator/g;
  $t =~ s/\[\[FULLTEXTKEY\]\]/$full_kw/g;
  my $res = $dbh->dbc->db_handle->selectall_arrayref( "$t limit $limit" ) || [];

  return $res;
}


sub search_MARKER {
  my $self = shift;
  my $species = $self->species;
  my $species_path = $self->species_path;

  $self->_fetch_results( 
    [ 'core', 'Marker',
      "select count(distinct name) from marker_synonym where name [[COMP]] '[[KEY]]'",
      "select distinct name from marker_synonym where name [[COMP]] '[[KEY]]'" ]
  );

  foreach ( @{$self->{_results}} ) {
    my $KEY =  $_->[2] < 1e6 ? 'contigview' : 'cytoview';
    $KEY = 'cytoview' if $self->species_defs->NO_SEQUENCE;
    $_ = {
      'URL'       => "$species_path/Location/Marker?m=$_->[0]", # v58 format
      'idx'       => 'Marker',
      'subtype'   => 'Marker',
      'ID'        => $_->[0],
      'desc'      => '',
      'species'   => $species
    };
  }
  @{$self->{_results}} ? $self->{'results'}{'Marker'} = [ $self->{_results}, $self->{_result_count} ] : '';
}


sub search_OLIGOPROBE {
  my $self = shift;
  my $species = $self->species;
  my $species_path = $self->species_path;
  
  $self->_fetch_results(
    [ 'funcgen', 'OligoProbe',
      "select count(distinct name) from probe_set where name [[COMP]] '[[KEY]]'",
       "select ps.name, group_concat(distinct a.name order by a.name separator ' '), vendor from probe_set ps, array a, array_chip ac, probe p
     where ps.name [[COMP]] '[[KEY]]' AND a.array_id = ac.array_id AND ac.array_chip_id = p.array_chip_id AND p.probe_set_id = ps.probe_set_id group by ps.name"],
  );
  foreach ( @{$self->{_results}} ) {
    $_ = {
      'URL'       => "$species_path/Location/Genome?ftype=ProbeFeature;fdb=funcgen;ptype=pset;id=$_->[0]", # v58 format
      'idx'       => 'OligoProbe',
      'subtype'   => $_->[2] . ' Probe set',
      'ID'        => $_->[0],
      'desc'      => 'Is a member of the following arrays: '.$_->[1],
      'species'   => $species
    };
  }
  @{$self->{_results}} ? $self->{'results'}{ 'OligoProbe' }  = [ $self->{_results}, $self->{_result_count} ] : '';
}

sub search_SNP {
  my $self = shift;
  my $species = $self->species;
  my $species_path = $self->species_path;
  
  $self->_fetch_results(
   [ 'variation' , 'SNP',
     "select count(*) from variation as v where name = '[[KEY]]'",
   "select s.name as source, v.name
      from source as s, variation as v
     where s.source_id = v.source_id and v.name = '[[KEY]]'" ],
   [ 'variation', 'SNP',
     "select count(*) from variation as v, variation_synonym as vs
       where v.variation_id = vs.variation_id and vs.name = '[[KEY]]'",
   "select s.name as source, v.name
      from source as s, variation as v, variation_synonym as vs
     where s.source_id = v.source_id and v.variation_id = vs.variation_id and vs.name = '[[KEY]]'"
  ]);
  
  foreach ( @{$self->{_results}} ) {
    $_ = {
      'idx'     => 'SNP', 
      'subtype' => "$_->[0] SNP",
      'ID'      => $_->[1],
      'URL'     => "$species_path/Variation/Summary?source=$_->[0];v=$_->[1]", # v58 link format
      'desc'    => '',
      'species' => $species
    };
  }
  @{$self->{_results}} ? $self->{'results'}{'SNP'} = [ $self->{_results}, $self->{_result_count} ] : '';
}

sub search_FAMILY {
  my( $self, $species ) = @_;
  my $species = $self->species;
  my $species_path = $self->species_path;
  
  $self->_fetch_results(
    [ 'compara', 'Family',
      "select count(*) from family where stable_id [[COMP]] '[[KEY]]'",
      "select stable_id, description FROM family WHERE stable_id  [[COMP]] '[[KEY]]'" ],
    [ 'compara', 'Family',
      "select count(*) from family where description [[COMP]] '[[KEY]]'",
      "select stable_id, description FROM family WHERE description [[COMP]] '[[KEY]]'" ] );
  foreach ( @{$self->{_results}} ) {
    $_ = {
      'URL'       => "$species_path/Gene/Family/Genes?family=$_->[0]", # Updated to current ( v58 ) link format
      'idx'       => 'Family',
      'subtype'   => 'Family',
      'ID'        => $_->[0],
      'desc'      => $_->[1],
      'species'   => $species
    };
  }
  @{$self->{_results}} ? $self->{'results'}{ 'Family' }  = [ $self->{_results}, $self->{_result_count} ] :'';
}

sub search_DOMAIN {
  my $self = shift;
  my $species = $self->species;
  my $species_path = $self->species_path;
  
  $self->_fetch_results(
    [ 'core', 'Domain',
      "select count(*) from xref as x, external_db as e 
        where e.external_db_id = x.external_db_id and e.db_name = 'Interpro' and x.dbprimary_acc [[COMP]] '[[KEY]]'", # Eagle change, added Interpro to the count too 
      "select x.dbprimary_acc, x.description
         FROM xref as x, external_db as e
        WHERE e.db_name = 'Interpro' and e.external_db_id = x.external_db_id and
              x.dbprimary_acc [[COMP]] '[[KEY]]'" ],
    [ 'core', 'Domain',
      "select count(*) from xref as x, external_db as e 
        where e.external_db_id = x.external_db_id and e.db_name = 'Interpro' and x.description [[COMP]] '[[KEY]]'",# Eagle change, added Interpro to the count too, changed dbprimary_acc to x.description to match search
                                                                                                                   ## The description search will only find the word if its at the begining of the line, so not very good. 
      "SELECT x.dbprimary_acc, x.description                                       
         FROM xref as x, external_db as e
        WHERE e.db_name = 'Interpro' and e.external_db_id = x.external_db_id and
              x.description [[COMP]] '[[KEY]]'" ],
  );
  foreach ( @{$self->{_results}} ) {
    $_ = {
      'URL'       => "$species_path/Location/Genome?ftype=Domain;id=$_->[0]", # updated to current ( v58 ) link format
      'idx'       => 'Domain',
      'subtype'   => 'Domain',
      'ID'        => $_->[0],
      'desc'      => $_->[1],
      'species'   => $species
    };
  }
  @{$self->{_results}} ? $self->{'results'}{'Domain'} = [ $self->{_results}, $self->{_result_count} ] : '';
}

sub search_GENOMICALIGNMENT {
  my $self = shift;
  my $species = $self->species;
  my $species_path = $self->species_path;
  
  $self->_fetch_results(
    [
      'core', 'DNA',
      "select count(distinct analysis_id, hit_name) from dna_align_feature where hit_name [[COMP]] '[[KEY]]'",
      "select a.logic_name, f.hit_name, 'Dna', 'core',count(*)  from dna_align_feature as f, analysis as a where a.analysis_id = f.analysis_id and f.hit_name [[COMP]] '[[KEY]]' group by a.logic_name, f.hit_name"
    ],
    [
      'core', 'Protein',
      "select count(distinct analysis_id, hit_name) from protein_align_feature where hit_name [[COMP]] '[[KEY]]'",
      "select a.logic_name, f.hit_name, 'Protein', 'core',count(*) from protein_align_feature as f, analysis as a where a.analysis_id = f.analysis_id and f.hit_name [[COMP]] '[[KEY]]' group by a.logic_name, f.hit_name"
    ],
    [
      'vega', 'DNA',
      "select count(distinct analysis_id, hit_name) from dna_align_feature where hit_name [[COMP]] '[[KEY]]'",
      "select a.logic_name, f.hit_name, 'Dna', 'vega', count(*) from dna_align_feature as f, analysis as a where a.analysis_id = f.analysis_id and f.hit_name [[COMP]] '[[KEY]]' group by a.logic_name, f.hit_name"
    ],
    [
      'est', 'DNA',
      "select count(distinct analysis_id, hit_name) from dna_align_feature where hit_name [[COMP]] '[[KEY]]'",
      "select a.logic_name, f.hit_name, 'Dna', 'est', count(*) from dna_align_feature as f, analysis as a where a.analysis_id = f.analysis_id and f.hit_name [[COMP]] '[[KEY]]' group by a.logic_name, f.hit_name"
    ]
  );
  foreach ( @{$self->{_results}} ) {
    $_ = {
      'idx'     => 'GenomicAlignment',
      'subtype' => "$_->[0] $_->[2] alignment feature",
      'ID'      => $_->[1],
      'URL'     => "$species_path/Location/Genome?ftype=$_->[2]AlignFeature;db=$_->[3];id=$_->[1]", # v58 format
      'desc'    => "This $_->[2] alignment feature hits the genome in $_->[4] place(s).",
      'species' => $species
    };
  }
# Eagle change, this should really match the value in the Species DEFs file, ie. GenomicAlignment not GenomicAlignments
# + the others are all singular so keep this consistent
  @{$self->{_results}} ? $self->{'results'}{'GenomicAlignment'} = [ $self->{_results}, $self->{_result_count} ] : '';
}

1;
