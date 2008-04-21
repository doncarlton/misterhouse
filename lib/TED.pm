=begin comment
# $Date: 2008-03-14 22:43:50 -0400 (Fri, 14 Mar 2008) $
# $Revision: 1394 $

From David Satterfield <david_misterhouse@yahoo.com>

# Serial port that the RZC0P is connected to. Put this in your mh.private.ini.
TED_serial_port = /dev/ttyUSB0

Then, add this to your user code (I put it in ted.pl)
use TED;
$ted_interface = new TED;

That's it! Your %Electric hash should start getting filled in.

Known Issues:
It seems that TED packets can vary in size. This module only handles 280 byte packets at this point.

=cut

use strict;
use warnings;

package TED;

@TED::ISA=('Serial_Item');

my $portname = 'TED';

sub new {

    my ($class, $port_name)=@_;
    $port_name = 'TED' if !$port_name;
    $main::config_parms{"TED_break"} = "\cP\cC";

    my $self = {};
    $self->{port_name} = $port_name;

    bless $self, $class;

    &::MainLoop_pre_add_hook(\&TED::check_for_data,   1, $self);
    $self->{update_time} = time;
    $self->{good_packet_time} = time;

    return $self;
}

sub serial_startup {
    my $port  = $main::config_parms{TED_serial_port};
    &::serial_port_create($portname, $port, '19200', 'none', 'record');
}

sub check_for_data {
    my ($self) = @_;

    # check for data
    &main::check_for_generic_serial_data($portname);

    my $time = time;

    if ($main::Serial_Ports{$portname}{data_record}) {
	# go get and process the data
	&process_incoming_data($self);
	$self->{update_time} = $time;
    }
    
    if ($time > ($self->{update_time}+10)) {
	&::print_log("TED: Haven't heard from ted in 10 seconds, is something wrong?");
	return;
#	my $port = $::Serial_Ports{$portname}{port};
#	my $serial_port = $::Serial_Ports{object_by_port}{$port};
#	$serial_port->close();
#	&::serial_port_create($portname, $port, '19200', 'none', 'record');
    }

    if (($time > ($self->{good_packet_time}+30)) and 
	($time > ($self->{squawk_time}+10))) {
	$self->{squawk_time} = $time;
	&::print_log("TED: Haven't gotten a good packet from ted in 30 seconds, is something wrong? time: $time gpt:$self->{good_packet_time} st:$self->{squawk_time}") unless $::Startup;
    }
}

