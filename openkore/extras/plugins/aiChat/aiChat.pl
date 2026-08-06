#############################################################################
# aiChat — AI-powered chat replies for OpenKore
#
# PM / nearby public chat → OpenAI-compatible reply ONLY.
# No local/keyword fallback — if the API is missing or fails, it stays silent.
#
# Config:
#   aiChat 1
#   aiChat_apiKey sk-...          # REQUIRED (or OPENAI_API_KEY / AI_CHAT_API_KEY)
#   aiChat_apiUrl https://api.openai.com/v1/chat/completions
#   aiChat_model gpt-4o-mini
#   aiChat_public 1
#   aiChat_publicNeedName 1
#   aiChat_nearDist 3
#   aiChat_delay 2
#   aiChat_cooldown 6
#   aiChat_maxLen 70
#   aiChat_history 6
#   aiChat_timeout 15
#   aiChat_temperature 0.9
#   aiChat_persona ...
#   aiChat_ignore Bot1,Bot2
#
# Console: aichat status | on | off | test <player> <msg>
#############################################################################
package aiChat;

use strict;
use warnings;
use Plugins;
use Globals qw(%config $char $field $messageSender $playersList %jobs_lut);
use Log qw(message warning error debug);
use Commands;
use Utils qw(timeOut blockDistance);
use Actor;
use JSON::Tiny qw(encode_json decode_json);
use Encode qw(encode decode);

Plugins::register('aiChat', 'AI chat replies (PM / public)', \&onUnload, \&onReload);

my $hooks = Plugins::addHooks(
	['start3',         \&onStart, undef],
	['packet_privMsg', \&onPrivMsg, undef],
	['packet_pubMsg',  \&onPubMsg, undef],
	['mainLoop_pre',   \&onMainLoop, undef],
);

my $cmd = Commands::register(
	['aichat', 'AI chat plugin control', \&cmdAiChat],
);

my @queue;
my %lastReply;
my %history;
my $busy = 0;
my $lastMode = 'none';  # api | local | none

sub onUnload {
	Plugins::delHooks($hooks) if $hooks;
	Commands::unregister($cmd) if $cmd;
	@queue = ();
	%lastReply = ();
	%history = ();
	message "[aiChat] unloaded\n", "system";
}

sub onReload { onUnload(); }

sub onStart {
	_ensureDefaults();
	my $key = apiKey();
	if ($key eq '') {
		warning "[aiChat] loaded — NO API KEY. Will not reply until aiChat_apiKey is set.\n";
	} else {
		message "[aiChat] loaded — API-only mode (" . substr($key, 0, 7) . "…)\n", "system";
	}
}

sub _ensureDefaults {
	$config{aiChat} //= 0;
	$config{aiChat_apiUrl} //= 'https://api.openai.com/v1/chat/completions';
	$config{aiChat_model} //= 'gpt-4o-mini';
	$config{aiChat_public} //= 1;
	$config{aiChat_publicNeedName} //= 1;
	$config{aiChat_nearDist} //= 3;
	$config{aiChat_delay} //= 2;
	$config{aiChat_cooldown} //= 6;
	$config{aiChat_maxLen} //= 70;
	$config{aiChat_history} //= 6;
	$config{aiChat_timeout} //= 15;
	$config{aiChat_temperature} //= 0.9;
	$config{aiChat_persona} //= _defaultPersona();
}

sub _defaultPersona {
	return join(' ', (
		'You are a real Ragnarok Online player chatting in-game.',
		'Write like a casual RO player: short, natural, slightly slangy.',
		'Answer the actual question using your character facts when relevant.',
		'Never say you are a bot, AI, macro, OpenKore, or script.',
		'No OOC, no markdown, no links, no emoji spam.',
		'One short line only. Match their language (English/Tagalog/etc).',
		'If they greet you, greet back warmly. If they ask something you do not know, guess casually or deflect.',
		'Do not offer to party/trade/buff unless they ask; if they ask, politely decline for now.',
	));
}

sub enabled {
	return ($config{aiChat} || 0) == 1;
}

sub apiKey {
	return $config{aiChat_apiKey}
		|| $ENV{OPENAI_API_KEY}
		|| $ENV{AI_CHAT_API_KEY}
		|| '';
}

sub _charJob {
	return 'Novice' unless $char;
	my $id = $char->{jobID};
	return $jobs_lut{$id} if defined $id && $jobs_lut{$id};
	return $char->{job} if $char->{job};
	return 'Novice';
}

