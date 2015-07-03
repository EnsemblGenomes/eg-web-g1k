package EG::1000Genomes::SiteDefs;
use strict;
sub update_conf {

    map {delete($SiteDefs::__species_aliases{$_})} keys %SiteDefs::__species_aliases;
    $SiteDefs::ENSEMBL_PROXY_PORT = 80;
    $SiteDefs::ENSEMBL_SITETYPE = '1000 Genomes';
    $SiteDefs::SITE_NAME = '1000 Genomes';
    $SiteDefs::SITE_RELEASE_VERSION = 17;
    $SiteDefs::SITE_RELEASE_DATE = 'Jul 2015';
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
                                           $SiteDefs::ENSEMBL_SERVERROOT.'/eg-web-common/perl',
				       );
    $SiteDefs::ENSEMBL_DATASETS = ['Homo_sapiens'];

    $SiteDefs::OBJECT_TO_SCRIPT->{'Info'} = 'AltPage';#for e!69/70 style species home page
 push @SiteDefs::ENSEMBL_LIB_DIRS, (
 "$SiteDefs::ENSEMBL_SERVERROOT/ensembl-io/modules"
);

}

1;