sub process_incoming_data {
    my ($self)=@_;

    my $input=$main::Serial_Ports{$portname}{data_record};

    my $hex = unpack "H*", $input;

    my @pkt=unpack("C*", $input);
    for (my $i=0; $i < $#pkt-1; $i++)
    {
	splice(@pkt, $i, 1) if ($pkt[$i] == 0x10 && $pkt[$i+1] == 0x10);
    }	

    my $tedchars = $#pkt+3;
    printf("%02d:%02d:%02d TED chars: $tedchars\n",
		$main::Hour, $main::Minute, $main::Second) if $main::Debug{ted};

    my $output;
    foreach my $i (@pkt) {
	my $char=sprintf "%02x ", $i;
	$output.=$char;
    }

    my $tedstr = pack "CCCC", $pkt[113], $pkt[114], $pkt[115], $pkt[116];
    my $start  = pack "CC", $pkt[0], $pkt[1];    

    my @values = split (/ /, $output);

    for my $i (0..13) {
	my $line_index = $i*20;
	my $prline = '';
	for my $j (0..19) {
	    my $char_index = $line_index + $j;
	    if ($char_index <= $#values) {
		my $char = $values[$char_index];
		$prline .= $char . " ";
	    }
	}
	printf "%3d:$prline\n", $line_index if $main::Debug{ted};
    }
    my $v;
    if (($start eq "\cP\cD") and ($tedstr eq "TED ") and $#values == 277) {
        $main::Electric{Flags}       = (($pkt[3] * 256) + $pkt[2]);
        $main::Electric{FixMthChrg_1}= (($pkt[5] * 256) + $pkt[4])/100;
        $main::Electric{FixMthChrg_2}= (($pkt[7] * 256) + $pkt[6])/100;
        $main::Electric{MinMthChrg_1}= (($pkt[9] * 256) + $pkt[8])/100;
        $main::Electric{MinMthChrg_2}= (($pkt[11] * 256) + $pkt[10])/100;
        $main::Electric{FuelSurChrg_1}=(($pkt[13] * 256) + $pkt[12])/10000;
        $main::Electric{FuelSurChrg_2}=(($pkt[15] * 256) + $pkt[14])/10000;
        $main::Electric{SummerStart}  = (($pkt[17] * 256) + $pkt[16]);
        $main::Electric{SummerStart} = sprintf "%d/%d", 
				int $main::Electric{SummerStart}/32 + 1,	
				    $main::Electric{SummerStart}%32 + 1;	
        $main::Electric{SummerEnd}   = (($pkt[19] * 256) + $pkt[18]);
        $main::Electric{SummerEnd}   = sprintf "%d/%d", 
				int $main::Electric{SummerEnd}/32 + 1,	
				    $main::Electric{SummerEnd}%32 + 1;	
        $main::Electric{KwThresh1_0} = (($pkt[21] * 256) + $pkt[20]);
        $main::Electric{KwThresh1_1} = (($pkt[23] * 256) + $pkt[22]);
        $main::Electric{KwThresh1_2} = (($pkt[25] * 256) + $pkt[24]);
        $main::Electric{KwThresh1_3} = (($pkt[27] * 256) + $pkt[26]);
        $main::Electric{KwThresh1_4} = (($pkt[29] * 256) + $pkt[28]);
        $main::Electric{KwThresh1_5} = (($pkt[31] * 256) + $pkt[30]);
        $main::Electric{KwThresh2_0} = (($pkt[33] * 256) + $pkt[32]);
        $main::Electric{KwThresh2_1} = (($pkt[35] * 256) + $pkt[34]);
        $main::Electric{KwThresh2_2} = (($pkt[37] * 256) + $pkt[36]);
        $main::Electric{KwThresh2_3} = (($pkt[39] * 256) + $pkt[38]);
        $main::Electric{KwThresh2_4} = (($pkt[41] * 256) + $pkt[40]);
        $main::Electric{KwThresh2_5} = (($pkt[43] * 256) + $pkt[42]);
        $main::Electric{KwThresh3_0} = (($pkt[45] * 256) + $pkt[44]);
        $main::Electric{KwThresh3_1} = (($pkt[47] * 256) + $pkt[46]);
        $main::Electric{KwThresh3_2} = (($pkt[49] * 256) + $pkt[48]);
        $main::Electric{KwThresh3_3} = (($pkt[51] * 256) + $pkt[50]);
        $main::Electric{KwThresh3_4} = (($pkt[53] * 256) + $pkt[52]);
        $main::Electric{KwThresh3_5} = (($pkt[55] * 256) + $pkt[54]);
        $main::Electric{KwThresh4_0} = (($pkt[57] * 256) + $pkt[56]);
        $main::Electric{KwThresh4_1} = (($pkt[59] * 256) + $pkt[58]);
        $main::Electric{KwThresh4_2} = (($pkt[61] * 256) + $pkt[60]);
        $main::Electric{KwThresh4_3} = (($pkt[63] * 256) + $pkt[62]);
        $main::Electric{KwThresh4_4} = (($pkt[65] * 256) + $pkt[64]);
        $main::Electric{KwThresh4_5} = (($pkt[67] * 256) + $pkt[66]);
        $main::Electric{KwRate1_1}   = (($pkt[85] * 256) + $pkt[84])/10000;
        $main::Electric{KwRate1_2}   = (($pkt[87] * 256) + $pkt[86])/10000;
        $main::Electric{KwRate1_3}   = (($pkt[89] * 256) + $pkt[88])/10000;
        $main::Electric{KwRate1_4}   = (($pkt[91] * 256) + $pkt[90])/10000;
        $main::Electric{KwRate1_5}   = (($pkt[93] * 256) + $pkt[92])/10000;
        $main::Electric{KwRate2_1}   = (($pkt[95] * 256) + $pkt[94])/10000;
        $main::Electric{KwRate2_2}   = (($pkt[97] * 256) + $pkt[96])/10000;
        $main::Electric{KwRate2_3}   = (($pkt[99] * 256) + $pkt[98])/10000;
        $main::Electric{KwRate2_4}   = (($pkt[101] * 256) + $pkt[100])/10000;
        $main::Electric{KwRate2_5}   = (($pkt[103] * 256) + $pkt[102])/10000;
        $main::Electric{SalesTax}    = (($pkt[105] * 256) + $pkt[104])/10000;
        $main::Electric{MeterRead}   =   $pkt[106] + 1;
	$main::Electric{Calibrate}   = (($pkt[108] * 256) + $pkt[107])/1000;
	$main::Electric{NumHouseCode}=   $pkt[109]+1;
	$main::Electric{HouseCode}   =   $pkt[110]; # good
	$main::Electric{HouseCode2}  =   $pkt[111];

        $main::Electric{DlrPkKwHAlarm} = (($pkt[123] * 256) + $pkt[122])/100;
        $main::Electric{PkKwAlarm}    = (($pkt[125] * 256) + $pkt[124])/100;
        $main::Electric{DlrMthAlarm} = (($pkt[127] * 256) + $pkt[126])/10; 
        $main::Electric{KwMtdAlarm}  = (($pkt[129] * 256) + $pkt[128]); 
        $main::Electric{LoValarm}    = (($pkt[131] * 256) + $pkt[130])/10; 
        $main::Electric{HiValarm}    = (($pkt[133] * 256) + $pkt[132])/10; 
        $main::Electric{LoVrmsTdy}   = (($pkt[135] * 256) + $pkt[134])/10; 
        $main::Electric{stLoVtimTdy} = &get_time((($pkt[137] * 256) + $pkt[136])); 
	$main::Electric{HiVrmsTdy}   = (($pkt[139] * 256) + $pkt[138])/10; 
	$main::Electric{stHiVtimTdy} = &get_time((($pkt[141] * 256) + $pkt[140])); 
	$main::Electric{LoVrmsMtd}   = (($pkt[143] * 256) + $pkt[142])/10; 
	$main::Electric{LoVrmsMtdFlg}=  ($pkt[144]); 
	$main::Electric{HiVrmsMtd}   = (($pkt[146] * 256) + $pkt[145])/10; 
	$main::Electric{HiVrmsMtdFlg}=  ($pkt[147]); 
	$main::Electric{KwPeakTdy}   = (($pkt[149] * 256) + $pkt[148])/100; 
	$main::Electric{DlrPeakTdy}  = (($pkt[151] * 256) + $pkt[150])/100;
	$main::Electric{KwPeakMtd}   = (($pkt[153] * 256) + $pkt[152])/100; 
	$main::Electric{DlrPeakMtd}  = (($pkt[155] * 256) + $pkt[154])/100;
	$main::Electric{DlrTdy}      = (($pkt[159] * 256 * 256 * 256) + 
			                ($pkt[158] * 256 * 256) +
			                ($pkt[157] * 256) + 
			                ($pkt[156]))/600000;
	$main::Electric{KwTdy}       = (($pkt[163] * 256 * 256 * 256) + 
			                ($pkt[162] * 256 * 256) +
					($pkt[161] * 256) + 
					($pkt[160])) / 60000;
	$main::Electric{KwhMtdCnt}   = (($pkt[167] * 256 * 256 * 256) + 
			                ($pkt[166] * 256 * 256) +
					($pkt[165] * 256) + 
					($pkt[164]))/100;
	$main::Electric{KwhMtdSum}   = (($pkt[171] * 256 * 256 * 256) + 
			                ($pkt[170] * 256 * 256) +
					($pkt[169] * 256) + 
					($pkt[168])) / 60000;
	$main::Electric{DlrMtdSum}   = (($pkt[175] * 256 * 256 * 256) + 
			                ($pkt[174] * 256 * 256) +
					($pkt[173] * 256) + 
					($pkt[172])) / 600000;
	$main::Electric{KWNow}       = (($pkt[250] * 256) + $pkt[249])/100;
        $main::Electric{DlrNow}      = (($pkt[252] * 256) + $pkt[251])/100;
	$main::Electric{VrmsNowDsp}  = (($pkt[254] * 256) + $pkt[253])/10;
	$main::Electric{DlrMtd}      = (($pkt[256] * 256) + $pkt[255])/10;
	$main::Electric{DlrProj}     = (($pkt[258] * 256) + $pkt[257])/10;
        $main::Electric{KWProj}      = (($pkt[260] * 256) + $pkt[259]);
        $main::Electric{AlarmStatus} =   $pkt[261];
	$main::Electric{VRmsNow_1}   = (($pkt[273] * 256 * 256 * 256) + 
			                ($pkt[272] * 256 * 256) +
					($pkt[271] * 256) + 
					($pkt[270]));
	$main::Electric{VRmsNow_2}   = (($pkt[277] * 256 * 256 * 256) + 
			                ($pkt[276] * 256 * 256) +
					($pkt[275] * 256) + 
					($pkt[274]));

	if ($main::Debug{ted}) {
	    print "HouseCode:      $main::Electric{HouseCode}\n";
	    print "HouseCode2:     $main::Electric{HouseCode2}\n" if $main::Electric{NumHouseCode} > 1;
	    printf "AlarmStatus:    0x%02X\n", $main::Electric{AlarmStatus};
	    printf "Flags:          0x%04X\n", $main::Electric{Flags};
	    printf "Calibration:    %.3f\n", $main::Electric{Calibrate};
	    print "Meter Read Day: $main::Electric{MeterRead}\n";
	    print "VrmsNowDsp:     $main::Electric{VrmsNowDsp}\n";
	    print "LoVrmsTdy:      $main::Electric{LoVrmsTdy} at $main::Electric{stLoVtimTdy}\n";
	    print "HiVrmsTdy:      $main::Electric{HiVrmsTdy} at $main::Electric{stHiVtimTdy}\n";
	    print "LoVrmsMtd:      $main::Electric{LoVrmsMtd}\n";
	    print "HiVrmsMtd:      $main::Electric{HiVrmsMtd}\n";

	    printf "DlrNow:         %.2f\n", $main::Electric{DlrNow};
	    printf "DlrPeakTdy:     %.2f\n", $main::Electric{DlrPeakTdy};
	    print "DlrPeakMtd:     $main::Electric{DlrPeakMtd}\n";
	    printf "DlrTdy:         %.2f\n", $main::Electric{DlrTdy};
	    printf "DlrMtd:         %.2f\n", $main::Electric{DlrMtd};
	    printf "DlrMtdSum:      %.2f\n", $main::Electric{DlrMtdSum};
	    printf "DlrProj:        %.2f\n", $main::Electric{DlrProj};

	    print "KWNow:          $main::Electric{KWNow}\n";
	    print "KwPeakTdy:      $main::Electric{KwPeakTdy}\n";
	    print "KwPeakMtd:      $main::Electric{KwPeakMtd}\n";
	    printf "KwTdy:          %.1f\n", $main::Electric{KwTdy};
	    printf "KwhMtdSum:      %.1f\n", $main::Electric{KwhMtdSum};
	    print "KWProj:         $main::Electric{KWProj}\n";
	    print "KwhMtdCnt:      $main::Electric{KwhMtdCnt}\n";

	    print "LoValarm:       $main::Electric{LoValarm}\n";
	    print "HiValarm:       $main::Electric{HiValarm}\n";
	    print "PkKwAlarm:      $main::Electric{PkKwAlarm}\n";
	    print "KwMtdwAlarm:    $main::Electric{KwMtdAlarm}\n";
	    print "DlrPkKwHAlarm:  $main::Electric{DlrPkKwHAlarm}\n";
	    print "DlrMthAlarm:    $main::Electric{DlrMthAlarm}\n";
	}
	$self->{good_packet_time} = time;

    }
    else { 
#	print "housecode:$pkt[110]\n"; # add some more recovery here...
	print "bad ted pkt $#values \"$tedstr\"\n" if $::Debug{ted}; 
    }
    $main::Serial_Ports{$portname}{data_record} = undef;
}

sub get_time {
    my ($minutes) = @_;
    my $hours = int ($minutes / 60);
    my $mins = $minutes % 60;
    my $suffix = 'am';
    if ($hours > 12) {
	$hours = $hours - 12;
	$suffix = 'pm';
    }
    $hours = 12 if $hours == 0;

    $mins=sprintf "%02d ", $mins;    
	
    my $time = "${hours}:${mins}$suffix";
    return $time;
}


# do not remove the following line, packages must return a true value
1;
# =========== Revision History ==============
# Revision 1.0  -- 4/08/2008 -- David Satterfield
# - First Release
#
# Revision 1.1  -- 4/21/2008 -- Joe Blecher
# - Fixed issue with decoding variable packet length. Decoded more fields
#
