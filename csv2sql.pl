#!/usr/bin/perl
=head1 NAME

csv2sql.pl

=head2 VERSION

0.1

=head1 SYNOPSIS

read a csv file and convert fields from first line into sql
insert statements

=head2 OPTIONS

=over

=item  <tablename> name of the table into which we
+ want to insert

=back

=head1 REQUIREMENTS

Perl 5.8.4 (not tried on other versions)
Text::CSV_XS 
IO::Handle

=head1 COPYRIGHT AND LICENCE

               Copyright (C)2011  Adam Bielinski

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version
 2 of the License, or (at your option) any later version.

 This program is distributed in the hope that it will be
 useful, but WITHOUT ANY WARRANTY; without even the implied
 warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 PURPOSE.  See the GNU General Public License for more
 details.

 You should have received a copy of the GNU General Public
 License along with this program; if not, write to the Free
 Software Foundation, Inc., 59 Temple Place - Suite 330,
 Boston, MA  02111-1307, USA.
 Also available on line: http://www.gnu.org/copyleft/gpl.html

=head1 SEE ALSO

=cut

use strict;
use warnings;
use Text::CSV_XS;
use IO::Handle;
use Text::Unaccent::PurePerl qw(unac_string);

my $usage="Usage: $0 <tablename>";
die $usage unless($#ARGV==0);

my $table=shift;
die $usage unless $table;

my $csv = Text::CSV_XS->new ({binary=>1});
my $in  = IO::Handle->new;
my $out = IO::Handle->new;

$in->fdopen(fileno(STDIN), 'r') or die "Can't fdopen STDIN: $!\n";# // stupid syntax highlighter
$out->fdopen (fileno (STDOUT), "w") or die "Cannot fdopen STDOUT: $!\n
+";
$csv->parse($in->getline) or die ("Can't parse first line of STDIN! $!
+\n");
my $cols = "(";
my @col_names;
my $col_count =0;
for ($csv->fields){
  $_ =~ s/ /_/g; # replace spaces with _
  $_ =~ s/\.'//g; # remove . and '
  $_ = unac_string($_);
  $_ = lc($_);   # lowercase
  $_ = substr($_, 0, 64); # limit size
  $cols .= "`$_`, ";
  push(@col_names, $_);
  $col_count++;
}
$cols =~ s/, $//; #remove commas and $

my $sql = "DROP TABLE IF EXISTS `$table`;
CREATE TABLE `$table`(";

foreach my $col (@col_names){
#`reference` varchar(255) NOT NULL,
	$sql.="\n`$col` text NOT NULL,";
} 
chop($sql);


$sql .="
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


LOCK TABLES `$table` WRITE;

INSERT INTO `$table` ";
$sql  .= "$cols) VALUES ";

while (!$in->eof) {
  IO::Handle->input_record_separator("\n");
  my $row = $csv->getline($in);
  next unless defined $row ;
  if((@$row) != $col_count) {
    warn "Odd row: " ;
    warn (join ", ",@$row);
    warn "\nExpecting $col_count elements, got " . (@$row) . "\n";
    next;
  }
  my $empty = 1; foreach (@$row) { $empty = 0  if (defined ($_) && ($_ ne "")); } 
  if ($empty){
  	warn "Empty row: ";
  	next;
  }
  my $vals='';
  for(@$row) {
    $_=~s/"/\\"/g;
    $vals.='"' .$_ .'", ';
  }
  $vals =~s/, $//;
  $sql.= "($vals), \n";
}
undef $in;

$sql=~s/, $/;/;
$out->print($sql);
undef $out;
