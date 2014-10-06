#$Id: Variation.pm,v 1.1 2012-12-10 16:25:19 ek3 Exp $
package EnsEMBL::Web::Object::Variation;

### NAME: EnsEMBL::Web::Object::Variation
### Wrapper around a Bio::EnsEMBL::Variation 
### or EnsEMBL::Web::VariationFeature object  

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk
### Contains a lot of functionality not directly related to
### manipulation of the underlying API object 

### DESCRIPTION

# FIXME Are these actually used anywhere???
# Is there a reason they come before 'use strict'?


use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code variation_class);
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump); 

use strict;
use warnings;
no warnings "uninitialized";
use Vcf;

use EnsEMBL::Web::Cache;
use Data::Dumper;

use base qw(EnsEMBL::Web::Object);

our $MEMD = new EnsEMBL::Web::Cache;

sub availability {
  my $self = shift;
  
  if (!$self->{'_availability'}) {
    my $availability = $self->_availability;
    my $obj = $self->Obj;
    
    if ($obj->isa('Bio::EnsEMBL::Variation::Variation')) {
      my $counts = $self->counts;
      
      $availability->{'variation'} = 1;
# 1kg      
      $availability->{"has_$_"}  = $counts->{$_} for qw(transcripts populations individuals individuals1kg ega alignments ldpops);
# /1kg      
      $availability->{'is_somatic'}  = $obj->is_somatic;
      $availability->{'not_somatic'} = !$obj->is_somatic;
    }
    
    $self->{'_availability'} = $availability;
  }
  
  return $self->{'_availability'};
}

sub counts {
  my $self = shift;
  my $obj  = $self->Obj;
  my $hub  = $self->hub;

  return {} unless $obj->isa('Bio::EnsEMBL::Variation::Variation');

  my $vf  = $hub->param('vf');
  my $key = sprintf '::Counts::Variation::%s::%s::%s::', $self->species, $hub->param('vdb'), $hub->param('v');
  $key   .= $vf . '::' if $vf;

  my $counts = $self->{'_counts'};
  $counts ||= $MEMD->get($key) if $MEMD;

  unless ($counts) {
    $counts = {};
    $counts->{'transcripts'} = $self->count_transcripts;
    $counts->{'populations'} = $self->count_populations;
    $counts->{'individuals'} = $self->count_individuals;
    $counts->{'ega'}         = $self->count_ega;
    $counts->{'ldpops'}      = $self->count_ldpops;
    $counts->{'alignments'}  = $self->count_alignments->{'multi'};
# 1kg
    $counts->{'individuals1kg'} = $self->count_individuals('1000genomes');
    $MEMD->set($key, $counts, undef, 'COUNTS') if $MEMD;
    $self->{'_counts'} = $counts;
  }
  
  return $counts;
}

sub count_individuals {
  my $self = shift;
  my $dbh  = $self->database('variation')->get_VariationAdaptor->dbc->db_handle;
  my $var  = $self->Obj;
  my $src = shift;
# 1kg wait for the next release
  if ($src eq '1000genomes') {
    return $self->g1k_get_count();
  }
# /1kg
  # somatic variations don't have genotypes currently
  return 0 if $var->is_somatic;
  
  my $gts = $var->get_all_IndividualGenotypes();
  
  return defined($gts) ? scalar @$gts : 0;
}

