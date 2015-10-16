package EnsEMBL::Web::Configuration::UserData;

use strict;

sub modify_tree {
  my $self = shift;

  my $custom_data = $self->get_node('CustomData');
  $custom_data->remove unless exists $self->hub->referer->{'ENSEMBL_TYPE'};

  my $convert_menu = $self->get_node( 'Conversion' );

  ## Slice file attachment
 $convert_menu->append(
  $self->create_node( 'SelectSlice', "Data Slicer",
   [qw(select_vcf EnsEMBL::Web::Component::UserData::SelectSlice)],
    { 'availability' => 1 }
  ));

 $convert_menu->append(
  $self->create_node( 'SliceFile', '',
    [], { 'command' => 'EnsEMBL::Web::Command::UserData::SliceFile',
    'availability' => 1, 'no_menu_entry' => 1 }
  ));

 $convert_menu->append(
  $self->create_node( 'SliceFeedback', '',
   [qw(vcf_feedback EnsEMBL::Web::Component::UserData::SliceFeedback)],
    { 'availability' => 1, 'no_menu_entry' => 1 }
  ));

##Disabled for now
# $convert_menu->append(
#    $self->create_node( 'VariationsMap','Variations Map',
#      [qw(variations_map EnsEMBL::Web::Component::UserData::VariationsMap)],
#			{ 'availability' => 1, },
#    )
#		       );

 $convert_menu->append(
    $self->create_node( 'VariationsMapVCF','Variation Pattern Finder',
      [qw(variations_map EnsEMBL::Web::Component::UserData::VariationsMapVCF)],
                        { 'availability' => 1, },
    )
                       );

 $convert_menu->append(
    $self->create_node( 'Haploview','VCF to PED converter',
      [qw(variations_map EnsEMBL::Web::Component::UserData::Haploview)],
                        { 'availability' => 1, },
    )
                       );


 $convert_menu->append(
    $self->create_node( 'Forge','Forge Analysis (v1.1)',
      [qw(forge EnsEMBL::Web::Component::UserData::Forge)],
                        { 'availability' => 1, },
    )
                       );

 $convert_menu->append(
  $self->create_node( 'ForgeRun', '',
    [], { 'command' => 'EnsEMBL::Web::Command::UserData::ForgeRun',
    'availability' => 1, 'no_menu_entry' => 1 }
  ));

 $convert_menu->append(
  $self->create_node( 'ForgeFeedback', '',
   [qw(forge_feedback EnsEMBL::Web::Component::UserData::ForgeFeedback)],
    { 'availability' => 1, 'no_menu_entry' => 1 }
  ));

 $convert_menu->append(
  $self->create_node( 'ForgeOutput', '',
   [qw(forge_output EnsEMBL::Web::Component::UserData::ForgeOutput)],
    { 'availability' => 1, 'no_menu_entry' => 1 }
  ));



 $convert_menu->append(
    $self->create_node( 'Forge10','Forge Analysis (v1.0)',
      [qw(forge EnsEMBL::Web::Component::UserData::Forge10)],
                        { 'availability' => 1, },
    )
                       );

 $convert_menu->append(
  $self->create_node( 'ForgeRun10', '',
    [], { 'command' => 'EnsEMBL::Web::Command::UserData::ForgeRun10',
    'availability' => 1, 'no_menu_entry' => 1 }
  ));

 $convert_menu->append(
  $self->create_node( 'ForgeFeedback10', '',
   [qw(forge_feedback10 EnsEMBL::Web::Component::UserData::ForgeFeedback)],
    { 'availability' => 1, 'no_menu_entry' => 1 }
  ));

 $convert_menu->append(
  $self->create_node( 'ForgeOutput10', '',
   [qw(forge_output10 EnsEMBL::Web::Component::UserData::ForgeOutput)],
    { 'availability' => 1, 'no_menu_entry' => 1 }
  ));





  $convert_menu->append(
    $self->create_node( 'Allele','Allele Frequency',
      [qw(allele EnsEMBL::Web::Component::UserData::Allele)],
        { 'availability' => 1, },
  ));

  $convert_menu->append(
    $self->create_node( 'AllelePop','Allele Frequency',
      [qw(allele EnsEMBL::Web::Component::UserData::AllelePop)],
        { 'availability' => 1, 'no_menu_entry' => 1},
  ));

 $convert_menu->append(
    $self->create_node( 'AlleleFreq', '', [],
      {'command' => 'EnsEMBL::Web::Command::UserData::AlleleFreq',
      'availability' => 1, 'no_menu_entry' => 1},
    )
  );

  $convert_menu->append(
    $self->create_node( 'AlleleCalc', 'Allele Frequency Output',
      [qw(allelecalc EnsEMBL::Web::Component::UserData::AlleleCalc)],
      {'availability' => 1, 'no_menu_entry' => 1},
    )
  );
  $convert_menu->append(
    $self->create_node( 'AlleleFreqOutput', 'Allele Frequency Output',
      [qw(allelecalc EnsEMBL::Web::Component::UserData::AlleleFreqOutput)],
      {'availability' => 1, 'no_menu_entry' => 1},
    )
  );
}


1;
