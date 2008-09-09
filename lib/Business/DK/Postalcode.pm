package Business::DK::Postalcode;

# $Id: Postalcode.pm,v 1.3 2008-09-09 19:17:24 jonasbn Exp $

use strict;
use Tree::Simple;
use Data::Dumper;
use vars qw($VERSION @ISA @EXPORT_OK);
require Exporter;

use constant VERBOSE => 0;
use constant DEBUG => 0;

$VERSION = '0.01';
@ISA = qw(Exporter);
@EXPORT_OK = qw(get_all_postalcodes get_all_data create_regex);

sub get_all_data {
	my @data = <DATA>; 

	return \@data;
}

sub get_all_postalcodes {
	my @data = @_;
	my @postalcodes = ();

	@data = <DATA> if not @data;

	foreach my $zipcode (@data) {
		_retrieve_postalcode(\@postalcodes, $zipcode);
	}

	return \@postalcodes;
}

sub _retrieve_postalcode {
	my ($postalcodes, $string) = @_;

	my @entries = split(/\t/, $string, 6);

	if ($entries[0] =~ m/^\d{4}$/) {
		push @{$postalcodes}, $entries[0];
	}
}

sub create_regex {
	my ($postalcodes) = @_;

	my $tree = Tree::Simple->new("0", Tree::Simple->ROOT);
	if (scalar @{$postalcodes}) {
		foreach my $postalcode (@{$postalcodes}) {
			_build_tree($tree, $postalcode);
		}
	} else {
		while (<DATA>) {
			_build_tree($tree, $_);
		}
	}

	my $regex = [];
	
	my $end = '';
	my $no_of_children = $tree->getChildCount();
	
	print STDERR "root has $no_of_children\n";

	$tree->traverse(sub {
		my ($_tree) = shift;
		print STDERR (("\t" x $_tree->getDepth()), $_tree->getNodeValue(), "\n");
		
		$no_of_children = $_tree->getChildCount();
		if ($no_of_children > 1) {
			$_tree->insertChild(0, Tree::Simple->new('('));
			$_tree->addChild(Tree::Simple->new(')'));
			
			_branch(\$end, \$no_of_children);
		} elsif ($_tree->isLeaf() && $_tree->getNodeValue() =~ m/^\d+$/) {

			print STDERR "We have a leaf\n" if VERBOSE;
			#$_tree->insertChild(0, Tree::Simple->new('(?:'));
			$_tree->addChild(Tree::Simple->new($end));
			$end = '';
		}
		
		if ($_tree->getNodeValue() =~ m/^\d+$/) {
			$_tree->setNodeValue('(?:'.$_tree->getNodeValue().')');
		}
		
		if (DEBUG) {
			print STDERR "examining: ".$_tree->getNodeValue()."\n";
			print STDERR "\$no_of_children = $no_of_children\n";
			print STDERR "\$end = $end\n";	
		}
		if (DEBUG) {
			print STDERR "\$regex = ".join("", @{$regex})."\n";	
			print STDERR "\n";
		}
	});

	$tree->traverse(sub {
		my ($_tree) = shift;
		push(@{$regex}, $_tree->getNodeValue());
	});

	my $result = join("", @{$regex});
	return \$result;
}

sub create_regex_old {
	my ($postalcodes) = @_;

	my $tree = Tree::Simple->new("0", Tree::Simple->ROOT);
	if (scalar @{$postalcodes}) {
		foreach my $postalcode (@{$postalcodes}) {
			_build_tree($tree, $postalcode);
		}
	} else {
		while (<DATA>) {
			_build_tree($tree, $_);
		}
	}

	my $regex = [];
	
	#push(@{$regex}, '(');
	
	my $end = '';
	my $no_of_children = 0;
	my $branch = 0;

	$tree->traverse(sub {
		my ($_tree) = shift;
		print (("\t" x $_tree->getDepth()), $_tree->getNodeValue(), "\n");
		
		$no_of_children = $_tree->getChildCount();
		if (DEBUG) {
			print STDERR "examining: ".$_tree->getNodeValue()."\n";
			print STDERR "\$no_of_children = $no_of_children\n";
			print STDERR "\$branch = $branch\n";
			print STDERR "\$end = $end\n";	
		}
		if ($branch) {
			_branch(\$_tree->getNodeValue(), \$branch, \$end, $regex);
		}
				
		if ($no_of_children > 1) {
			$branch++;
			_tokenize(\$_tree->getNodeValue(), $regex);			
			#_terminate(\$_tree->getNodeValue(), \$end, $regex);

		} else {
			_tokenize(\$_tree->getNodeValue(), $regex);
			#_terminate(\$_tree->getNodeValue(), \$end, $regex);
		}
		
		if ($_tree->getDepth == 3) {
			_terminate(\$_tree->getNodeValue(), \$end, $regex);
		}
		if (DEBUG) {
			print STDERR "\$regex = ".join("", @{$regex})."\n";	
			print STDERR "\n";
		}
	});

	my $result = join("", @{$regex});
	return \$result;
}

sub _tokenize {
	my ($key, $regex) = @_;

	print STDERR "_tokenize\n" if DEBUG;
	
	my $token = "(?$$key)";
	
	push @{$regex}, $token;
	
	return $token;
}

sub _terminate {
	my ($key, $end, $regex) = @_;

	print STDERR "_terminate\n" if DEBUG;

	push @{$regex}, $$end;
	$$end = '';

	return $$end;
}

sub _branch {
	my ($end, $branch) = @_;

	print STDERR "_branch: $$branch\n" if DEBUG;
	
	if ($$branch > 1) {
		$$end = '|';
	} else {
		$$end = ')'; 
	}
	$$branch--;

	return;
}