sub g1k_get_count {
  my $self = shift;  
  
  my %mappings = %{$self->variation_feature_mapping};
  my $count = 0;
  
  foreach (sort { $mappings{$a}->{'Chr'} cmp $mappings{$b}->{'Chr'} || $mappings{$a}->{'start'} <=> $mappings{$b}->{'start'}} keys %mappings) {
      my $chr = $mappings{$_}{'Chr'}; 
      my $start  = $mappings{$_}{'start'};
      my $end    = $mappings{$_}{'end'};
      my $str    = $mappings{$_}{'strand'};
  
      my $fname = "ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20110521/ALL.chr${chr}.phase1_release_v3.20101123.snps_indels_svs.genotypes.vcf.gz";
#     my $fname = "ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20110521/ALL.chr${chr}.phase1_integrated_calls.20101123.snps_indels_svs.genotypes.vcf.gz";
 
#      warn $self->alleles, " * ", $start,  " * ", $str;

# if it is an insertion then we need to swap coordinates before quering the vcf file 
      if ($start > $end) {
    ($start, $end) = ($end, $start);
      }

      my $vcf;
      eval {
        $vcf = Vcf->new(file=>$fname, region=>"$chr:$start-$end",  print_header=>1, silent=>1); #print_header allows print sample name rather than column index
        $vcf->parse_header();

        while (my $x=$vcf->next_data_hash()) {
# there could be overlapping variations
# so we need to filter out the irrelevant ones
#     foreach my $k (sort keys %$x) {
#   warn "$k => $x->{$k} \n";
#     }
      warn '-'x30, "\n";
      next unless $x->{POS} eq $start;
      $count += scalar(keys %{$x->{gtypes}});
        } 
      };
  }

  return $count;
}

my %gMap = (
    1 => 'Male',
    2 => 'Female'
);

my %pMap = (
  'GBR' => 'EUR',
  'FIN' => 'EUR',
  'CHS' => 'ASN',
  'PUR' => 'AMR',
  'CLM' => 'AMR',
  'IBS' => 'EUR',
  'CEU' => 'EUR',
  'YRI' => 'AFR',
  'CHB' => 'ASN',
  'JPT' => 'ASN',
  'LWK' => 'AFR',
  'ASW' => 'AFR',
  'MXL' => 'AMR',
  'TSI' => 'EUR',
);