sub _charFacts {
	my $name = ($char && $char->{name}) ? $char->{name} : 'Adventurer';
	my $job  = _charJob();
	my $blvl = ($char && defined $char->{lv}) ? $char->{lv} : '?';
	my $jlvl = ($char && defined $char->{lv_job}) ? $char->{lv_job} : '?';
	my $map  = ($field && $field->baseName) ? $field->baseName : 'unknown';
	my $x = ($char && $char->{pos_to}{x}) ? $char->{pos_to}{x} : '?';
	my $y = ($char && $char->{pos_to}{y}) ? $char->{pos_to}{y} : '?';
	my $zeny = ($char && defined $char->{zeny}) ? $char->{zeny} : undef;
	my $hp = '';
	if ($char && $char->{hp_max}) {
		$hp = int(100 * $char->{hp} / $char->{hp_max}) . '% HP';
	}
	my @bits = (
		"name=$name",
		"job=$job",
		"baseLv=$blvl",
		"jobLv=$jlvl",
		"map=$map",
		"pos=$x,$y",
	);
	push @bits, "zeny=$zeny" if defined $zeny;
	push @bits, $hp if $hp ne '';
	return join(', ', @bits);
}

sub cmdAiChat {
	my (undef, $args) = @_;
	_ensureDefaults();
	$args = '' unless defined $args;
	my ($sub, $rest) = $args =~ /^\s*(\S+)(?:\s+(.*))?$/;
	$sub = lc($sub // 'status');
	$rest //= '';

	if ($sub eq 'on') {
		$config{aiChat} = 1;
		message "[aiChat] enabled\n", "system";
	} elsif ($sub eq 'off') {
		$config{aiChat} = 0;
		message "[aiChat] disabled\n", "system";
	} elsif ($sub eq 'test') {
		my ($user, $msg) = $rest =~ /^(\S+)\s+(.+)$/;
		unless ($user && $msg) {
			message "Usage: aichat test <player> <message>\n", "list";
			return;
		}
		_enqueue({ type => 'pm', user => $user, msg => $msg, force => 1 });
		message "[aiChat] queued test reply to $user\n", "system";
	} else {
		my $key = apiKey();
		my $keyHint = $key ? (substr($key, 0, 7) . '…') : '(NONE — will not reply)';
		message "[aiChat] status\n"
			. "  enabled   : " . (enabled() ? 'yes' : 'no') . "\n"
			. "  mode      : API only (no local fallback)\n"
			. "  api key   : $keyHint\n"
			. "  model     : $config{aiChat_model}\n"
			. "  last mode : $lastMode\n"
			. "  char      : " . _charFacts() . "\n"
			. "  public    : $config{aiChat_public} (needName=$config{aiChat_publicNeedName}, nearDist=$config{aiChat_nearDist})\n"
			. "  delay     : $config{aiChat_delay}s\n"
			. "  cooldown  : $config{aiChat_cooldown}s\n"
			. "  queue     : " . scalar(@queue) . " pending\n",
			"list";
	}
}

sub onPrivMsg {
	my (undef, $args) = @_;
	return unless enabled();
	my $user = $args->{MsgUser} || $args->{privMsgUser} || '';
	my $msg  = $args->{Msg} || $args->{privMsg} || '';
	return unless $user && $msg ne '';
	return if _ignored($user);
	_enqueue({ type => 'pm', user => $user, msg => $msg });
}

sub onPubMsg {
	my (undef, $args) = @_;
	return unless enabled();
	return unless ($config{aiChat_public} || 0) == 1;
	my $user = $args->{MsgUser} || $args->{pubMsgUser} || '';
	my $msg  = $args->{Msg} || $args->{pubMsg} || '';
	return unless $user && $msg ne '';
	return if _ignored($user);

	my $near = _isNear($args->{pubID});
	my $named = 0;
	if (($config{aiChat_publicNeedName} || 0) == 1) {
		my $name = ($char && $char->{name}) ? $char->{name} : '';
		$named = ($name ne '' && $msg =~ /\Q$name\E/i) ? 1 : 0;
	} else {
		$named = 1;
	}
	return unless $named || $near;

	_enqueue({
		type => 'c',
		user => $user,
		msg  => $msg,
		near => $near ? 1 : 0,
	});
}

sub _isNear {
	my ($pubID) = @_;
	return 0 unless $char && $char->{pos_to};
	my $max = $config{aiChat_nearDist};
	$max = 3 unless defined $max && $max ne '';
	return 0 if $max <= 0;

	my $actor;
	if (defined $pubID) {
		$actor = Actor::get($pubID);
	}
	return 0 unless $actor && $actor->{pos_to};

	my $dist = blockDistance($char->{pos_to}, $actor->{pos_to});
	return ($dist <= $max) ? 1 : 0;
}

sub _ignored {
	my ($user) = @_;
	my $list = $config{aiChat_ignore} || '';
	if ($list ne '') {
		for my $n (split /\s*,\s*/, $list) {
			return 1 if lc($n) eq lc($user);
		}
	}
	return 1 if $char && $char->{name} && lc($char->{name}) eq lc($user);
	return 0;
}

sub _enqueue {
	my ($item) = @_;
	my $user = $item->{user};
	my $cd = $config{aiChat_cooldown} || 6;
	unless ($item->{force}) {
		if ($lastReply{$user} && !timeOut($lastReply{$user}, $cd)) {
			debug "[aiChat] cooldown skip for $user\n", "aiChat";
			return;
		}
	}
	for my $q (@queue) {
		return if $q->{user} eq $user;
	}

	my $delay = $config{aiChat_delay};
	$delay = 2 unless defined $delay && $delay ne '';
	if ($delay > 0) {
		my $jitter = $delay * (0.7 + rand(0.6));
		$item->{ready_at} = time + $jitter;
	} else {
		$item->{ready_at} = time;
	}
	push @queue, $item;
	debug "[aiChat] queued reply to $user (delay ~$delay s)\n", "aiChat";
}

sub onMainLoop {
	return unless enabled();
	return if $busy;
	return unless @queue;
	return unless $char && $field;

	my $idx;
	for my $i (0 .. $#queue) {
		my $ready = $queue[$i]{ready_at} || 0;
		if (time >= $ready) {
			$idx = $i;
			last;
		}
	}
	return unless defined $idx;

	my ($item) = splice @queue, $idx, 1;
	$busy = 1;
	eval {
		_handle($item);
		1;
	} or do {
		warning "[aiChat] error: $@\n";
	};
	$busy = 0;
}

sub _handle {
	my ($item) = @_;
	my $user = $item->{user};
	my $msg  = $item->{msg};
	my $type = $item->{type} || 'pm';

	_pushHistory($user, 'user', $msg);
	my $reply = _generateReply($user, $msg, $type);
	$reply = _sanitize($reply);
	unless (defined $reply && length $reply) {
		warning "[aiChat] empty reply for $user\n";
		return;
	}

	_pushHistory($user, 'assistant', $reply);
	$lastReply{$user} = { time => time };

	if ($type eq 'pm') {
		Commands::run("pm \"$user\" $reply");
		message "[aiChat] ($lastMode) PM -> $user : $reply\n", "system";
	} else {
		Commands::run("c $reply");
		message "[aiChat] ($lastMode) chat -> $user : $reply\n", "system";
	}
}

sub _pushHistory {
	my ($user, $role, $content) = @_;
	$history{$user} ||= [];
	push @{ $history{$user} }, { role => $role, content => $content };
	my $max = ($config{aiChat_history} || 6) * 2;
	while (@{ $history{$user} } > $max) {
		shift @{ $history{$user} };
	}
}

sub _sanitize {
	my ($t) = @_;
	return '' unless defined $t;
	$t =~ s/[\r\n\t]+/ /g;
	$t =~ s/^\s+|\s+$//g;
	$t =~ s/^["']|["']$//g;
	$t =~ s/[*_`#]+//g;
	# strip common AI refusals / bot tells
	$t =~ s/\b(as an ai|i'?m an? (ai|bot|language model)|openkore)\b//gi;
	$t =~ s/\s{2,}/ /g;
	$t =~ s/^\s+|\s+$//g;
	my $max = $config{aiChat_maxLen} || 70;
	if (length($t) > $max) {
		$t = substr($t, 0, $max - 1);
		$t =~ s/\s+\S*$//;
	}
	return $t;
}

sub _generateReply {
	my ($user, $msg, $type) = @_;
	my $key = apiKey();
	if ($key eq '') {
		warning "[aiChat] no API key — skipping reply to $user\n";
		$lastMode = 'none';
		return '';
	}
	my $ai = eval { _callOpenAI($user, $msg, $key, $type) };
	if ($@) {
		warning "[aiChat] API failed: $@ — skipping reply (API-only mode)\n";
		$lastMode = 'none';
		return '';
	}
	if (!defined $ai || $ai eq '') {
		warning "[aiChat] API returned empty — skipping reply\n";
		$lastMode = 'none';
		return '';
	}
	$lastMode = 'api';
	return $ai;
}

sub _systemPrompt {
	my ($user, $type) = @_;
	my $persona = $config{aiChat_persona} || _defaultPersona();
	my $facts = _charFacts();
	my $chan = ($type && $type eq 'pm') ? 'private message' : 'public chat';
	my $max = $config{aiChat_maxLen} || 70;
	return join("\n", (
		$persona,
		"Your live character facts: $facts.",
		"You are talking with player \"$user\" via $chan.",
		"Use those facts when they ask about your job, level, map, or what you are doing.",
		"Hard limit: one chat line, under $max characters. No quotes around the reply.",
	));
}

sub _callOpenAI {
	my ($user, $msg, $key, $type) = @_;
	my $url   = $config{aiChat_apiUrl} || 'https://api.openai.com/v1/chat/completions';
	my $model = $config{aiChat_model} || 'gpt-4o-mini';
	my $timeout = $config{aiChat_timeout} || 15;
	my $temp = $config{aiChat_temperature};
	$temp = 0.9 unless defined $temp && $temp ne '';

	my @messages = (
		{ role => 'system', content => _systemPrompt($user, $type) },
	);

	# Replay history; label the latest user turn clearly
	if ($history{$user} && @{ $history{$user} }) {
		my @h = @{ $history{$user} };
		for my $i (0 .. $#h) {
			my $turn = $h[$i];
			my $content = $turn->{content};
			if ($turn->{role} eq 'user' && $i == $#h) {
				$content = "$user says: $content";
			}
			push @messages, { role => $turn->{role}, content => $content };
		}
	} else {
		push @messages, { role => 'user', content => "$user says: $msg" };
	}

	my $payload = encode_json({
		model => $model,
		temperature => 0 + $temp,
		max_tokens => 100,
		messages => \@messages,
	});

	my $tmpdir = $ENV{TEMP} || $ENV{TMP} || $ENV{TMPDIR} || '/tmp';
	$tmpdir =~ s/[\\\/]+$//;
	my $tmpIn  = "$tmpdir/aichat-req-$$.json";
	my $tmpOut = "$tmpdir/aichat-res-$$.json";
	open my $fh, '>:raw', $tmpIn or die "cannot write $tmpIn: $!";
	print {$fh} $payload;
	close $fh;

	my $curl = _findCurl() or die "curl not found in PATH";
	my @cmd = (
		$curl, '-sS', '-X', 'POST', $url,
		'-H', "Authorization: Bearer $key",
		'-H', 'Content-Type: application/json',
		'--max-time', $timeout,
		'--data-binary', "\@$tmpIn",
		'-o', $tmpOut,
	);
	my $rc = system(@cmd);
	unlink $tmpIn;
	die "curl failed rc=$rc" if $rc != 0 || !-f $tmpOut;

	open my $rf, '<:raw', $tmpOut or die "cannot read $tmpOut: $!";
	local $/;
	my $raw = <$rf>;
	close $rf;
	unlink $tmpOut;

	my $data = decode_json($raw);
	if ($data->{error}) {
		my $em = $data->{error}{message} || 'unknown';
		die "API error: $em";
	}
	my $content = $data->{choices}[0]{message}{content} // '';
	$content = decode('UTF-8', $content) if !utf8::is_utf8($content) && defined $content;
	$content =~ s/^\s+|\s+$//g;
	die "empty content" if $content eq '';
	return $content;
}

# Smarter offline engine — answers with real char facts, not just "oh?"
sub _localFallback {
	my ($user, $msg) = @_;
	my $m = lc($msg);
	$m =~ s/[^\w\s\?\!\']+/ /g;
	$m =~ s/\s+/ /g;
	$m =~ s/^\s+|\s+$//g;

	my $name = ($char && $char->{name}) ? $char->{name} : 'me';
	my $job  = _charJob();
	my $blvl = ($char && defined $char->{lv}) ? $char->{lv} : '?';
	my $jlvl = ($char && defined $char->{lv_job}) ? $char->{lv_job} : '?';
	my $map  = ($field && $field->baseName) ? $field->baseName : 'here';
	my $short = sub { $_[0]->[ int(rand(@{$_[0]})) ] };

	# Accusations
	if ($m =~ /\b(bot|botter|macro|openkore|auto\s*bot|script)\b/) {
		return $short->(["haha nah just grinding", "lol no just playing", "bro i'm just farming"]);
	}

	# Greetings
	if ($m =~ /^(hi|hello|hey|yo|sup|good ?day|good ?morning|good ?evening|hola|oi)\b/
		|| $m =~ /\b(hi|hello|hey|yo|sup)\s+$name\b/i
		|| $m =~ /\b(hi|hello|hey)\b/) {
		return $short->(["hey $user", "yo $user", "hey what's up", "hi!", "yo"]);
	}

	# How are you
	if ($m =~ /\b(how are you|how's it going|how r u|hru|kamusta)\b/) {
		return $short->(["pretty good, farming a bit", "all good you?", "chillin on $map", "tired but grinding"]);
	}

	# Level / job questions
	if ($m =~ /\b(what('?s| is) your (base )?level|what lvl|what level|base lvl|base level)\b/
		|| $m =~ /\b(lvl|level)\s*\??\s*$/
		|| $m =~ /\byou(r)?\s*(lvl|level)\b/) {
		return $short->(["base $blvl", "i'm $blvl", "base $blvl job $jlvl"]);
	}
	if ($m =~ /\b(what('?s| is) your job|what class|what job|are you (a |an )?\w+)\b/) {
		return $short->(["$job", "i'm a $job", "$job base $blvl"]);
	}
	if ($m =~ /\b(who are you|what('?s| is) your name)\b/) {
		return $short->(["i'm $name", "$name, $job"]);
	}

	# Where / map
	if ($m =~ /\b(where (are )?you|what map|which map|where u at|saan)\b/
		|| $m =~ /\b(where|map|spot)\b/) {
		return $short->(["on $map", "just around $map", "here on $map grinding"]);
	}

	# What doing
	if ($m =~ /\b(what('?s| are) you doing|wyd|ano ginagawa|farming\?)\b/) {
		return $short->(["just grinding on $map", "farming a bit", "lvling my $job"]);
	}

	# Party
	if ($m =~ /\b(party|pt|party pls|need pt)\b/) {
		return $short->(["solo for now thanks", "maybe later finishing this run", "appreciate it but solo rn"]);
	}

	# Buffs / heal
	if ($m =~ /\b(buff|bless|agi|heal|warp|warp portal)\b/) {
		return $short->(["no buffs on me sorry", "can't help with that rn", "wish i could"]);
	}

	# Trade / zeny
	if ($m =~ /\b(zeny|money|cheap|sell|buy|trade|vending|vender)\b/) {
		return $short->(["not trading rn", "saving up actually", "broke as usual lol"]);
	}

	# Help
	if ($m =~ /\b(help|can you help|pahelp|tulong)\b/) {
		return $short->(["what's up?", "depends, what do you need?", "kinda busy grinding but what's wrong?"]);
	}

	# Thanks
	if ($m =~ /\b(thanks|thank you|ty|thx|salamat)\b/) {
		return $short->(["np", "anytime", "sure"]);
	}

	# Laugh
	if ($m =~ /\b(lol|haha|lmao|xd|huhu|jeje)\b/ && length($m) < 20) {
		return $short->(["lol", "haha", "xD"]);
	}

	# Questions we don't know — ask back instead of "oh?"
	if ($m =~ /\?$/ || $m =~ /\b(what|why|how|when|who|which|can you|do you)\b/) {
		return $short->([
			"not sure tbh, why?",
			"hmm good question",
			"maybe? what do you mean",
			"idk yet still figuring it out",
			"could be, you tried already?",
		]);
	}

	# Default: acknowledge + light context (not empty "oh?")
	return $short->([
		"haha yeah",
		"true",
		"nice",
		"busy on $map a bit, what's up?",
		"lol yeah",
		"fair enough",
		"oh for real?",
		"gotcha",
	]);
}

sub _findCurl {
	for my $c (qw(curl curl.exe)) {
		my $out = `$c --version 2>&1`;
		return $c if defined $out && $out =~ /curl/i;
	}
	return;
}

1;
