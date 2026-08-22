# phase1Weapon — equip RagnaOne changejob free weapons / armor.
# Console: phase1equip   |   phase1weaponcheck (sets Phase1NeedWeaponBuy)
package phase1Weapon;

use strict;
use Plugins;
use Globals qw($char $messageSender %config %jobs_lut);
use Log qw(message warning);
use Commands;
use Misc;

Plugins::register('phase1Weapon', 'Equip Phase1 job-change reward weapons', \&onUnload, \&onReload);

my $hooks = Plugins::addHooks(
	['start3', \&onStart, undef],
);
my $cmd = Commands::register(
	['phase1equip', 'Equip job-change reward weapons/armor', \&cmdEquip],
	['phase1weaponcheck', 'Check if class weapon missing (sets Phase1NeedWeaponBuy)', \&cmdCheck],
	['phase1weaponcanbuy', 'Check buy cooldown (sets Phase1WeaponBuyNow)', \&cmdCanBuy],
	['phase1weaponbuysetup', 'Configure buyAuto_1 for missing class weapon', \&cmdBuySetup],
);

sub onUnload {
	Plugins::delHooks($hooks);
	Commands::unregister($cmd);
}
sub onReload { onUnload(); }
sub onStart { message "[phase1Weapon] loaded — use phase1equip / phase1weaponcheck\n", "success"; }

sub job_name {
	return '' unless $char && defined $char->{jobID};
	return $jobs_lut{$char->{jobID}} || '';
}

sub want_ids {
	my ($job) = @_;
	return (1107, 1109, 1101, 1104) if $job =~ /Sword/;
	return (1704, 1705, 1706, 1701, 1742) if $job eq 'Archer';
	return (1519, 1520, 1504, 1501, 1601) if $job eq 'Acolyte';
	return (1601, 1607, 1602, 1604) if $job =~ /Mage|Magician/;
	return (1301, 1302) if $job eq 'Merchant';
	return (1204, 1207) if $job eq 'Thief';
	return (1107, 1109, 1704, 1705, 1706, 1601, 1301, 1204, 1519, 1504, 1101);
}

sub attack_hand_id {
	my ($job) = @_;
	return 1109 if $job =~ /Sword/;
	return 1704 if $job eq 'Archer';
	return 1519 if $job eq 'Acolyte';
	return 1601 if $job =~ /Mage|Magician/;
	return 1301 if $job eq 'Merchant';
	return 1204 if $job eq 'Thief';
	return 0;
}

sub identify_rewards {
	return unless $char && $char->inventory->isReady && $messageSender;
	for my $it (@{$char->inventory}) {
		next unless $it && !$it->{identified} && $it->{nameID};
		my $id = $it->{nameID};
		next unless (
			($id >= 1101 && $id <= 1199) ||
			($id >= 1201 && $id <= 1299) ||
			($id >= 1301 && $id <= 1399) ||
			($id >= 1501 && $id <= 1599) ||
			($id >= 1601 && $id <= 1699) ||
			($id >= 1701 && $id <= 1799) ||
			($id >= 2301 && $id <= 2399)
		);
		$messageSender->sendItemIdentify($it->{ID});
	}
}

sub equip_by_ids {
	my (@ids) = @_;
	return 0 unless $char && $char->inventory->isReady;
	my $equipped = 0;
	for my $id (@ids) {
		my $i = $char->inventory->getByNameID($id);
		next unless $i;
		if (!$i->{identified} && $messageSender) {
			$messageSender->sendItemIdentify($i->{ID});
		}
		next if $i->{equipped};
		$i->equip;
		$equipped = 1;
		last;
	}
	return $equipped;
}

sub equip_armor_if_empty {
	my (@ids) = @_;
	return 0 unless $char && $char->inventory->isReady;
	for my $id (@ids) {
		my $i = $char->inventory->getByNameID($id);
		next unless $i && !$i->{equipped};
		# Skip if any equipment already occupies this item's equip slots
		my $slots = $i->{type_equip} || 0;
		my $blocked = 0;
		if ($char->{equipment}) {
			for my $slot (keys %{$char->{equipment}}) {
				my $eq = $char->{equipment}{$slot} or next;
				my $eqSlots = $eq->{type_equip} || 0;
				if ($slots && $eqSlots && ($slots & $eqSlots)) {
					$blocked = 1;
					last;
				}
			}
		}
		next if $blocked;
		if (!$i->{identified} && $messageSender) {
			$messageSender->sendItemIdentify($i->{ID});
		}
		$i->equip;
		return 1;
	}
	return 0;
}

