use strict;
use warnings;

use lib "../modules";

use Cwd;
use Bio::Analysis::Forge;


  my @snps = qw(rs2395730 rs12914385 rs2865531 rs11168048 rs1529672 rs357394 rs13147758 rs3769124 rs2647044 rs12504628 rs1541374 rs2869967 rs1928168 rs3094548 rs3867498 rs6903823 rs4762767 rs9978142 rs11172113 rs9310995 rs2571445 rs2070600 rs11727189 rs3734729 rs2906966 rs1036429 rs16909898 rs3995090 rs2284746 rs2544527 rs12477314 rs2277027 rs993925 rs1344555 rs1455782 rs2855812 rs2838815 rs11001819 rs12716852 rs2798641 rs4129267 rs7068966 rs12899618 rs153916 rs1551943 rs730532 rs1980057 rs3820928 rs2036527 rs10516526 rs2857595 rs3817928 rs310558 rs808225 rs12447804);


my $fname = getcwd.'/forge';
mkdir $fname;

my $forge = Bio::Analysis::Forge->new(
    {
	output => $fname,
#	bkgd => $hub->param('opt_bkgd'),
#	data => $hub->param('opt_data'),
#	label => $hub->param('name'),
        noplot => 1,
	r_libs => "/nfs/public/rw/ensembl/libs/R",
	datadir => '/nfs/public/rw/ensembl/data/Forge'
    });

$forge or die "System error: Failed to initialise Forge analysis.";

if (my $jobid = $forge->run(\@snps)) {
    warn "Done . Results are in $fname/$jobid \n";
} else {
    warn "Error : ",$forge->error, "\n";
}
