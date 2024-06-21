#!/opt/LifeKeeper/bin/perl

use Getopt::Std;
use File::Glob ':bsd_glob';

our $opt_r,$opt_p, $opt_k, $opt_u;

getopts('r:p:k:u:');

if( ! defined ${opt_r} || ${opt_r} eq "" || ! defined ${opt_p} || ${opt_p} eq "" || ! defined ${opt_k} || ${opt_k} eq "" || ! defined ${opt_u} || ${opt_u} eq ""){
	print STDERR "Usage:\n";
	print STDERR "./add_regions.pl -r <AWS_REGION> -p <instance password> -k <instance key> -u <S3 URL>\n";
	print STDERR "\n\t: EX: ./add_regions -r us-east-1 -p SamplePassword -k MyKey.pem -u https://Fake_Bucket.s3.REGION.amazonaws.com/OBJECT/templates/sios-protection-suite-main.template.yaml \n";
	exit 1;
}

my $region=${opt_r};
my $pass=${opt_p};
my $key=${opt_k};
my $url=${opt_u};
my $templatename = "sios-protection-suite-main.template.yaml";
my $jsonpartsdir = "./jsonparts/";

my @availability_zones=`aws ec2 describe-availability-zones --region $region --output text --query "AvailabilityZones[*].{ZoneName:ZoneName}" --filters Name="zone-type",Values="availability-zone"`;

if( scalar @availability_zones < 2){
	print STDERR "The region $region does not have enough availability zones to create the stack\n";
	exit 1;
}


# select two random availability zones
my $num_zones = 2;
@availability_zones=(shuffle(@availability_zones))[0 .. $num_zones-1];

my @s3details=split(/[.\/]+/, $url);


if( $s3details[0] ne "https:" || $s3details[2] ne "s3" )
{
	print STDERR "The specified URL is not an s3 bucket\n";
	exit 1;
}

if( $s3details[-1] ne "yaml" )
{
	print STDERR "The specified URL is not a path to a .yaml file.\n";
}

my $s3bucket = $s3details[1];
my $s3region = $s3details[3];
my $s3object = "";
my $comreached = 0;
my $wholeobjectfound = 0;
foreach my $element (@s3details)
{
	if( $element eq "templates"){
		$wholeobjectfound = 1;
	}
	if($comreached && ! $wholeobjectfound){
		$s3object=$s3object.$element."/";
	}
	if(!$comreached && $element eq "com"){
		$comreached=1;
	}
}

my @last_three = splice(@s3details, -3);
my $filename = "";
foreach $i (@last_three){
	$filename=$filename.$i;
	if ( $i ne $last_three[-1]){
		$filename=$filename.".";
	}
}

if($filename ne $templatename){
	print STDERR "The URL does not point to the correct template file.\n\tGot:\t\"$filename\"\n\t Wanted:\t\"$templatename\"\n";
	exit 1;
}

#TODO - make this pick two availability zones that are not always the first two in the list
my $azstr = "";
my $counter = 0;
foreach my $zone (@availability_zones){
	chomp($zone);
	$azstr = "$azstr"."$zone";

	# add a delimeter comma unless we are on the last element
	$azstr = "$azstr"."," unless ($counter++ eq $#availability_zones);
}

chomp(my $azstr="$availability_zones[0]");
chomp($azstr="$azstr,$availability_zones[1]");

my $parmsdir = "./config";
my $parmsdefault = "$parmsdir/defaults/default";
my %parms = ();

open(FH, '<', $parmsdefault) or die $!;

while(<FH>){
	if (!( $_ =~ m/^#.*$/ || $_ =~ m/^\n/) ){
		my @line = split(/=/, $_);
		my $key = "$line[0]";
		my $param = "$line[1]";

		chomp($parms{$key} = $param);
	}
}

close(FH);

my $paramsrequired = "$parmsdir/required";

open(FH, '<', $paramsrequired) or die $!;

while(<FH>){
        if (!( $_ =~ m/^#.*$/ || $_ =~ /^\n/ )){
                my @line = split(/=/, $_);
                chomp(my $key = "$line[0]");
                chomp(my $param = "$line[1]");

                $parms{$key} = $param;

        }
}

close(FH);

# TODO - USE OPTIONAL FILE


my $paramstemplatefile = "./parameters_template/cloudformationParms.template.json";

# move template file to its new home
my $generatedtemplatedir = "./generated-templates/$region/";
my $filledintemplatefile = $generatedtemplatedir . "cloudformationParms.$region.json";
`mkdir -p $generatedtemplatedir`;

if( $? != 0 ){
	print STDERR "Could not mkdir $generatedtemplatedir. Aborting\n";
}

if( -e $filledintemplatefile ){
	unlink $filledintemplatefile;
}

`cp $paramstemplatefile $filledintemplatefile`;

my $sed = "sed -e \'s/\\//\\\\\\//g\'";
# name all parameters that are defined in the default and required file
foreach my $keys ( keys %parms ){
	my $anchor = $keys . "_ANCHOR";
	chomp($anchor=`echo "$anchor" | $sed`);	
	chomp(my $replace = `echo "$parms{$keys}" | $sed`);
	my $sedcmd = "sed -i 's/$anchor/$replace/g' $filledintemplatefile";
	`$sedcmd`;
}

# Now put in the parameters generated programatically

chomp(my $s3object = `echo $s3object | $sed`);
`sed -i 's/QSS3KEYPREFIX_ANCHOR/$s3object/' $filledintemplatefile`;
#`sed -i 's/KEYPAIRNAME_ANCHOR/$key/' $filledintemplatefile`;
`sed -i 's/QSS3BUCKETNAME_ANCHOR/$s3bucket/' $filledintemplatefile`;
`sed -i 's/AVAILABILITYZONES_ANCHOR/$azstr/' $filledintemplatefile`;
`sed -i 's/QSS3BUCKETREGION_ANCHOR/$s3region/' $filledintemplatefile`;
#`sed -i 'NEWROOTPASSWORD_ANCHOR/$pass/ $filledintemplatefile'`

print "$filledintemplatefile\n";

exit 0;