sub cmdEquip {
	return warning "[phase1Weapon] not in game\n" unless $char && $char->inventory->isReady;
	my $job = job_name();
	identify_rewards();
	# Armor only if that slot is empty (never swap Jacket↔Cotton Shirt)
	equip_armor_if_empty(2303, 2304, 2301); # body
	equip_armor_if_empty(2401, 2403);       # shoes
	equip_armor_if_empty(2501, 2503);       # cape
	equip_armor_if_empty(2101, 2103, 2105); # shield
	my @want = want_ids($job);
	my $ok = equip_by_ids(@want);
	if ($job eq 'Archer') {
		my $ar = $char->inventory->getByNameID(1750);
		$ar->equip if $ar && !$ar->{equipped};
	}
	my $hand = attack_hand_id($job);
	configModify('attackEquip_rightHand', $hand) if $hand;
	configModify('Phase1WeaponDone', 1);
	my $rh = $char->{equipment}{rightHand};
	my $rhName = $rh ? $rh->{name} : 'none';
	message "[phase1Weapon] job=$job rightHand=$rhName equipped_new=$ok\n", "success";
}

sub cmdCheck {
	return warning "[phase1Weapon] not in game\n" unless $char && $char->inventory->isReady;
	my $job = job_name();
	my @want = want_ids($job);
	if ($job eq '' || $job eq 'Novice') {
		configModify('Phase1NeedWeaponBuy', 0);
		return;
	}
	my $rh = $char->{equipment}{rightHand};
	my $rhID = $rh ? $rh->{nameID} : 0;
	my $have = 0;
	for my $id (@want) {
		$have = 1 if $rhID && $rhID == $id;
		$have = 1 if $char->inventory->getByNameID($id);
	}
	my $need = (!$have && (!$rhID || $rhID == 1201)) ? 1 : 0;
	configModify('Phase1NeedWeaponBuy', $need);
	message "[phase1Weapon] job=$job needBuy=$need rh=" . ($rh ? $rh->{name} : 'none') . "\n", "success";
}

sub cmdCanBuy {
	my $at = $config{Phase1WeaponBuyAt} || 0;
	my $ok = (time >= $at) ? 1 : 0;
	configModify('Phase1WeaponBuyNow', $ok);
	message "[phase1Weapon] canBuy=$ok (nextAt=$at)\n", "success";
}

# Shop stock (RagnaOne) — use nameIDs (buyAuto supports numeric IDs):
#   prt_in 172,130 → 1701 Bow[3], 1107 Blade[3], ...
#   prt_church 108,124 → 1501 Club, 1504 Mace, 1519 Chain[2]
sub cmdBuySetup {
	my $job = job_name();
	my ($item, $npc, $stand, $mapHint);
	if ($job =~ /Sword/) {
		($item, $npc, $stand) = (1107, 'prt_in 172 130', 'prt_in 172 128');
		$mapHint = 'prt_in';
	} elsif ($job eq 'Archer') {
		# Free reward was Composite Bow [3] (1704); shop replacement is Bow [3] (1701)
		($item, $npc, $stand) = (1701, 'prt_in 172 130', 'prt_in 172 128');
		$mapHint = 'prt_in';
	} elsif ($job eq 'Acolyte') {
		($item, $npc, $stand) = (1501, 'prt_church 108 124', 'prt_church 108 122');
		$mapHint = 'prt_church';
	} else {
		configModify('Phase1NeedWeaponBuy', 0);
		configModify('buyAuto_1_disabled', 1);
		message "[phase1Weapon] buysetup: no shop buy for job=$job\n", "success";
		return;
	}
	configModify('buyAuto_1', $item);
	configModify('buyAuto_1_npc', $npc);
	configModify('buyAuto_1_standpoint', $stand);
	configModify('buyAuto_1_distance', 3);
	configModify('buyAuto_1_minAmount', 0);
	configModify('buyAuto_1_maxAmount', 1);
	configModify('buyAuto_1_disabled', 0);
	configModify('Phase1WeaponBuyMap', $mapHint);
	message "[phase1Weapon] buysetup job=$job itemID=$item npc=$npc\n", "success";
}

1;
