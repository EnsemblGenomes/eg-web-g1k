package EG::1000Genomes::SiteDefs;
use strict;
sub update_conf {

    map {delete($SiteDefs::__species_aliases{$_})} keys %SiteDefs::__species_aliases;
    $SiteDefs::ENSEMBL_PROXY_PORT = 80;
    $SiteDefs::ENSEMBL_SITETYPE = '1000 Genomes';
    $SiteDefs::SITE_NAME = '1000 Genomes';
    $SiteDefs::SITE_RELEASE_VERSION = 16;
    $SiteDefs::SITE_RELEASE_DATE = 'Oct 2014';
    $SiteDefs::ENSEMBL_SERVERNAME     = 'browser.1000genomes.org';
    $SiteDefs::ENSEMBL_BASE_URL     = 'http://browser.1000genomes.org';
    $SiteDefs::ENSEMBL_HELPDESK_EMAIL  = 'info@1000genomes.org';

    $SiteDefs::__species_aliases{ 'Homo_sapiens'       } = [qw(hs human)];
    $SiteDefs::ENSEMBL_PRIMARY_SPECIES  = 'Homo_sapiens';
    $SiteDefs::ENSEMBL_SECONDARY_SPECIES = 'Homo_sapiens';
    $SiteDefs::ENSEMBL_BLAST_ENABLED  = 0;
    $SiteDefs::ENSEMBL_LOGINS = 0;

    @SiteDefs::ENSEMBL_PERL_DIRS    = (
                                           $SiteDefs::ENSEMBL_SERVERROOT.'/perl',
                                           $SiteDefs::ENSEMBL_SERVERROOT.'/eg-plugins/common/perl',
				       );
    $SiteDefs::ENSEMBL_DATASETS = ['Homo_sapiens'];

    $SiteDefs::OBJECT_TO_SCRIPT->{'Info'} = 'AltPage';#for e!69/70 style species home page
}

1;