sub _build_tree {
	my ($tree, $postalcode) = @_;

	if ($postalcode =~ m/^\d{4}$/) {

		my $oldtree = $tree;
	
		my @digits = split(//, $postalcode, 4);	
		for(my $i = 0; $i < scalar(@digits); $i++) {
	
			print STDERR "We have digit: ".$digits[$i]."\n" if VERBOSE;;
			if ($i == 0) {
				print STDERR "We are resetting to oldtree: $i\n" if VERBOSE;
				$tree = $oldtree;
			}
			
			my $subtree = Tree::Simple->new($digits[$i]);
			
			my @children = $tree->getAllChildren();
			my $child = undef;
			foreach my $c (@children) {
				print STDERR "\$c: ".$c->getNodeValue()."\n" if VERBOSE;
				if ($c->getNodeValue() == $subtree->getNodeValue()) {
					$child = $c;
					last;
				}
			}
	
			if ($child) {
				print STDERR "We are represented at $i with $digits[$i], we go to next\n" if VERBOSE;
				$tree = $child;
			} else {
				print STDERR "We are adding child ".$subtree->getNodeValue."\n" if VERBOSE;
				$tree->addChild($subtree);
				$tree = $subtree;
			}
		}
		$tree = $oldtree;

	} else {
		warn "$postalcode does not look like a postalcode\n";
	}

	return 1;
}

1;

=pod

=head1 NAME

Business::DK::Postalcode -

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

Please report issues via CPAN RT:

  http://rt.cpan.org/NoAuth/Bugs.html?Dist=Business-DK-Postalcode

or by sending mail to

  bug-Business-DK-Postalcode@rt.cpan.org

=head1 SEE ALSO

=over

=item 

=back

=head1 AUTHOR

Jonas B. Nielsen, (jonasbn) - C<< <jonasbn@cpan.org> >>

=head1 COPYRIGHT

Business-DK-Postalcode is (C) by Jonas B. Nielsen, (jonasbn) 2006

Business-DK-Postalcode is released under the artistic license

The distribution is licensed under the Artistic License, as specified
by the Artistic file in the standard perl distribution
(http://www.perl.com/language/misc/Artistic.html).

=cut

__DATA__

Postnr.	Bynavn			Gade	Firma	Provins	Land	
0555	Scanning		Data Scanning A/S, "L�s Ind"-service	True	1	
0555	Scanning		Data Scanning A/S, "L�s Ind"-service	False	1	
0800	H�je Taastrup	Girostr�get 1	BG-Bank A/S	True	1	
0877	Valby	Vigerslev All� 18	Aller Press (konkurrencer)	False	1	
0900	K�benhavn C		K�benhavns Postcenter + erhvervskunder	False	1	
0910	K�benhavn C	Ufrankerede svarforsendelser 		False	1	
0929	K�benhavn C	Ufrankerede svarforsendelser		False	1	
1000	K�benhavn K	K�bmagergade 33	K�bmagergade Postkontor	False	1	
1001	K�benhavn K	Postboks		False	1	
1002	K�benhavn K	Postboks		False	1	
1003	K�benhavn K	Postboks		False	1	
1004	K�benhavn K	Postboks		False	1	
1005	K�benhavn K	Postboks		False	1	
1006	K�benhavn K	Postboks		False	1	
1007	K�benhavn K	Postboks		False	1	
1008	K�benhavn K	Postboks		False	1	
1009	K�benhavn K	Postboks		False	1	
1010	K�benhavn K	Postboks		False	1	
1011	K�benhavn K	Postboks		False	1	
1012	K�benhavn K	Postboks		False	1	
1013	K�benhavn K	Postboks		False	1	
1014	K�benhavn K	Postboks		False	1	
1015	K�benhavn K	Postboks		False	1	
1016	K�benhavn K	Postboks		False	1	
1017	K�benhavn K	Postboks		False	1	
1018	K�benhavn K	Postboks		False	1	
1019	K�benhavn K	Postboks		False	1	
1020	K�benhavn K	Postboks		False	1	
1021	K�benhavn K	Postboks		False	1	
1022	K�benhavn K	Postboks		False	1	
1023	K�benhavn K	Postboks		False	1	
1024	K�benhavn K	Postboks		False	1	
1025	K�benhavn K	Postboks		False	1	
1026	K�benhavn K	Postboks		False	1	
1045	K�benhavn K	Ufrankerede svarforsendelser		False	1	
1050	K�benhavn K	Kongens Nytorv		False	1	
1051	K�benhavn K	Nyhavn		False	1	
1052	K�benhavn K	Herluf Trolles Gade		False	1	
1053	K�benhavn K	Cort Adelers Gade		False	1	
1054	K�benhavn K	Peder Skrams Gade		False	1	
1055	K�benhavn K	Tordenskjoldsgade		False	1	
1055	K�benhavn K	August Bournonvilles Passage		False	1	
1056	K�benhavn K	Heibergsgade		False	1	
1057	K�benhavn K	Holbergsgade		False	1	
1058	K�benhavn K	Havnegade		False	1	
1059	K�benhavn K	Niels Juels Gade		False	1	
1060	K�benhavn K	Holmens Kanal		False	1	
1061	K�benhavn K	Ved Stranden		False	1	
1062	K�benhavn K	Boldhusgade		False	1	
1063	K�benhavn K	Laksegade		False	1	
1064	K�benhavn K	Asylgade		False	1	
1065	K�benhavn K	Fortunstr�de		False	1	
1066	K�benhavn K	Admiralgade		False	1	
1067	K�benhavn K	Nikolaj Plads		False	1	
1068	K�benhavn K	Nikolajgade		False	1	
1069	K�benhavn K	Bremerholm		False	1	
1070	K�benhavn K	Ving�rdstr�de		False	1	
1071	K�benhavn K	Dybensgade		False	1	
1072	K�benhavn K	Lille Kirkestr�de		False	1	
1073	K�benhavn K	Store Kirkestr�de		False	1	
1074	K�benhavn K	Lille Kongensgade		False	1	
1092	K�benhavn K	Holmens Kanal 2-12	Danske Bank A/S	False	1	
1093	K�benhavn K	Havnegade 5	Danmarks Nationalbank	False	1	
1095	K�benhavn K	Kongens Nytorv 13	Magasin du Nord	False	1	
1098	K�benhavn K	Esplanaden 50	A.P. M�ller	False	1	
1100	K�benhavn K	�stergade		False	1	
1101	K�benhavn K	Ny �stergade		False	1	
1102	K�benhavn K	Pistolstr�de		False	1	
1103	K�benhavn K	Hovedvagtsgade		False	1	
1104	K�benhavn K	Ny Adelgade		False	1	
1105	K�benhavn K	Kristen Bernikows Gade		False	1	
1106	K�benhavn K	Antonigade		False	1	
1107	K�benhavn K	Gr�nnegade		False	1	
1110	K�benhavn K	Store Regnegade		False	1	
1111	K�benhavn K	Christian IX's Gade		False	1	
1112	K�benhavn K	Pilestr�de		False	1	
1113	K�benhavn K	Silkegade		False	1	
1114	K�benhavn K	Kronprinsensgade		False	1	
1115	K�benhavn K	Klareboderne		False	1	
1116	K�benhavn K	M�ntergade		False	1	
1117	K�benhavn K	Gammel M�nt		False	1	
1118	K�benhavn K	Sv�rtegade		False	1	
1119	K�benhavn K	Landem�rket		False	1	
1120	K�benhavn K	Vognmagergade		False	1	
1121	K�benhavn K	L�nporten		False	1	
1122	K�benhavn K	Sj�leboderne		False	1	
1123	K�benhavn K	Gothersgade		False	1	
1124	K�benhavn K	�benr�		False	1	
1125	K�benhavn K	Suhmsgade		False	1	
1126	K�benhavn K	Pustervig		False	1	
1127	K�benhavn K	Hauser Plads		False	1	
1128	K�benhavn K	Hausergade		False	1	
1129	K�benhavn K	Sankt Gertruds Str�de		False	1	
1130	K�benhavn K	Rosenborggade		False	1	
1131	K�benhavn K	Tornebuskegade		False	1	
1140	K�benhavn K	M�ntergade 19	Dagbladet B�rsen	False	1	
1147	K�benhavn K	Pilestr�de 34	Berlingske Tidende	False	1	
1148	K�benhavn K	Vognmagergade 11	Gutenberghus	False	1	
1150	K�benhavn K	K�bmagergade		False	1	
1151	K�benhavn K	Valkendorfsgade		False	1	
1152	K�benhavn K	L�vstr�de		False	1	
1153	K�benhavn K	Niels Hemmingsens Gade		False	1	
1154	K�benhavn K	Gr�br�dretorv		False	1	
1155	K�benhavn K	Kejsergade		False	1	
1156	K�benhavn K	Gr�br�drestr�de		False	1	
1157	K�benhavn K	Klosterstr�de		False	1	
1158	K�benhavn K	Skoubogade		False	1	
1159	K�benhavn K	Skindergade		False	1	
1160	K�benhavn K	Amagertorv		False	1	
1161	K�benhavn K	Vimmelskaftet		False	1	
1162	K�benhavn K	Jorcks Passage		False	1	
1163	K�benhavn K	Klosterg�rden		False	1	
1164	K�benhavn K	Nygade		False	1	
1165	K�benhavn K	N�rregade		False	1	
1166	K�benhavn K	Dyrk�b		False	1	
1167	K�benhavn K	Bispetorvet		False	1	
1168	K�benhavn K	Frue Plads		False	1	
1169	K�benhavn K	Store Kannikestr�de		False	1	
1170	K�benhavn K	Lille Kannikestr�de		False	1	
1171	K�benhavn K	Fiolstr�de		False	1	
1172	K�benhavn K	Krystalgade		False	1	
1173	K�benhavn K	Peder Hvitfeldts Str�de		False	1	
1174	K�benhavn K	Roseng�rden		False	1	
1175	K�benhavn K	Kultorvet		False	1	
1200	K�benhavn K	H�jbro Plads		False	1	
1201	K�benhavn K	L�derstr�de		False	1	
1202	K�benhavn K	Gammel Strand		False	1	
1203	K�benhavn K	Nybrogade		False	1	
1204	K�benhavn K	Magstr�de		False	1	
1205	K�benhavn K	Snaregade		False	1	
1206	K�benhavn K	Nabol�s		False	1	
1207	K�benhavn K	Hyskenstr�de		False	1	
1208	K�benhavn K	Kompagnistr�de		False	1	
1209	K�benhavn K	Badstuestr�de		False	1	
1210	K�benhavn K	Knabrostr�de		False	1	
1211	K�benhavn K	Brol�ggerstr�de		False	1	
1212	K�benhavn K	Vindebrogade		False	1	
1213	K�benhavn K	Bertel Thorvaldsens Plads		False	1	
1214	K�benhavn K	S�ren Kierkegaards Plads		False	1	
1214	K�benhavn K	T�jhusgade		False	1	
1215	K�benhavn K	B�rsgade		False	1	
1216	K�benhavn K	Slotsholmsgade		False	1	
1217	K�benhavn K	B�rsen		False	1	
1218	K�benhavn K	Christiansborg Ridebane		False	1	
1218	K�benhavn K	Proviantpassagen		False	1	
1218	K�benhavn K	Christiansborg		False	1	
1218	K�benhavn K	Rigsdagsg�rden		False	1	
1218	K�benhavn K	Christiansborg Slotsplads		False	1	
1218	K�benhavn K	Prins J�rgens G�rd		False	1	
1219	K�benhavn K	Christians Brygge ulige nr. + 2-22		False	1	
1220	K�benhavn K	Frederiksholms Kanal		False	1	
1240	K�benhavn K	Christiansborg	Folketinget	False	1	
1250	K�benhavn K	Sankt Ann� Plads		False	1	
1251	K�benhavn K	Kv�sthusgade		False	1	
1252	K�benhavn K	Kv�sthusbroen		False	1	
1253	K�benhavn K	Toldbodgade		False	1	
1254	K�benhavn K	Lille Strandstr�de		False	1	
1255	K�benhavn K	Store Strandstr�de		False	1	
1256	K�benhavn K	Amaliegade		False	1	
1257	K�benhavn K	Amalienborg		False	1	
1258	K�benhavn K	Larsens Plads		False	1	
1259	K�benhavn K	Nordre Toldbod		False	1	
1259	K�benhavn K	Trekroner		False	1	
1260	K�benhavn K	Bredgade		False	1	
1261	K�benhavn K	Pal�gade		False	1	
1263	K�benhavn K	Esplanaden		False	1	
1263	K�benhavn K	Churchillparken		False	1	
1264	K�benhavn K	Store Kongensgade		False	1	
1265	K�benhavn K	Frederiksgade		False	1	
1266	K�benhavn K	Bornholmsgade		False	1	
1267	K�benhavn K	Hammerensgade		False	1	
1268	K�benhavn K	Jens Kofods Gade		False	1	
1270	K�benhavn K	Gr�nningen		False	1	
1271	K�benhavn K	Poul Ankers Gade		False	1	
1291	K�benhavn K	Sankt Ann� Plads 28	J. Lauritzen A/S	False	1	
1300	K�benhavn K	Borgergade		False	1	
1301	K�benhavn K	Landgreven		False	1	
1302	K�benhavn K	Dronningens Tv�rgade		False	1	
1303	K�benhavn K	Hindegade		False	1	
1304	K�benhavn K	Adelgade		False	1	
1306	K�benhavn K	Kronprinsessegade		False	1	
1307	K�benhavn K	S�lvgade		False	1	
1307	K�benhavn K	Georg Brandes Plads		False	1	
1308	K�benhavn K	Klerkegade		False	1	
1309	K�benhavn K	Rosengade		False	1	
1310	K�benhavn K	Fredericiagade		False	1	
1311	K�benhavn K	Olfert Fischers Gade		False	1	
1312	K�benhavn K	Gammelvagt		False	1	
1313	K�benhavn K	Sankt Pauls Gade		False	1	
1314	K�benhavn K	Sankt Pauls Plads		False	1	
1315	K�benhavn K	R�vegade		False	1	
1316	K�benhavn K	Rigensgade		False	1	
1317	K�benhavn K	Stokhusgade		False	1	
1318	K�benhavn K	Krusemyntegade		False	1	
1319	K�benhavn K	Gernersgade		False	1	
1320	K�benhavn K	Haregade		False	1	
1321	K�benhavn K	Tigergade		False	1	
1322	K�benhavn K	Suensonsgade		False	1	
1323	K�benhavn K	Hjertensfrydsgade		False	1	
1324	K�benhavn K	Elsdyrsgade		False	1	
1325	K�benhavn K	Delfingade		False	1	
1326	K�benhavn K	Krokodillegade		False	1	
1327	K�benhavn K	Vildandegade		False	1	
1328	K�benhavn K	Svanegade		False	1	
1329	K�benhavn K	Timiansgade		False	1	
1349	K�benhavn K	S�lvgade 40	DSB	False	1	
1350	K�benhavn K	�ster Voldgade		False	1	
1352	K�benhavn K	R�rholmsgade		False	1	
1353	K�benhavn K	�ster Farimagsgade 1-19 + 2-2D		False	1	
1354	K�benhavn K	Ole Suhrs Gade		False	1	
1355	K�benhavn K	Gammeltoftsgade		False	1	
1356	K�benhavn K	Bartholinsgade		False	1	
1357	K�benhavn K	�ster S�gade 1 - 36		False	1	
1358	K�benhavn K	N�rre Voldgade		False	1	
1359	K�benhavn K	Ahlefeldtsgade		False	1	
1360	K�benhavn K	Frederiksborggade		False	1	
1361	K�benhavn K	Israels Plads		False	1	
1361	K�benhavn K	Linn�sgade		False	1	
1362	K�benhavn K	R�mersgade		False	1	
1363	K�benhavn K	Vendersgade		False	1	
1364	K�benhavn K	N�rre Farimagsgade		False	1	
1365	K�benhavn K	Schacksgade		False	1	
1366	K�benhavn K	Nansensgade		False	1	
1367	K�benhavn K	Kjeld Langes Gade		False	1	
1368	K�benhavn K	Turesensgade		False	1	
1369	K�benhavn K	Gyldenl�vesgade Lige nr		False	1	
1370	K�benhavn K	N�rre S�gade		False	1	
1371	K�benhavn K	S�torvet		False	1	
1390	K�benhavn K	N�rre Voldgade 68	BG-Bank	False	1	
1400	K�benhavn K	Torvegade		False	1	
1400	K�benhavn K	Knippelsbro		False	1	
1401	K�benhavn K	Strandgade		False	1	
1402	K�benhavn K	Asiatisk Plads		False	1	
1402	K�benhavn K	Johan Semps Gade		False	1	
1402	K�benhavn K	Nicolai Eigtveds Gade		False	1	
1402	K�benhavn K	David Balfours Gade		False	1	
1402	K�benhavn K	Hammersh�i Kaj		False	1	
1403	K�benhavn K	Wilders Plads		False	1	
1404	K�benhavn K	Kr�yers Plads		False	1	
1405	K�benhavn K	Gr�nlandske Handels Plads		False	1	
1406	K�benhavn K	Christianshavns Kanal		False	1	
1407	K�benhavn K	B�dsmandsstr�de		False	1	
1408	K�benhavn K	Wildersgade		False	1	
1409	K�benhavn K	Knippelsbrogade		False	1	
1410	K�benhavn K	Christianshavns Torv		False	1	
1411	K�benhavn K	Langebrogade		False	1	
1411	K�benhavn K	Applebys Plads		False	1	
1412	K�benhavn K	Voldg�rden		False	1	
1413	K�benhavn K	Ved Kanalen		False	1	
1414	K�benhavn K	Overgaden neden Vandet		False	1	
1415	K�benhavn K	Overgaden oven Vandet		False	1	
1416	K�benhavn K	Sankt Ann� Gade		False	1	
1417	K�benhavn K	Mikkel Vibes Gade		False	1	
1418	K�benhavn K	Sofiegade		False	1	
1419	K�benhavn K	Store S�ndervoldstr�de		False	1	
1420	K�benhavn K	Dronningensgade		False	1	
1421	K�benhavn K	Lille S�ndervoldstr�de		False	1	
1422	K�benhavn K	Prinsessegade		False	1	
1423	K�benhavn K	Amagergade		False	1	
1424	K�benhavn K	Christianshavns Voldgade		False	1	
1425	K�benhavn K	Ved Volden		False	1	
1426	K�benhavn K	Voldboligerne		False	1	
1427	K�benhavn K	Brobergsgade		False	1	
1428	K�benhavn K	Andreas Bj�rns Gade		False	1	
1429	K�benhavn K	Burmeistersgade		False	1	
1430	K�benhavn K	Bodenhoffs Plads		False	1	
1431	K�benhavn K	Islands Plads		False	1	
1432	K�benhavn K	Margretheholmsvej		False	1	
1432	K�benhavn K	Refshalevej		False	1	
1432	K�benhavn K	William Wains Gade		False	1	
1433	K�benhavn K	Refshale�en		False	1	
1433	K�benhavn K	Quintus		False	1	
1433	K�benhavn K	Flakfortet		False	1	
1433	K�benhavn K	Lynetten		False	1	
1433	K�benhavn K	Margretheholm		False	1	
1433	K�benhavn K	Middelgrundsfortet		False	1	
1433	K�benhavn K	Christiansholms �		False	1	
1434	K�benhavn K	Danneskiold-Sams�es All�		False	1	
1435	K�benhavn K	Philip de Langes All�		False	1	
1436	K�benhavn K	V�rftsbroen		False	1	
1436	K�benhavn K	S�artillerivej		False	1	
1436	K�benhavn K	Halvtolv		False	1	
1436	K�benhavn K	Trangravsvej		False	1	
1436	K�benhavn K	Arsenalvej		False	1	
1436	K�benhavn K	Kugleg�rdsvej		False	1	
1436	K�benhavn K	Kugleg�rden		False	1	
1437	K�benhavn K	Fabrikmestervej		False	1	
1437	K�benhavn K	Masteskursvej		False	1	
1437	K�benhavn K	Bohlendachvej		False	1	
1437	K�benhavn K	Stibolts Kvarter		False	1	
1437	K�benhavn K	Takkelloftsvej		False	1	
1437	K�benhavn K	Theodor Christensens Plads		False	1	
1437	K�benhavn K	Hohlenbergs Kvarter		False	1	
1437	K�benhavn K	Galionsvej		False	1	
1437	K�benhavn K	Krabbes Kvarter		False	1	
1437	K�benhavn K	Kanonb�dsvej		False	1	
1437	K�benhavn K	Leo Mathisens Vej		False	1	
1437	K�benhavn K	Per Knutzons Vej		False	1	
1437	K�benhavn K	Eik Skal�es Plads		False	1	
1437	K�benhavn K	Schifters Kvarter		False	1	
1438	K�benhavn K	Benstrups Kvarter		False	1	
1438	K�benhavn K	Judich�rs Plads		False	1	
1438	K�benhavn K	Judich�rs Kvarter		False	1	
1438	K�benhavn K	Dok�vej		False	1	
1438	K�benhavn K	Ekvipagemestervej		False	1	
1438	K�benhavn K	Orlogsv�rftvej		False	1	
1439	K�benhavn K	Takkeladsvej		False	1	
1439	K�benhavn K	Elefanten		False	1	
1439	K�benhavn K	H.C. Sneedorffs All�		False	1	
1439	K�benhavn K	Eskadrevej		False	1	
1439	K�benhavn K	Henrik Spans Vej		False	1	
1439	K�benhavn K	Spanteloftvej		False	1	
1439	K�benhavn K	Kongebrovej		False	1	
1439	K�benhavn K	P. L�ven�rns Vej		False	1	
1439	K�benhavn K	Henrik Gerners Plads		False	1	
1439	K�benhavn K	Krudtl�bsvej		False	1	
1439	K�benhavn K	Bradb�nken		False	1	
1439	K�benhavn K	A.H. Vedels Plads		False	1	
1440	K�benhavn K	Tinghuset		False	1	
1440	K�benhavn K	Bl� Karamel		False	1	
1440	K�benhavn K	Fredens Ark		False	1	
1440	K�benhavn K	Sydomr�det		False	1	
1440	K�benhavn K	Bj�rnekloen		False	1	
1440	K�benhavn K	Nordomr�det		False	1	
1440	K�benhavn K	M�lkeb�tten		False	1	
1440	K�benhavn K	Fabriksomr�det		False	1	
1440	K�benhavn K	L�vehuset		False	1	
1440	K�benhavn K	M�lkevejen		False	1	
1440	K�benhavn K	Psyak		False	1	
1441	K�benhavn K	Syddyssen		False	1	
1441	K�benhavn K	Midtdyssen		False	1	
1441	K�benhavn K	Norddyssen		False	1	
1448	K�benhavn K	Asiatisk Plads 2	Udenrigsministeriet	False	1	
1450	K�benhavn K	Nytorv		False	1	
1451	K�benhavn K	Larslejsstr�de		False	1	
1452	K�benhavn K	Teglg�rdstr�de		False	1	
1453	K�benhavn K	Sankt Peders Str�de		False	1	
1454	K�benhavn K	Larsbj�rnsstr�de		False	1	
1455	K�benhavn K	Studiestr�de 1-49 + 2-42		False	1	
1456	K�benhavn K	Vestergade		False	1	
1457	K�benhavn K	Gammeltorv		False	1	
1458	K�benhavn K	Kattesundet		False	1	
1459	K�benhavn K	Frederiksberggade		False	1	
1460	K�benhavn K	Mikkel Bryggers Gade		False	1	
1461	K�benhavn K	Slutterigade		False	1	
1462	K�benhavn K	Lavendelstr�de		False	1	
1463	K�benhavn K	Farvergade		False	1	
1464	K�benhavn K	Hestem�llestr�de		False	1	
1465	K�benhavn K	G�segade		False	1	
1466	K�benhavn K	R�dhusstr�de		False	1	
1467	K�benhavn K	Vandkunsten		False	1	
1468	K�benhavn K	L�ngangstr�de		False	1	
1470	K�benhavn K	Stormgade 2-16		False	1	
1471	K�benhavn K	Ny Vestergade		False	1	
1472	K�benhavn K	Ny Kongensgade,  til 17 + til 16		False	1	
1473	K�benhavn K	Bryghusgade		False	1	
1500	K�benhavn V	Bernstorffsgade 40	Vesterbro Postkontor	False	1	
1501	K�benhavn V	Postboks		False	1	
1502	K�benhavn V	Postboks		False	1	
1503	K�benhavn V	Postboks		False	1	
1504	K�benhavn V	Postboks		False	1	
1505	K�benhavn V	Postboks		False	1	
1506	K�benhavn V	Postboks		False	1	
1507	K�benhavn V	Postboks		False	1	
1508	K�benhavn V	Postboks		False	1	
1509	K�benhavn V	Postboks		False	1	
1510	K�benhavn V	Postboks		False	1	
1532	K�benhavn V	Kystvejen 26, 2770 Kastrup	Internationalt Postcenter, returforsendelser + consignment	False	1	
1533	K�benhavn V	Kystvejen 26, 2770 Kastrup	Internationalt Postcenter	False	1	
1550	K�benhavn V	Bag R�dhuset		False	1	
1550	K�benhavn V	R�dhuspladsen		False	1	
1551	K�benhavn V	Jarmers Plads		False	1	
1552	K�benhavn V	Vester Voldgade		False	1	
1553	K�benhavn V	H.C. Andersens Boulevard		False	1	
1553	K�benhavn V	Langebro		False	1	
1554	K�benhavn V	Studiestr�de 51-69 + 46-54		False	1	
1555	K�benhavn V	Stormgade Ulige nr + 18-20		False	1	
1556	K�benhavn V	Dantes Plads		False	1	
1557	K�benhavn V	Ny Kongensgade, fra 18 + fra 19		False	1	
1558	K�benhavn V	Christiansborggade		False	1	
1559	K�benhavn V	Christians Brygge 24 - 30		False	1	
1560	K�benhavn V	Kalvebod Brygge		False	1	
1561	K�benhavn V	Fisketorvet		False	1	
1561	K�benhavn V	Kalvebod Pladsvej		False	1	
1562	K�benhavn V	Hambrosgade		False	1	
1563	K�benhavn V	Otto M�nsteds Plads		False	1	
1564	K�benhavn V	Rysensteensgade		False	1	
1566	K�benhavn V	Tietgensgade 37	Post Danmark A/S	False	1	
1567	K�benhavn V	Polititorvet		False	1	
1568	K�benhavn V	Mitchellsgade		False	1	
1569	K�benhavn V	Edvard Falcks Gade		False	1	
1570	K�benhavn V	Baneg�rdspladsen		False	1	
1570	K�benhavn V	K�benhavns Hovedbaneg�rd		False	1	
1571	K�benhavn V	Otto M�nsteds Gade		False	1	
1572	K�benhavn V	Anker Heegaards Gade		False	1	
1573	K�benhavn V	Puggaardsgade		False	1	
1574	K�benhavn V	Niels Brocks Gade		False	1	
1575	K�benhavn V	Ved Glyptoteket		False	1	
1576	K�benhavn V	Stoltenbergsgade		False	1	
1577	K�benhavn V	Bernstorffsgade		False	1	
1590	K�benhavn V	Jarmers Plads 2	Realkredit Danmark	False	1	
1592	K�benhavn V	Bernstorffsgade 17-19	K�benhavns Socialdirektorat	False	1	
1599	K�benhavn V	R�dhuspladsen	K�benhavns R�dhus	False	1	
1600	K�benhavn V	Gyldenl�vesgade Ulige nr.		False	1	
1601	K�benhavn V	Vester S�gade		False	1	
1602	K�benhavn V	Nyropsgade		False	1	
1603	K�benhavn V	Dahlerupsgade		False	1	
1604	K�benhavn V	Kampmannsgade		False	1	
1605	K�benhavn V	Herholdtsgade		False	1	
1606	K�benhavn V	Vester Farimagsgade		False	1	
1607	K�benhavn V	Staunings Plads		False	1	
1608	K�benhavn V	Jernbanegade		False	1	
1609	K�benhavn V	Axeltorv		False	1	
1610	K�benhavn V	Gammel Kongevej 1-51 + 2-10		False	1	
1611	K�benhavn V	Hammerichsgade		False	1	
1612	K�benhavn V	Ved Vesterport		False	1	
1613	K�benhavn V	Meldahlsgade		False	1	
1614	K�benhavn V	Trommesalen		False	1	
1615	K�benhavn V	Sankt J�rgens All�		False	1	
1616	K�benhavn V	Stenosgade		False	1	
1617	K�benhavn V	Bagerstr�de		False	1	
1618	K�benhavn V	Tullinsgade		False	1	
1619	K�benhavn V	V�rnedamsvej Lige nr.		False	1	
1620	K�benhavn V	Vesterbros Torv		False	1	
1620	K�benhavn V	Vesterbrogade 1-151 + 2-150		False	1	
1621	K�benhavn V	Frederiksberg All� 1 - 13B		False	1	
1622	K�benhavn V	Boyesgade Ulige nr		False	1	
1623	K�benhavn V	Kingosgade 1-9 + 2-6		False	1	
1624	K�benhavn V	Brorsonsgade		False	1	
1630	K�benhavn V	Vesterbrogade 3	Tivoli A/S	False	1	
1631	K�benhavn V	Herman Triers Plads		False	1	
1632	K�benhavn V	Julius Thomsens Gade Lige nr		False	1	
1633	K�benhavn V	Kleinsgade		False	1	
1634	K�benhavn V	Rosen�rns All� 2-18		False	1	
1635	K�benhavn V	�boulevard 1-13		False	1	
1639	K�benhavn V	Gyldenl�vesgade 15	K�benhavns Skatteforvaltning	False	1	
1640	K�benhavn V	Dahlerupsgade 6	K�benhavns Folkeregister	False	1	
1650	K�benhavn V	Istedgade		False	1	
1651	K�benhavn V	Reventlowsgade		False	1	
1652	K�benhavn V	Colbj�rnsensgade		False	1	
1653	K�benhavn V	Helgolandsgade		False	1	
1654	K�benhavn V	Abel Cathrines Gade		False	1	
1655	K�benhavn V	Viktoriagade		False	1	
1656	K�benhavn V	Gasv�rksvej		False	1	
1657	K�benhavn V	Eskildsgade		False	1	
1658	K�benhavn V	Absalonsgade		False	1	
1659	K�benhavn V	Svendsgade		False	1	
1660	K�benhavn V	Otto Krabbes Plads		False	1	
1660	K�benhavn V	Dannebrogsgade		False	1	
1661	K�benhavn V	Westend		False	1	
1662	K�benhavn V	Saxogade		False	1	
1663	K�benhavn V	Oehlenschl�gersgade		False	1	
1664	K�benhavn V	Kaalundsgade		False	1	
1665	K�benhavn V	Valdemarsgade		False	1	
1666	K�benhavn V	Matth�usgade		False	1	
1667	K�benhavn V	Frederiksstadsgade		False	1	
1668	K�benhavn V	Mysundegade		False	1	
1669	K�benhavn V	Flensborggade		False	1	
1670	K�benhavn V	Enghave Plads		False	1	
1671	K�benhavn V	Tove Ditlevsens Plads		False	1	
1671	K�benhavn V	Haderslevgade		False	1	
1672	K�benhavn V	Broagergade		False	1	
1673	K�benhavn V	Ullerupgade		False	1	
1674	K�benhavn V	Enghavevej, til 79 + til 78		False	1	
1675	K�benhavn V	Kongsh�jgade		False	1	
1676	K�benhavn V	Sankelmarksgade		False	1	
1677	K�benhavn V	Gr�stensgade		False	1	
1699	K�benhavn V	Staldgade		False	1	
1700	K�benhavn V	Halmtorvet		False	1	
1701	K�benhavn V	Reverdilsgade		False	1	
1702	K�benhavn V	Stampesgade		False	1	
1703	K�benhavn V	Lille Colbj�rnsensgade		False	1	
1704	K�benhavn V	Tietgensgade		False	1	
1705	K�benhavn V	Ingerslevsgade		False	1	
1706	K�benhavn V	Lille Istedgade		False	1	
1707	K�benhavn V	Maria Kirkeplads		False	1	
1708	K�benhavn V	Eriksgade		False	1	
1709	K�benhavn V	Skydebanegade		False	1	
1710	K�benhavn V	Kv�gtorvsgade		False	1	
1711	K�benhavn V	Fl�sketorvet		False	1	
1712	K�benhavn V	H�kerboderne		False	1	
1713	K�benhavn V	Kv�gtorvet		False	1	
1714	K�benhavn V	K�dboderne		False	1	
1715	K�benhavn V	Slagtehusgade		False	1	
1716	K�benhavn V	Slagterboderne		False	1	
1717	K�benhavn V	Skelb�kgade		False	1	
1718	K�benhavn V	Sommerstedgade		False	1	
1719	K�benhavn V	Krus�gade		False	1	
1720	K�benhavn V	S�nder Boulevard		False	1	
1721	K�benhavn V	Dybb�lsgade		False	1	
1722	K�benhavn V	Godsbanegade		False	1	
1723	K�benhavn V	Letlandsgade		False	1	
1724	K�benhavn V	Estlandsgade		False	1	
1725	K�benhavn V	Esbern Snares Gade		False	1	
1726	K�benhavn V	Arkonagade		False	1	
1727	K�benhavn V	Asger Rygs Gade		False	1	
1728	K�benhavn V	Skjalm Hvides Gade		False	1	
1729	K�benhavn V	Sigerstedgade		False	1	
1730	K�benhavn V	Knud Lavards Gade		False	1	
1731	K�benhavn V	Erik Ejegods Gade		False	1	
1732	K�benhavn V	Bodilsgade		False	1	
1733	K�benhavn V	Palnatokesgade		False	1	
1734	K�benhavn V	Heilsgade		False	1	
1735	K�benhavn V	R�ddinggade		False	1	
1736	K�benhavn V	Bevtoftgade		False	1	
1737	K�benhavn V	Bustrupgade		False	1	
1738	K�benhavn V	Stenderupgade		False	1	
1739	K�benhavn V	Enghave Passage		False	1	
1748	K�benhavn V	Kammasvej 2		False	1	
1749	K�benhavn V	Rahbeks All� 3-15		False	1	
1750	K�benhavn V	Vesterf�lledvej		False	1	
1751	K�benhavn V	Sundevedsgade		False	1	
1752	K�benhavn V	T�ndergade		False	1	
1753	K�benhavn V	Ballumgade		False	1	
1754	K�benhavn V	Hedebygade		False	1	
1755	K�benhavn V	M�gelt�ndergade		False	1	
1756	K�benhavn V	Amerikavej		False	1	
1757	K�benhavn V	Tr�jborggade		False	1	
1758	K�benhavn V	Lyrskovgade		False	1	
1759	K�benhavn V	Rejsbygade		False	1	
1760	K�benhavn V	Ny Carlsberg Vej		False	1	
1761	K�benhavn V	Ejderstedgade		False	1	
1762	K�benhavn V	Slesvigsgade		False	1	
1763	K�benhavn V	Dannevirkegade		False	1	
1764	K�benhavn V	Alsgade		False	1	
1765	K�benhavn V	Angelgade		False	1	
1766	K�benhavn V	Slien		False	1	
1770	K�benhavn V	Carstensgade		False	1	
1771	K�benhavn V	Lundbyesgade		False	1	
1772	K�benhavn V	Ernst Meyers Gade		False	1	
1773	K�benhavn V	Bissensgade		False	1	
1774	K�benhavn V	K�chlersgade		False	1	
1775	K�benhavn V	Freundsgade		False	1	
1777	K�benhavn V	Jerichausgade		False	1	
1778	K�benhavn V	Pasteursvej		False	1	
1780	K�benhavn V		Erhvervskunder	False	1	
1782	K�benhavn V	Ufrankerede svarforsendelser		False	1	
1784	K�benhavn V	Gerdasgade 37	Forlagsgruppen (ufrankerede svarforsendelser)	False	1	
1785	K�benhavn V	R�dhuspladsen 33 og 37	Politiken og Ekstrabladet	False	1	
1786	K�benhavn V	Vesterbrogade 8	Unibank	False	1	
1787	K�benhavn V	H.C. Andersens Boulevard 18	Dansk Industri	False	1	
1788	K�benhavn V		Erhvervskunder	False	1	
1789	K�benhavn V	H.C. Andersens Boulevard 12	Star Tour A/S	False	1	
1790	K�benhavn V		Erhvervskunder	False	1	
1795	K�benhavn V	Gerdasgade 35-37	Bogklubforlag	False	1	
1799	K�benhavn V	Vester F�lledvej 100	Carlsberg	False	1	
1800	Frederiksberg C	Vesterbrogade, fra 152 og 153		False	1	
1801	Frederiksberg C	Rahbeks All� 2-36 + 17-23		False	1	
1802	Frederiksberg C	Halls All�		False	1	
1803	Frederiksberg C	Br�ndsteds All�		False	1	
1804	Frederiksberg C	Bakkeg�rds All�		False	1	
1805	Frederiksberg C	Kammasvej 1-3 + 4		False	1	
1806	Frederiksberg C	Jacobys All�		False	1	
1807	Frederiksberg C	Schlegels All�		False	1	
1808	Frederiksberg C	Asmussens All�		False	1	
1809	Frederiksberg C	Frydendalsvej		False	1	
1810	Frederiksberg C	Platanvej		False	1	
1811	Frederiksberg C	Asg�rdsvej		False	1	
1812	Frederiksberg C	Kochsvej		False	1	
1813	Frederiksberg C	Henrik Ibsens Vej		False	1	
1814	Frederiksberg C	Carit Etlars Vej		False	1	
1815	Frederiksberg C	Paludan M�llers Vej		False	1	
1816	Frederiksberg C	Engtoftevej		False	1	
1817	Frederiksberg C	Carl Bernhards Vej		False	1	
1818	Frederiksberg C	Kingosgade 8-12 + 11-17		False	1	
1819	Frederiksberg C	V�rnedamsvej Ulige nr.		False	1	
1820	Frederiksberg C	Frederiksberg All� 15-65 + 2-104		False	1	
1822	Frederiksberg C	Boyesgade Lige nr		False	1	
1823	Frederiksberg C	Haveselskabetsvej		False	1	
1824	Frederiksberg C	Sankt Thomas All�		False	1	
1825	Frederiksberg C	Hauchsvej		False	1	
1826	Frederiksberg C	Alhambravej		False	1	
1827	Frederiksberg C	Mynstersvej		False	1	
1828	Frederiksberg C	Martensens All�		False	1	
1829	Frederiksberg C	Madvigs All�		False	1	
1835	Frederiksberg C	Postboks	inkl. Frederiksberg C Postkontor	False	1	
1850	Frederiksberg C	Gammel Kongevej 85-179 + 60-178		False	1	
1851	Frederiksberg C	Nyvej		False	1	
1852	Frederiksberg C	Amicisvej		False	1	
1853	Frederiksberg C	Maglekildevej		False	1	
1854	Frederiksberg C	Dr. Priemes Vej		False	1	
1855	Frederiksberg C	Holl�ndervej		False	1	
1856	Frederiksberg C	Edisonsvej		False	1	
1857	Frederiksberg C	Hortensiavej		False	1	
1860	Frederiksberg C	Christian Winthers Vej		False	1	
1861	Frederiksberg C	Sagasvej		False	1	
1862	Frederiksberg C	Rathsacksvej		False	1	
1863	Frederiksberg C	Ceresvej		False	1	
1864	Frederiksberg C	Grundtvigsvej		False	1	
1865	Frederiksberg C	Grundtvigs Sidevej		False	1	
1866	Frederiksberg C	Henrik Steffens Vej		False	1	
1867	Frederiksberg C	Acaciavej		False	1	
1868	Frederiksberg C	Bianco Lunos All�		False	1	
1870	Frederiksberg C	B�lowsvej		False	1	
1871	Frederiksberg C	Thorvaldsensvej		False	1	
1872	Frederiksberg C	Bomhoffs Have		False	1	
1873	Frederiksberg C	Helenevej		False	1	
1874	Frederiksberg C	Harsdorffsvej		False	1	
1875	Frederiksberg C	Amalievej		False	1	
1876	Frederiksberg C	Kastanievej		False	1	
1877	Frederiksberg C	Lindevej		False	1	
1878	Frederiksberg C	Uraniavej		False	1	
1879	Frederiksberg C	H.C. �rsteds Vej		False	1	
1900	Frederiksberg C	Vodroffsvej		False	1	
1901	Frederiksberg C	T�rnborgvej		False	1	
1902	Frederiksberg C	Lykkesholms All�		False	1	
1903	Frederiksberg C	Sankt Knuds Vej		False	1	
1904	Frederiksberg C	Forh�bningsholms All�		False	1	
1905	Frederiksberg C	Svanholmsvej		False	1	
1906	Frederiksberg C	Sch�nbergsgade		False	1	
1908	Frederiksberg C	Prinsesse Maries All�		False	1	
1909	Frederiksberg C	Vodroffs Tv�rgade		False	1	
1910	Frederiksberg C	Danasvej		False	1	
1911	Frederiksberg C	Niels Ebbesens Vej		False	1	
1912	Frederiksberg C	Svend Tr�sts Vej		False	1	
1913	Frederiksberg C	Carl Plougs Vej		False	1	
1914	Frederiksberg C	Vodroffslund		False	1	
1915	Frederiksberg C	Danas Plads		False	1	
1916	Frederiksberg C	Norsvej		False	1	
1917	Frederiksberg C	Sveasvej		False	1	
1920	Frederiksberg C	Forchhammersvej		False	1	
1921	Frederiksberg C	Sankt Markus Plads		False	1	
1922	Frederiksberg C	Sankt Markus All�		False	1	
1923	Frederiksberg C	Johnstrups All�		False	1	
1924	Frederiksberg C	Steenstrups All�		False	1	
1925	Frederiksberg C	Julius Thomsens Plads		False	1	
1926	Frederiksberg C	Martinsvej		False	1	
1927	Frederiksberg C	Suomisvej		False	1	
1928	Frederiksberg C	Filippavej		False	1	
1931	Frederiksberg C	Ufrankerede svarforsendelser 		False	1	
1950	Frederiksberg C	Hostrupsvej		False	1	
1951	Frederiksberg C	Christian Richardts Vej		False	1	
1952	Frederiksberg C	Falkonerv�nget		False	1	
1953	Frederiksberg C	Sankt Nikolaj Vej		False	1	
1954	Frederiksberg C	Hostrups Have		False	1	
1955	Frederiksberg C	Dr. Abildgaards All�		False	1	
1956	Frederiksberg C	L.I. Brandes All�		False	1	
1957	Frederiksberg C	N.J. Fjords All�		False	1	
1958	Frederiksberg C	Rolighedsvej		False	1	
1959	Frederiksberg C	Falkonerg�rdsvej		False	1	
1960	Frederiksberg C	�boulevard 15-55		False	1	
1961	Frederiksberg C	J.M. Thieles Vej		False	1	
1962	Frederiksberg C	Fuglevangsvej		False	1	
1963	Frederiksberg C	Bille Brahes Vej		False	1	
1964	Frederiksberg C	Ingemannsvej		False	1	
1965	Frederiksberg C	Erik Menveds Vej		False	1	
1966	Frederiksberg C	Steenwinkelsvej		False	1	
1967	Frederiksberg C	Svanemoseg�rdsvej		False	1	
1970	Frederiksberg C	Rosen�rns All� 1-65 + 20-70		False	1	
1971	Frederiksberg C	Adolph Steens All�		False	1	
1972	Frederiksberg C	Worsaaesvej		False	1	
1973	Frederiksberg C	Jakob Dannef�rds Vej		False	1	
1974	Frederiksberg C	Julius Thomsens Gade Ulige nr		False	1	
1999	Frederiksberg C	Rosen�rns All� 22	Danmarks Radio	False	1	
2000	Frederiksberg			False	1	
2100	K�benhavn �			False	1	
2200	K�benhavn N			False	1	
2300	K�benhavn S			False	1	
2400	K�benhavn NV			False	1	
2450	K�benhavn SV			False	1	
2500	Valby			False	1	
2600	Glostrup			True	1	
2605	Br�ndby			True	1	
2610	R�dovre			True	1	
2620	Albertslund			True	1	
2625	Vallensb�k			True	1	
2630	Taastrup			True	1	
2633	Taastrup		Erhvervskunder	True	1	
2635	Ish�j			True	1	
2640	Hedehusene			True	1	
2650	Hvidovre			True	1	
2660	Br�ndby Strand			True	1	
2665	Vallensb�k Strand			True	1	
2670	Greve			True	1	
2680	Solr�d Strand			True	1	
2690	Karlslunde			True	1	
2700	Br�nsh�j			False	1	
2720	Vanl�se			False	1	
2730	Herlev			True	1	
2740	Skovlunde			True	1	
2750	Ballerup			True	1	
2760	M�l�v			True	1	
2765	Sm�rum			True	1	
2770	Kastrup			True	1	
2791	Drag�r			True	1	
2800	Kongens Lyngby			True	1	
2820	Gentofte			True	1	
2830	Virum			True	1	
2840	Holte			True	1	
2850	N�rum			True	1	
2860	S�borg			True	1	
2870	Dysseg�rd 			True	1	
2880	Bagsv�rd			True	1	
2900	Hellerup			True	1	
2920	Charlottenlund			True	1	
2930	Klampenborg			True	1	
2942	Skodsborg			True	1	
2950	Vedb�k			True	1	
2960	Rungsted Kyst			True	1	
2970	H�rsholm			True	1	
2980	Kokkedal			True	1	
2990	Niv�			True	1	
3000	Helsing�r			True	1	
3050	Humleb�k			True	1	
3060	Esperg�rde			True	1	
3070	Snekkersten			True	1	
3080	Tik�b			True	1	
3100	Hornb�k			True	1	
3120	Dronningm�lle			True	1	
3140	�lsg�rde			True	1	
3150	Helleb�k			True	1	
3200	Helsinge			True	1	
3210	Vejby			True	1	
3220	Tisvildeleje			True	1	
3230	Gr�sted			True	1	
3250	Gilleleje			True	1	
3300	Frederiksv�rk			True	1	
3310	�lsted			True	1	
3320	Sk�vinge			True	1	
3330	G�rl�se			True	1	
3360	Liseleje			True	1	
3370	Melby			True	1	
3390	Hundested			True	1	
3400	Hiller�d			True	1	
3450	Aller�d			True	1	
3460	Birker�d			True	1	
3480	Fredensborg			True	1	
3490	Kvistg�rd			True	1	
3500	V�rl�se			True	1	
3520	Farum			True	1	
3540	Lynge			True	1	
3550	Slangerup			True	1	
3600	Frederikssund			True	1	
3630	J�gerspris			True	1	
3650	�lstykke			True	1	
3660	Stenl�se			True	1	
3670	Veks� Sj�lland			True	1	
3700	R�nne			True	1	
3720	Aakirkeby			True	1	
3730	Nex�			True	1	
3740	Svaneke			True	1	
3751	�stermarie			True	1	
3760	Gudhjem			True	1	
3770	Allinge			True	1	
3782	Klemensker			True	1	
3790	Hasle			True	1	
4000	Roskilde			True	1	
4040	Jyllinge			True	1	
4050	Skibby			True	1	
4060	Kirke S�by			True	1	
4070	Kirke Hyllinge			True	1	
4100	Ringsted			True	1	
4105	Ringsted		Midtsj�llands Postcenter + erhvervskunder	True	1	
4129	Ringsted	Ufrankerede svarforsendelser		True	1	
4130	Viby Sj�lland			True	1	
4140	Borup			True	1	
4160	Herlufmagle			True	1	
4171	Glums�			True	1	
4173	Fjenneslev			True	1	
4174	Jystrup Midtsj			True	1	
4180	Sor�			True	1	
4190	Munke Bjergby			True	1	
4200	Slagelse			True	1	
4220	Kors�r			True	1	
4230	Sk�lsk�r			True	1	
4241	Vemmelev			True	1	
4242	Boeslunde			True	1	
4243	Rude			True	1	
4250	Fuglebjerg			True	1	
4261	Dalmose			True	1	
4262	Sandved			True	1	
4270	H�ng			True	1	
4281	G�rlev			True	1	
4291	Ruds Vedby			True	1	
4293	Dianalund			True	1	
4295	Stenlille			True	1	
4296	Nyrup			True	1	
4300	Holb�k			True	1	
4320	Lejre			True	1	
4330	Hvals�			True	1	
4340	T�ll�se			True	1	
4350	Ugerl�se			True	1	
4360	Kirke Eskilstrup			True	1	
4370	Store Merl�se			True	1	
4390	Vipper�d			True	1	
4400	Kalundborg			True	1	
4420	Regstrup			True	1	
4440	M�rk�v			True	1	
4450	Jyderup			True	1	
4460	Snertinge			True	1	
4470	Sveb�lle			True	1	
4480	Store Fuglede			True	1	
4490	Jerslev Sj�lland			True	1	
4500	Nyk�bing Sj			True	1	
4520	Svinninge			True	1	
4532	Gislinge			True	1	
4534	H�rve			True	1	
4540	F�revejle			True	1	
4550	Asn�s			True	1	
4560	Vig			True	1	
4571	Grevinge			True	1	
4572	N�rre Asmindrup			True	1	
4573	H�jby			True	1	
4581	R�rvig			True	1	
4583	Sj�llands Odde			True	1	
4591	F�llenslev			True	1	
4592	Sejer�			True	1	
4593	Eskebjerg			True	1	
4600	K�ge			True	1	
4621	Gadstrup			True	1	
4622	Havdrup			True	1	
4623	Lille Skensved			True	1	
4632	Bj�verskov			True	1	
4640	Fakse			True	1	
4652	H�rlev			True	1	
4653	Karise			True	1	
4654	Fakse Ladeplads			True	1	
4660	Store Heddinge			True	1	
4671	Str�by			True	1	
4672	Klippinge			True	1	
4673	R�dvig Stevns			True	1	
4681	Herf�lge			True	1	
4682	Tureby			True	1	
4683	R�nnede			True	1	
4684	Holmegaard 			True	1	
4690	Haslev			True	1	
4700	N�stved			True	1	
4720	Pr�st�			True	1	
4733	Tappern�je			True	1	
4735	Mern			True	1	
4736	Karreb�ksminde			True	1	
4750	Lundby			True	1	
4760	Vordingborg			True	1	
4771	Kalvehave			True	1	
4772	Langeb�k			True	1	
4773	Stensved			True	1	
4780	Stege			True	1	
4791	Borre			True	1	
4792	Askeby			True	1	
4793	Bog� By			True	1	
4800	Nyk�bing F			True	1	
4840	N�rre Alslev			True	1	
4850	Stubbek�bing			True	1	
4862	Guldborg			True	1	
4863	Eskilstrup			True	1	
4871	Horbelev			True	1	
4872	Idestrup			True	1	
4873	V�ggerl�se			True	1	
4874	Gedser			True	1	
4880	Nysted			True	1	
4891	Toreby L			True	1	
4892	Kettinge			True	1	
4894	�ster Ulslev			True	1	
4895	Errindlev			True	1	
4900	Nakskov			True	1	
4912	Harpelunde			True	1	
4913	Horslunde			True	1	
4920	S�llested			True	1	
4930	Maribo			True	1	
4941	Bandholm			True	1	
4943	Torrig L			True	1	
4944	Fej�			True	1	
4951	N�rreballe			True	1	
4952	Stokkemarke			True	1	
4953	Vesterborg			True	1	
4960	Holeby			True	1	
4970	R�dby			True	1	
4983	Dannemare			True	1	
4990	Saksk�bing			True	1	
5000	Odense C			True	1	
5029	Odense C	Ufrankerede svarforsendelser		True	1	
5090	Odense C		Erhvervskunder	True	1	
5100	Odense C	Postboks		True	1	
5200	Odense V			True	1	
5210	Odense NV			True	1	
5220	Odense S�			True	1	
5230	Odense M			True	1	
5240	Odense N�			True	1	
5250	Odense SV			True	1	
5260	Odense S			True	1	
5270	Odense N			True	1	
5290	Marslev			True	1	
5300	Kerteminde			True	1	
5320	Agedrup			True	1	
5330	Munkebo			True	1	
5350	Rynkeby			True	1	
5370	Mesinge			True	1	
5380	Dalby			True	1	
5390	Martofte			True	1	
5400	Bogense			True	1	
5450	Otterup			True	1	
5462	Morud			True	1	
5463	Harndrup			True	1	
5464	Brenderup Fyn			True	1	
5466	Asperup			True	1	
5471	S�nders�			True	1	
5474	Veflinge			True	1	
5485	Skamby			True	1	
5491	Blommenslyst			True	1	
5492	Vissenbjerg			True	1	
5500	Middelfart			True	1	
5540	Ullerslev			True	1	
5550	Langeskov			True	1	
5560	Aarup			True	1	
5580	N�rre Aaby			True	1	
5591	Gelsted			True	1	
5592	Ejby			True	1	
5600	Faaborg			True	1	
5610	Assens			True	1	
5620	Glamsbjerg			True	1	
5631	Ebberup			True	1	
5642	Millinge			True	1	
5672	Broby			True	1	
5683	Haarby			True	1	
5690	Tommerup			True	1	
5700	Svendborg			True	1	
5750	Ringe			True	1	
5762	Vester Skerninge			True	1	
5771	Stenstrup			True	1	
5772	Kv�rndrup			True	1	
5792	�rslev			True	1	
5800	Nyborg			True	1	
5853	�rb�k			True	1	
5854	Gislev			True	1	
5856	Ryslinge			True	1	
5863	Ferritslev Fyn			True	1	
5871	Fr�rup			True	1	
5874	Hesselager			True	1	
5881	Sk�rup Fyn			True	1	
5882	Vejstrup			True	1	
5883	Oure			True	1	
5884	Gudme			True	1	
5892	Gudbjerg Sydfyn			True	1	
5900	Rudk�bing			True	1	
5932	Humble			True	1	
5935	Bagenkop			True	1	
5953	Tranek�r			True	1	
5960	Marstal			True	1	
5970	�r�sk�bing			True	1	
5985	S�by �r�			True	1	
6000	Kolding			True	1	
6040	Egtved			True	1	
6051	Almind			True	1	
6052	Viuf			True	1	
6064	Jordrup			True	1	
6070	Christiansfeld			True	1	
6091	Bjert			True	1	
6092	S�nder Stenderup			True	1	
6093	Sj�lund			True	1	
6094	Hejls			True	1	
6100	Haderslev			True	1	
6200	Aabenraa			True	1	
6230	R�dekro			True	1	
6240	L�gumkloster			True	1	
6261	Bredebro			True	1	
6270	T�nder			True	1	
6280	H�jer			True	1	
6300	Gr�sten			True	1	
6310	Broager			True	1	
6320	Egernsund			True	1	
6330	Padborg			True	1	
6340	Krus�			True	1	
6360	Tinglev			True	1	
6372	Bylderup-Bov			True	1	
6392	Bolderslev			True	1	
6400	S�nderborg			True	1	
6430	Nordborg			True	1	
6440	Augustenborg			True	1	
6470	Sydals			True	1	
6500	Vojens			True	1	
6510	Gram			True	1	
6520	Toftlund			True	1	
6534	Agerskov			True	1	
6535	Branderup J			True	1	
6541	Bevtoft			True	1	
6560	Sommersted			True	1	
6580	Vamdrup			True	1	
6600	Vejen			True	1	
6621	Gesten			True	1	
6622	B�kke			True	1	
6623	Vorbasse			True	1	
6630	R�dding			True	1	
6640	Lunderskov			True	1	
6650	Br�rup			True	1	
6660	Lintrup			True	1	
6670	Holsted			True	1	
6682	Hovborg			True	1	
6683	F�vling			True	1	
6690	G�rding			True	1	
6700	Esbjerg			True	1	
6701	Esbjerg	Postboks		True	1	
6705	Esbjerg �			True	1	
6710	Esbjerg V			True	1	
6715	Esbjerg N			True	1	
6720	Fan�			True	1	
6731	Tj�reborg			True	1	
6740	Bramming			True	1	
6752	Glejbjerg			True	1	
6753	Agerb�k			True	1	
6760	Ribe			True	1	
6771	Gredstedbro			True	1	
6780	Sk�rb�k			True	1	
6792	R�m�			True	1	
6800	Varde			True	1	
6818	�rre			True	1	
6823	Ansager			True	1	
6830	N�rre Nebel			True	1	
6840	Oksb�l			True	1	
6851	Janderup Vestj			True	1	
6852	Billum			True	1	
6853	Vejers Strand			True	1	
6854	Henne			True	1	
6855	Outrup			True	1	
6857	Bl�vand			True	1	
6862	Tistrup			True	1	
6870	�lgod			True	1	
6880	Tarm			True	1	
6893	Hemmet			True	1	
6900	Skjern			True	1	
6920	Videb�k			True	1	
6933	Kib�k			True	1	
6940	Lem St			True	1	
6950	Ringk�bing			True	1	
6960	Hvide Sande			True	1	
6971	Spjald			True	1	
6973	�rnh�j			True	1	
6980	Tim			True	1	
6990	Ulfborg			True	1
7000	Fredericia			True	1	
7007	Fredericia		Sydjyllands Postcenter + erhvervskunder	True	1	
7029	Fredericia	Ufrankerede svarforsendelser		True	1	
7080	B�rkop			True	1	
7100	Vejle			True	1	
7120	Vejle �st			True	1	
7130	Juelsminde			True	1	
7140	Stouby			True	1	
7150	Barrit			True	1	
7160	T�rring			True	1	
7171	Uldum			True	1	
7173	Vonge			True	1	
7182	Bredsten			True	1	
7183	Randb�l			True	1	
7184	Vandel			True	1	
7190	Billund			True	1	
7200	Grindsted			True	1	
7250	Hejnsvig			True	1	
7260	S�nder Omme			True	1	
7270	Stakroge			True	1	
7280	S�nder Felding			True	1	
7300	Jelling			True	1	
7321	Gadbjerg			True	1	
7323	Give			True	1	
7330	Brande			True	1	
7361	Ejstrupholm			True	1	
7362	Hampen			True	1	
7400	Herning			True	1	
7401	Herning		Erhvervskunder	True	1	
7429	Herning	Ufrankerede svarforsendelser		True	1	
7430	Ikast			True	1	
7441	Bording			True	1	
7442	Engesvang			True	1	
7451	Sunds			True	1	
7470	Karup J			True	1	
7480	Vildbjerg			True	1	
7490	Aulum			True	1	
7500	Holstebro			True	1	
7540	Haderup			True	1	
7550	S�rvad			True	1	
7560	Hjerm			True	1	
7570	Vemb			True	1	
7600	Struer			True	1	
7620	Lemvig			True	1	
7650	B�vlingbjerg			True	1	
7660	B�kmarksbro			True	1	
7673	Harbo�re			True	1	
7680	Thybor�n			True	1	
7700	Thisted			True	1	
7730	Hanstholm			True	1	
7741	Fr�strup			True	1	
7742	Vesl�s			True	1	
7752	Snedsted			True	1	
7755	Bedsted Thy			True	1	
7760	Hurup Thy			True	1	
7770	Vestervig			True	1	
7790	Thyholm			True	1	
7800	Skive			True	1	
7830	Vinderup			True	1	
7840	H�jslev			True	1	
7850	Stoholm Jyll			True	1	
7860	Sp�ttrup			True	1	
7870	Roslev			True	1	
7884	Fur			True	1	
7900	Nyk�bing M			True	1	
7950	Erslev			True	1	
7960	Karby			True	1	
7970	Redsted M			True	1	
7980	Vils			True	1	
7990	�ster Assels			True	1	
8000	�rhus C			True	1	
8100	�rhus C	Postboks		True	1	
8200	�rhus N			True	1	
8210	�rhus V			True	1	
8220	Brabrand			True	1	
8229	Risskov �	Ufrankerede svarforsendelser		True	1	
8230	�byh�j			True	1	
8240	Risskov			True	1	
8245	Risskov �		�stjyllands Postcenter + erhvervskunder	True	1	
8250	Eg�			True	1	
8260	Viby J			True	1	
8270	H�jbjerg			True	1	
8300	Odder			True	1	
8305	Sams�			True	1	
8310	Tranbjerg J			True	1	
8320	M�rslet			True	1	
8330	Beder			True	1	
8340	Malling			True	1	
8350	Hundslund			True	1	
8355	Solbjerg			True	1	
8361	Hasselager			True	1	
8362	H�rning			True	1	
8370	Hadsten			True	1	
8380	Trige			True	1	
8381	Tilst			True	1	
8382	Hinnerup			True	1	
8400	Ebeltoft			True	1	
8410	R�nde			True	1	
8420	Knebel			True	1	
8444	Balle			True	1	
8450	Hammel			True	1	
8462	Harlev J			True	1	
8464	Galten			True	1	
8471	Sabro			True	1	
8472	Sporup			True	1	
8500	Grenaa			True	1	
8520	Lystrup			True	1	
8530	Hjortsh�j			True	1	
8541	Sk�dstrup			True	1	
8543	Hornslet			True	1	
8544	M�rke			True	1	
8550	Ryomg�rd			True	1	
8560	Kolind			True	1	
8570	Trustrup			True	1	
8581	Nimtofte			True	1	
8585	Glesborg			True	1	
8586	�rum Djurs			True	1	
8592	Anholt			True	1	
8600	Silkeborg			True	1	
8620	Kjellerup			True	1	
8632	Lemming			True	1	
8641	Sorring			True	1	
8643	Ans By			True	1	
8653	Them			True	1	
8654	Bryrup			True	1	
8660	Skanderborg			True	1	
8670	L�sby			True	1	
8680	Ry			True	1	
8700	Horsens			True	1	
8721	Daug�rd			True	1	
8722	Hedensted			True	1	
8723	L�sning			True	1	
8732	Hovedg�rd			True	1	
8740	Br�dstrup			True	1	
8751	Gedved			True	1	
8752	�stbirk			True	1	
8762	Flemming			True	1	
8763	Rask M�lle			True	1	
8765	Klovborg			True	1	
8766	N�rre Snede			True	1	
8781	Stenderup			True	1	
8783	Hornsyld			True	1	
8800	Viborg			True	1	
8830	Tjele			True	1	
8831	L�gstrup			True	1	
8832	Skals			True	1	
8840	R�dk�rsbro			True	1	
8850	Bjerringbro			True	1	
8860	Ulstrup			True	1	
8870	Lang�			True	1	
8881	Thors�			True	1	
8882	F�rvang			True	1	
8883	Gjern			True	1	
8900	Randers			True	1	
8950	�rsted			True	1	
8961	Alling�bro			True	1	
8963	Auning			True	1	
8970	Havndal			True	1	
8981	Spentrup			True	1	
8983	Gjerlev J			True	1	
8990	F�rup			True	1	
9000	Aalborg			True	1	
9020	Aalborg		Erhvervskunder	True	1	
9029	Aalborg	Ufrankerede svarforsendelser		True	1	
9100	Aalborg	Postboks		True	1	
9200	Aalborg SV			True	1	
9210	Aalborg S�			True	1	
9220	Aalborg �st			True	1	
9230	Svenstrup J			True	1	
9240	Nibe			True	1	
9260	Gistrup			True	1	
9270	Klarup			True	1	
9280	Storvorde			True	1	
9293	Kongerslev			True	1	
9300	S�by			True	1	
9310	Vodskov			True	1	
9320	Hjallerup			True	1	
9330	Dronninglund			True	1	
9340	Asaa			True	1	
9352	Dybvad			True	1	
9362	Gandrup			True	1	
9370	Hals			True	1	
9380	Vestbjerg			True	1	
9381	Sulsted			True	1	
9382	Tylstrup			True	1	
9400	N�rresundby			True	1	
9430	Vadum			True	1	
9440	Aabybro			True	1	
9460	Brovst			True	1	
9480	L�kken			True	1	
9490	Pandrup			True	1	
9492	Blokhus			True	1	
9493	Saltum			True	1	
9500	Hobro			True	1	
9510	Arden			True	1	
9520	Sk�rping			True	1	
9530	St�vring			True	1	
9541	Suldrup			True	1	
9550	Mariager			True	1	
9560	Hadsund			True	1	
9574	B�lum			True	1	
9575	Terndrup			True	1	
9600	Aars			True	1	
9610	N�rager			True	1	
9620	Aalestrup			True	1	
9631	Gedsted			True	1	
9632	M�ldrup			True	1	
9640	Fars�			True	1	
9670	L�gst�r			True	1	
9681	Ranum			True	1	
9690	Fjerritslev			True	1	
9700	Br�nderslev			True	1	
9740	Jerslev J			True	1	
9750	�stervr�			True	1	
9760	Vr�			True	1	
9800	Hj�rring			True	1	
9830	T�rs			True	1	
9850	Hirtshals			True	1	
9870	Sindal			True	1	
9881	Bindslev			True	1	
9900	Frederikshavn			True	1	
9940	L�s�			True	1	
9970	Strandby			True	1	
9981	Jerup			True	1	
9982	�lb�k			True	1	
9990	Skagen			True	1	
3900	Nuuk			False	2	
3905	Nuussuaq			False	2	
3910	Kangerlussuaq			False	2	
3911	Sisimiut			False	2	
3912	Maniitsoq			False	2	
3913	Tasiilaq			False	2	
3915	Kulusuk			False	2	
3919	Alluitsup Paa			False	2	
3920	Qaqortoq			False	2	
3921	Narsaq			False	2	
3922	Nanortalik			False	2	
3923	Narsarsuaq			False	2	
3924	Ikerasassuaq			False	2	
3930	Kangilinnguit			False	2	
3932	Arsuk			False	2	
3940	Paamiut			False	2	
3950	Aasiaat			False	2	
3951	Qasigiannguit			False	2	
3952	Ilulissat			False	2	
3953	Qeqertarsuaq			False	2	
3955	Kangaatsiaq			False	2	
3961	Uummannaq			False	2	
3962	Upernavik			False	2	
3964	Qaarsut			False	2	
3970	Pituffik			False	2	
3971	Qaanaaq			False	2	
3980	Ittoqqortoormiit			False	2	
3984	Danmarkshavn			False	2	
3985	Constable Pynt			False	2	
100	T�rshavn			False	3	
110	T�rshavn 	Postboks		False	3	
160	Argir			False	3	
165	Argir 	Postboks		False	3	
175	Kirkjub�ur			False	3	
176	Velbastadur			False	3	
177	Sydradalur, Streymoy			False	3	
178	Nordradalur			False	3	
180	Kaldbak			False	3	
185	Kaldbaksbotnur			False	3	
186	Sund			False	3	
187	Hvitanes			False	3	
188	Hoyv�k			False	3	
210	Sandur			False	3	
215	Sandur	Postboks		False	3	
220	Sk�lav�k			False	3	
230	H�sav�k			False	3	
235	Dalur			False	3	
236	Skarvanes			False	3	
240	Skopun			False	3	
260	Sk�voy			False	3	
270	N�lsoy			False	3	
280	Hestur			False	3	
285	Koltur			False	3	
286	St�ra Dimun			False	3	
330	Stykkid			False	3	
335	Leynar			False	3	
336	Sk�llingur			False	3	
340	Kv�v�k			False	3	
350	Vestmanna			False	3	
355	Vestmanna	Postboks		False	3	
358	V�lur			False	3	
360	Sandav�gur			False	3	
370	Midv�gur			False	3	
375	Midv�gur	Postboks		False	3	
380	S�rv�gur			False	3	
385	Vatnsoyrar			False	3	
386	B�ur			False	3	
387	G�sadalur			False	3	
388	Mykines			False	3	
400	Oyrarbakki			False	3	
405	Oyrarbakki	Postboks		False	3	
410	Kollafj�rdur			False	3	
415	Oyrareingir			False	3	
416	Signab�ur			False	3	
420	H�sv�k			False	3	
430	Hvalv�k			False	3	
435	Streymnes			False	3	
436	Saksun			False	3	
437	Nesv�k			False	3	
438	Langasandur			False	3	
440	Haldarsv�k			False	3	
445	Tj�rnuv�k			False	3	
450	Oyri			False	3	
460	Nordsk�li			False	3	
465	Svin�ir			False	3	
466	Lj�s�			False	3	
470	Eidi			False	3	
475	Funningur			False	3	
476	Gj�gv			False	3	
477	Funningsfj�rdur			False	3	
478	Elduv�k			False	3	
480	Sk�li			False	3	
485	Sk�lafj�rdur			False	3	
490	Strendur			False	3	
494	innan Glyvur			False	3	
495	Kolbanargj�gv			False	3	
496	Morskranes			False	3	
497	Selatrad			False	3	
510	G�ta			False	3	
511	G�tugj�gv			False	3	
512	Nordrag�ta			False	3	
513	Sydrug�ta			False	3	
515	G�ta	Postboks		False	3	
520	Leirv�k			False	3	
530	Fuglafj�rdur			False	3	
535	Fuglafj�rdur	Postboks		False	3	
600	Saltangar�			False	3	
610	Saltangar�	Postboks		False	3	
620	Runav�k			False	3	
625	Glyvrar			False	3	
626	Lambareidi			False	3	
627	Lambi			False	3	
640	Rituv�k			False	3	
645	�duv�k			False	3	
650	Toftir			False	3	
655	Nes, Eysturoy			False	3	
656	Saltnes			False	3	
660	S�ldarfj�rdur			False	3	
665	Skipanes			False	3	
666	G�tueidi			False	3	
690	Oyndarfj�rdur			False	3	
695	Hellur			False	3	
700	Klaksv�k			False	3	
710	Klaksv�k	Postboks		False	3	
725	Nordoyri			False	3	
726	�nir			False	3	
727	�rnafj�rdur			False	3	
730	Norddepil			False	3	
735	Depil			False	3	
736	Nordtoftir			False	3	
737	M�li			False	3	
740	Hvannasund			False	3	
750	Vidareidi			False	3	
765	Svinoy			False	3	
766	Kirkja			False	3	
767	Hattarv�k			False	3	
780	Kunoy			False	3	
785	Haraldssund			False	3	
795	Sydradalur, Kalsoy			False	3	
796	H�sar			False	3	
797	Mikladalur			False	3	
798	Tr�llanes			False	3	
800	Tv�royri			False	3	
810	Tv�royri	Postboks		False	3	
825	Frodba			False	3	
826	Trongisv�gur			False	3	
827	�rav�k			False	3	
850	Hvalba			False	3	
860	Sandv�k			False	3	
870	F�mjin			False	3	
900	V�gur			False	3	
910	V�gur	Postboks		False	3	
925	Nes, V�gur			False	3	
926	Lopra			False	3	
927	Akrar			False	3	
928	Vikarbyrgi			False	3	
950	Porkeri			False	3	
960	Hov			False	3	
970	Sumba			False	3	
