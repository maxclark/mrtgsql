#!/usr/bin/perl -w

# mrtgsql.pl: a tool to archive mrtg data into a database
#
#    Copyright (C) 2004-2011 Max Clark and Creative Thought, Inc.
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

use strict;
use Getopt::Long;
use DBI;
use MRTG_lib;

my $VERSION = "0.1";

# Configuration
# -------------
my $dbhost = "";
my $dbname = "";
my $dbuser = "";
my $dbpass = "";
my $mrtgconfig = "/usr/local/etc/mrtg/mrtg.cfg";

# Initialize Variables
# --------------------
my %count;
my %oldend;
my ($configfile, @target_names, %globalcfg, %targetcfg);
my $device;
my $name;

sub usage
{
        print "\n";
        print "usage: mrtgreport [*options*]\n";
        print "  -h, --help           display this help and exit\n";
        print "  -c, --config         location of the MRTG configuration file\n";
        print "  -d, --directory      directory where the mrtg .log files exist\n";
        print "      --dbhost         database host name\n";
        print "      --dbuser         database user name\n";
        print "      --dbpass         database password\n";
        print "      --dbname         database name\n";
        print "      --version        output version information and exit\n";
        print "  -v, --verbose        be verbose\n";
        print "      --debug          print debug messages\n";
        print "\n";
        exit;
}

my %opt = ();
GetOptions(\%opt,
        'config|c=s', 'debug', 'verbose|v', 'help|h', 'version',
	'dbhost=s', 'dbuser=s', 'dbpass=s', 'dbname=s'
        ) or exit(1);
usage if $opt{help};

if ($opt{version}) {
        print "mrtgsql $VERSION by max\@clarksys.com\n";
        exit;
}

# Override defaults
# -----------------
$mrtgconfig = $opt{config} if defined $opt{config};
$dbhost = $opt{dbhost} if defined $opt{dbhost};
$dbuser = $opt{dbuser} if defined $opt{dbuser};
$dbpass = $opt{dbpass} if defined $opt{dbpass};
$dbname = $opt{dbname} if defined $opt{dbname};

# Read in the Interfaces from MRTG
# --------------------------------
exit unless -r "$mrtgconfig";
readcfg($mrtgconfig, \@target_names, \%globalcfg, \%targetcfg);
my $workdir = $globalcfg{workdir};

# Connect to the Database
# -----------------------
my $dbh = DBI->connect("DBI:Pg:dbname=$dbname;host=$dbhost", $dbuser, $dbpass, { RaiseError => 1, AutoCommit => 0 })
	or die "Couldn't connect to database: " . DBI->errstr;

# SQL Queries
# -----------
my $last_date = $dbh->prepare_cached(q(
	select extract(epoch from date) as date
	from mrtglog
	where target = ?
	order by date desc limit 1
	)) or die "Couldn't prepare statement: " . $dbh->errstr;

my $insert = $dbh->prepare_cached(q(
	insert into mrtglog (target,date,avgin,avgout,peakin,peakout)
	values (?,to_timestamp(?),?,?,?,?)
	)) or die "Couldn't prepare statement: " . $dbh->errstr;

my $target_select = $dbh->prepare_cached(q(
	select target
	from mrtgtarget
	where target = ?
	)) or die "Couldn't prepare statement: " . $dbh->errstr;

my $target_insert = $dbh->prepare_cached(q(
	insert into mrtgtarget (target,device,description,date)
	values (?,?,?,now())
	)) or die "Couldn't prepare statement: " . $dbh->errstr;

# Get the last entry dates for the interfaces
# -------------------------------------------
foreach my $target (@target_names) {

	# First update the target table
	# -----------------------------
	($device,$name) = split(/\s--\s/,$targetcfg{title}{$target});

	$target_select->execute($target);

	unless ($target_select->fetch()) {
		$target_insert->execute($target,$device,$name) or die "Couldn't execute statement: " . $target_insert->errstr;
		$target_insert->finish;
	}

	$target_select->finish();

        $dbh->commit;

	$last_date->execute($target);
	my $last_ref = $last_date->fetchrow_hashref;
	$last_date->finish;

	$oldend{$target} = $last_ref->{'date'} || 0;

	print "$target last entry: $oldend{$target}\n" if defined $opt{debug};

}

# Get the Data
# ------------
foreach my $target (@target_names) {

	$count{$target} = "0";

	print "Target file $workdir/$targetcfg{directory}{$target}/$target.log\n" if $opt{debug};

	next unless -r "$workdir/$targetcfg{directory}{$target}/$target.log";

	print "Opening file $workdir/$targetcfg{directory}{$target}/$target.log\n" if $opt{debug};

	open(FILE, "< $workdir/$targetcfg{directory}{$target}/$target.log") || die "Cannot open $workdir/$targetcfg{directory}{$target}/$target.log: $!";

	# Skip the first line of the log file
	# -----------------------------------
	my $line = <FILE>;

	while (<FILE>) {

		chomp;

		my ($date,$avgin,$avgout,$peakin,$peakout) = split(/ /);

		# Only work on dates that have been rounded
		# -----------------------------------------
		next if $date !~ /00$/;

		# Don't insert data into old sample ranges
		# ----------------------------------------
		last if $date le $oldend{$target};

		$insert->execute($target,$date,$avgin,$avgout,$peakin,$peakout) or die "Couldn't execute statement: " . $insert->errstr;
		print "$target,$date,$avgin,$avgout,$peakin,$peakout\n" if defined $opt{debug};

		$count{$target}++;

	}

	$insert->finish;

	$dbh->commit;

	print "Inserted $count{$target} entries for interface $target\n" if defined $opt{verbose};

	close(FILE);

}

# Disconnect from the Database
# ----------------------------
$dbh->disconnect;