sub g1k_get_genotypes {
  my $self = shift;
  my $hub          = $self->hub;
    
  my $sample_panel = 'ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/working/20111108_samples_pedigree/G1K_samples_20111108.ped';
  
  my $ua = LWP::UserAgent->new;
  $ua->timeout(10);
  $ua->env_proxy;
    
  my $response = $ua->get($sample_panel);
  return "error:Sample-Population Mapping file has no content." unless $response->is_success;

  my @content = split /\n/, $response->content(); #$response->decoded_content;
  my %sample_info;   
  my $scount = 0;
  my $thash = {};
  foreach (@content) {
     chomp;
     s/^\s+|\s+$//g;
     my ($famid, $sample, $father, $mother, $sex, $phenotype, $population, @rest) = split(/\t/, $_);
     $sample_info{$sample}->{Father} = $father;
     $sample_info{$sample}->{Mother} = $mother;
     $sample_info{$sample}->{Gender} = $gMap{$sex} || 'Unknown';
     $sample_info{$sample}->{Population} = '1000GENOMES:'.$pMap{$population} || $population;
     $sample_info{$sample}->{Description} = "$population sample";
     $sample_info{$father} ||= {};
     $sample_info{$mother} ||= {};
     push @{$sample_info{$father}->{Children}}, $sample;
     push @{$sample_info{$mother}->{Children}}, $sample;
  }

#warn "PED is done \n";
  my %mappings = %{$self->variation_feature_mapping};
  my %data;
  my $ind = 1;
  
  foreach (sort { $mappings{$a}->{'Chr'} cmp $mappings{$b}->{'Chr'} || $mappings{$a}->{'start'} <=> $mappings{$b}->{'start'}} keys %mappings) {
      my $chr = $mappings{$_}{'Chr'}; 
      my $start  = $mappings{$_}{'start'};
      my $end    = $mappings{$_}{'end'};
      my $str    = $mappings{$_}{'strand'};
      my $ins = 0;
# if it is an insertion then we need to swap coordinates before quering the vcf file 
      if ($start > $end) {
    ($start, $end) = ($end, $start);
    $ins = 1;
      }

#     my $fname = "ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20110521/ALL.chr${chr}.phase1_integrated_calls.20101123.snps_indels_svs.genotypes.vcf.gz";
      my $fname = "ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20110521/ALL.chr${chr}.phase1_release_v3.20101123.snps_indels_svs.genotypes.vcf.gz";
      my $vcf;
      eval {
        $vcf = Vcf->new(file=>$fname, region=>"$chr:$start-$end",  print_header=>1, silent=>1); #print_header allows print sample name rather than column index
      };

      return "error:Error reading VCF file" if $@ || (!$vcf);

      $vcf->parse_header(); 

      my $pop_hash = {};
      $pop_hash->{'1000GENOMES:ALL'} = 1;

      while (my $x=$vcf->next_data_hash()) {
#          warn Dumper $x;
         
# there could be overlapping variations
# so we need to filter out the irrelevant ones ( which have different start position ) 
      next unless $x->{POS} eq $start;
          foreach my $sample (keys %{$x->{gtypes} || {}}) {
            
            if (my $sinfo  = $sample_info{$sample}) {
#              warn Dumper $sinfo;
              $data{$ind}{Gender} = $sinfo->{Gender};
              $data{$ind}{Description} = $sinfo->{Description};
              $data{$ind}{Father} = $sinfo->{Father} ? {Name => $sinfo->{Father}} : {};
              $data{$ind}{Mother} = $sinfo->{Mother} ? {Name => $sinfo->{Mother}} : {};
              if (my @children = @{$sinfo->{Children} || []}) {
                foreach my $child (@children) {
                  $data{$ind}{Children}->{$child} = [$sample_info{$child}->{Gender}, $child];                 
                }
              }

              $pop_hash->{$sinfo->{Population}} = scalar(keys %$pop_hash) + 1 unless exists $pop_hash->{$sinfo->{Population}};

              #the ID is set to an integer value to fix a bug (THOUGEN-199):
              my $phash = {Name => $sinfo->{Population}, ID => $pop_hash->{$sinfo->{Population}} };
              
              push @{$data{$ind}{Population}},$phash, {Name => '1000GENOMES:ALL', ID => $pop_hash->{'1000GENOMES:ALL'} };

            } else {
              $data{$ind} = {};
            }

# in case of deletions the VCF convention is to add a letter preceeding the deletions, but in ensembl only the deleted bps are presented
# ,e.g in ensembl deletions can be presented as -/AAGT, but in VCF file it will be C/CAAGT
# to be in line with ensembl display we cut the first letter of the deletion in VCF 
# thus a VCF deletion is defined as when the alt is only 1bp and the ref is longer then 1 bp 
      my $del = 0;
      my @gta; 
      if ($ins) {
    @gta = map { substr($_, 1) } @{$x->{ALT}||[]};
    unshift @gta, '-';
      } elsif (length($x->{REF}) > 1 && @{$x->{ALT} || []} && length($x->{ALT}->[0]) == 1) {
# deletion 
    push @gta, substr($x->{REF}, 1), '-';
      } else {
    push @gta, $x->{REF}, @{$x->{ALT}||[]};
      }

#            my @gta = $del ? ('-') : @{$x->{ALT}||[]};            
#            unshift @gta, ($del ? substr($x->{REF}, 1) : $x->{REF});

            $data{$ind}{Name} = $sample;
            my $gt = $x->{gtypes}->{$sample}->{GT};
            $gt =~ s/(\d)/$gta[$1]/g;
      
#            warn join ' * ', $del, $ins, $x->{gtypes}->{$sample}->{GT}, $gt , " # ", @gta, "\n";
            $data{$ind}{Genotypes}      = $gt;
            
#            if ($thash->{$sample}) {
#              warn "$sample : $x->{gtypes}->{$sample}->{GT} \n"; 
#            }
            $ind++;
          }
#          $x->{gtypes} = {};
#          warn Dumper $x;
      } 
  }
  return \%data;   
}

1;

