#!/usr/bin/perl -w

# mrtgreport: a tool to report mrtg data from a database
#
#    Copyright (C) 2004 Max Clark and Creative Thought Inc.
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

#use strict;
use Getopt::Long;
use DBI;
use Time::Local;
use MRTG_lib;

my $VERSION = "0.1";

# Configuration
# -------------
my $dbname = "";
my $dbuser = "";
my $dbpass = "";
my $mrtgconfig = "/usr/local/etc/mrtg/mrtg.cfg";

# Initialize Variables
# --------------------
my ($configfile, @target_names, %globalcfg, %targetcfg);
my %interface;

# Usage and Help
# --------------
sub usage
{
	print "\n";
        print "usage: mrtgreport [*options*]\n";
        print "  -h, --help           display this help and exit\n";
        print "      --version        output version information and exit\n";
        print "  -v, --verbose        display debug messages\n";
        print "  -l, --lastmonth      report for the previous month\n";
        print "  -y, --year           select the year in YYYY format\n";
	print "  -m, --month          select the month in MM format\n";
	print "\n";
        exit;
}

my %opt = ();
GetOptions(\%opt,
        'month|m=s', 'year|y=s', 'lastmonth|l', 'help|h', 'verbose|v', 'version'
        ) or exit(1);
usage if $opt{help};

if ($opt{version}) {
        print "mrtgreport $VERSION by max\@cthought.com\n";
        exit;
}

# Define Base Date Information
# ----------------------------
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

$mon = --$opt{month} if defined $opt{month};
$year = $opt{year} - 1900 if defined $opt{year};
	
if (defined $opt{lastmonth}) {
	if ($mon == 0) {
		$mon = "11";
		$year--;
	} else {
		$mon--;
	}
}

my @months = qw(31 28 31 30 31 30 31 31 30 31 30 31);
my @month_name = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

$months[1]++ if ($year + 1900) % 4 == 0;

my $localstart = timelocal("0","0","0","1",$mon,$year);
my $localend = timelocal("0","0","0",$months[$mon],$mon,$year);
my $starttime = timegm("0","0","0","1",$mon,$year);
my $endtime = timegm("0","0","0",$months[$mon],$mon,$year);

# Override defaults
# -----------------
$configfile = $opt{config} ? defined $opt{config} : $mrtgconfig;
                                                                                                                             
# Read in the Interfaces from MRTG
# --------------------------------
exit unless -r "$configfile";
readcfg($configfile, \@target_names, \%globalcfg, \%targetcfg);

# Connect to the Database
# -----------------------
my $dbh = DBI->connect("DBI:Pg:dbname=$dbname", $dbuser, $dbpass) or die "Couldn't connect to database: " . DBI->errstr;

# SQL Queries
# -----------
my $get_values = $dbh->prepare_cached(q(
	select date, avgin, avgout
	from t_mrtglog
	where interface = ? and date between ? and ?
	order by date desc
	)) || "Couldn't prepare statement: " . $dbh->errstr;

my $get_floor = $dbh->prepare_cached(q(
	select floor(count(*)*0.95)
	from t_mrtglog
	where interface = ? and date between ? and ?
	)) || "Couldn't prepare statement: " . $dbh->errstr;

my $get_95in = $dbh->prepare(q(
	select avgin from t_mrtglog
	where interface = ? and date between ? and ?
	order by avgin limit 1 offset ?
	)) || "Couldn't prepare statement: " . $dbh->errstr;
                                                                                                                             
my $get_95out = $dbh->prepare(q(
	select avgout from t_mrtglog
	where interfaceid = ? and date between ? and ?
	order by avgout limit 1 offset ?
	)) || "Couldn't prepare statement: " . $dbh->errstr;

# Get the Data
# ------------
foreach my $target (@target_names) {

	($interface{'in'},$interface{'out'}) = calcTransfer($target,$starttime,$endtime);

	print "Datatransfer for $target = In: $interface{'in'} Out: $interface{'out'}\n";

	($interface{'95in'},$interface{'95out'}) = get95th($target,$starttime,$endtime);

	print "95th for $target = In: $interface{'95in'} Out: $interface{'95out'}\n";

#	foreach $sday (1 .. $months[$mon]) {
#
#		my ($daystart,$dayend) = epochDayRange($sday);
#
#		my ($billif) = streamingCalc($interface,$daystart,$dayend,$billin{$interface});
#
#		print "Detail for $customer{$customerid}: $interface{$interface} $billif GB\n" if defined $opt{verbose};
# 
#	}

}

# Disconnect from the Database
# ----------------------------
$dbh->disconnect;

# ----------
sub calcTransfer {
	
	my $interface = shift;
	my $starttime = shift;
	my $endtime = shift;

	$get_values->execute($interface,$starttime,$endtime);
                                                                                                                             
	my $itot = "0";
	my $otot = "0";
	$prev_date = "0";
                                                                                                                             
	while (my ($date,$avgin,$avgout) = $get_values->fetchrow_array) {
                                                                                                                             
		$prev_date = $date if $prev_date == 0;
                                                                                                                             
		$interval = $prev_date - $date;
		$prev_date = $date;
                                                                                                                             
		$itot = $itot + ($avgin * $interval);
		$otot = $otot + ($avgout * $interval);
                                                                                                                             
	}

	$get_values->finish;

	return ($itot,$otot);
                                                                                                                             
}
# ==========

# ----------
sub scaleBytes {

	my $bytes = shift;
	$scale = $bytes / 1073741824;	# 1024 * 1024 * 1024 GB
	$round = sprintf("%.3f", $scale);
	return $round;

}
# ==========

# ----------
sub epochDayRange {

	my $sday = shift;

	my $smon = $mon;
	my $syear = $year;

	if ($sday == $months[$mon]) {
		$eday = "1";
		if ($smon == "11") {
		        $emon = "0";
		        $eyear = $syear + 1;
		} else {
			$emon = $smon + 1;
		}
	} else {
		$eday = $sday + 1;
		$emon = $smon;
		$eyear = $syear;
	}

	$daystart = timegm("0","0","0",$sday,$smon,$syear);
	$dayend = timegm("0","0","0",$eday,$emon,$eyear);

	return ($daystart,$dayend);

}
# ==========

# ----------
sub get95th {

	my $interface = shift;
	my $starttime = shift;
	my $endtime = shift;
                                                                                                                             
	$get_floor->execute($interface,$starttime,$endtime);
	my @floor = $get_floor->fetchrow_array;
	my $limit = $floor[0];
	$get_floor->finish;
 
	#next if $limit == 0;

	$get_95in->execute($interface,$starttime,$endtime,$limit);
	my @avgin = $get_95in->fetchrow_array;
	my $in = $avgin[0] || 0;
	$get_95in->finish;
 
	$get_95out->execute($interface,$starttime,$endtime,$limit);
	my @avgout = $get_95out->fetchrow_array;
	my $out = $avgout[0] || 0;
	$get_95out->finish;

	return($in,$out);
 
}
