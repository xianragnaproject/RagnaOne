#############################################################################
# aiChat — AI-powered chat replies for OpenKore
#
# When someone PMs (or mentions you in public chat), the plugin asks an
# OpenAI-compatible API to craft a short in-character reply, then sends it.
# If no API key is set, a small local fallback reply engine is used.
#
# Config (control/config.txt or profile config.txt):
#   aiChat 1
#   aiChat_apiKey sk-...          # or env OPENAI_API_KEY / AI_CHAT_API_KEY
#   aiChat_apiUrl https://api.openai.com/v1/chat/completions
#   aiChat_model gpt-4o-mini
#   aiChat_public 1               # 1 = also watch public chat
#   aiChat_publicNeedName 1       # public: only if your name is mentioned
#   aiChat_cooldown 6             # seconds between replies per player
#   aiChat_maxLen 70              # hard cap on outgoing RO message length
#   aiChat_history 4              # turns of memory per player
#   aiChat_timeout 12             # curl timeout seconds
#   aiChat_persona You are a friendly Ragnarok Online player. Keep replies short.
#   aiChat_ignore BotName1,BotName2
#
# Console:
#   aichat status | aichat on | aichat off | aichat test <player> <msg>
#############################################################################
package aiChat;

use strict;
use warnings;
use Plugins;
use Globals qw(%config $char $field $messageSender);
use Log qw(message warning error debug);
use Commands;
use Utils qw(timeOut);
# OpenKore ships JSON::Tiny in src/deps (Windows-friendly; JSON::PP may be missing)
use JSON::Tiny qw(encode_json decode_json);
use Encode qw(encode decode find_encoding);

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

# Pending reply queue (avoid blocking packet handlers with HTTP)
my @queue;
# Per-player cooldown + short history
my %lastReply;
my %history;
my $busy = 0;

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
	message "[aiChat] loaded — set aiChat 1 and aiChat_apiKey (or OPENAI_API_KEY)\n", "system";
	_ensureDefaults();
}

sub _ensureDefaults {
	$config{aiChat} //= 0;
	$config{aiChat_apiUrl} //= 'https://api.openai.com/v1/chat/completions';
	$config{aiChat_model} //= 'gpt-4o-mini';
	$config{aiChat_public} //= 1;
	$config{aiChat_publicNeedName} //= 1;
	$config{aiChat_cooldown} //= 6;
	$config{aiChat_maxLen} //= 70;
	$config{aiChat_history} //= 4;
	$config{aiChat_timeout} //= 12;
	$config{aiChat_persona} //=
		'You are a friendly Ragnarok Online player chatting in-game. '
		. 'Reply naturally, briefly (1 short sentence), no OOC, no admitting you are a bot, '
		. 'no links, no markdown. Match the player language when possible.';
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
		my $keyHint = $key ? (substr($key, 0, 6) . '…') : '(none — using local fallback)';
		message "[aiChat] status\n"
			. "  enabled   : " . (enabled() ? 'yes' : 'no') . "\n"
			. "  api key   : $keyHint\n"
			. "  model     : $config{aiChat_model}\n"
			. "  public    : $config{aiChat_public} (needName=$config{aiChat_publicNeedName})\n"
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

	if (($config{aiChat_publicNeedName} || 0) == 1) {
		my $name = ($char && $char->{name}) ? $char->{name} : '';
		return unless $name ne '' && $msg =~ /\Q$name\E/i;
	}
	_enqueue({ type => 'c', user => $user, msg => $msg });
}

sub _ignored {
	my ($user) = @_;
	my $list = $config{aiChat_ignore} || '';
	return 0 if $list eq '';
	for my $n (split /\s*,\s*/, $list) {
		return 1 if lc($n) eq lc($user);
	}
	# never reply to self
	return 1 if $char && $char->{name} && lc($char->{name}) eq lc($user);
	return 0;
}

sub _enqueue {
	my ($item) = @_;
	my $user = $item->{user};
	my $cd = $config{aiChat_cooldown} || 6;
	unless ($item->{force}) {
		if ($lastReply{$user} && timeOut($lastReply{$user}, $cd)) {
			# timeOut returns true when elapsed — OK to proceed
		} elsif ($lastReply{$user} && !timeOut($lastReply{$user}, $cd)) {
			debug "[aiChat] cooldown skip for $user\n", "aiChat";
			return;
		}
	}
	# drop if same user already queued
	for my $q (@queue) {
		return if $q->{user} eq $user;
	}
	push @queue, $item;
}

sub onMainLoop {
	return unless enabled();
	return if $busy;
	return unless @queue;
	return unless $char && $field; # in game-ish

	my $item = shift @queue;
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
	my $reply = _generateReply($user, $msg);
	$reply = _sanitize($reply);
	unless (defined $reply && length $reply) {
		warning "[aiChat] empty reply for $user\n";
		return;
	}

	_pushHistory($user, 'assistant', $reply);
	$lastReply{$user} = { time => time };

	if ($type eq 'pm') {
		Commands::run("pm \"$user\" $reply");
		message "[aiChat] PM -> $user : $reply\n", "system";
	} else {
		Commands::run("c $reply");
		message "[aiChat] chat -> $user : $reply\n", "system";
	}
}

sub _pushHistory {
	my ($user, $role, $content) = @_;
	$history{$user} ||= [];
	push @{ $history{$user} }, { role => $role, content => $content };
	my $max = ($config{aiChat_history} || 4) * 2;
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
	# strip markdown leftovers
	$t =~ s/[*_`#]+//g;
	my $max = $config{aiChat_maxLen} || 70;
	if (length($t) > $max) {
		$t = substr($t, 0, $max - 1);
		$t =~ s/\s+\S*$//;
	}
	return $t;
}

sub _generateReply {
	my ($user, $msg) = @_;
	my $key = apiKey();
	if ($key ne '') {
		my $ai = eval { _callOpenAI($user, $msg, $key) };
		if ($@) {
			warning "[aiChat] API failed ($@) — fallback\n";
		} elsif (defined $ai && $ai ne '') {
			return $ai;
		}
	}
	return _localFallback($user, $msg);
}

sub _systemPrompt {
	my $name = ($char && $char->{name}) ? $char->{name} : 'Adventurer';
	my $job  = ($char && $char->{job}) ? $char->{job} : 'Novice';
	my $blvl = ($char && defined $char->{lv}) ? $char->{lv} : '?';
	my $map  = ($field && $field->baseName) ? $field->baseName : 'unknown';
	my $persona = $config{aiChat_persona} || 'You are a friendly RO player.';
	return "$persona\n"
		. "Your character name is $name ($job, base $blvl) on map $map.\n"
		. "Hard limit: one short chat line under " . ($config{aiChat_maxLen} || 70) . " characters.";
}

sub _callOpenAI {
	my ($user, $msg, $key) = @_;
	my $url   = $config{aiChat_apiUrl} || 'https://api.openai.com/v1/chat/completions';
	my $model = $config{aiChat_model} || 'gpt-4o-mini';
	my $timeout = $config{aiChat_timeout} || 12;

	my @messages = (
		{ role => 'system', content => _systemPrompt() },
	);
	if ($history{$user}) {
		push @messages, @{ $history{$user} };
	} else {
		push @messages, { role => 'user', content => $msg };
	}

	my $payload = encode_json({
		model => $model,
		temperature => 0.8,
		max_tokens => 80,
		messages => \@messages,
	});

	# Temp files — work on Windows and Linux
	my $tmpdir = $ENV{TEMP} || $ENV{TMP} || $ENV{TMPDIR} || '/tmp';
	$tmpdir =~ s/[\\\/]+$//;
	my $tmpIn  = "$tmpdir/aichat-req-$$.json";
	my $tmpOut = "$tmpdir/aichat-res-$$.json";
	open my $fh, '>:raw', $tmpIn or die "cannot write $tmpIn: $!";
	# JSON::Tiny encode_json already returns UTF-8 bytes
	print {$fh} $payload;
	close $fh;

	# Prefer curl; on Windows also try curl.exe
	my $curl = _findCurl() or die "curl not found in PATH (needed for AI API calls)";
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
	return $content;
}

# Lightweight local fallback when no API key / API down
sub _localFallback {
	my ($user, $msg) = @_;
	my $m = lc($msg);
	my @replies;

	if ($m =~ /\b(bot|botter|macro|openkore)\b/) {
		@replies = ("haha nah just grinding", "lol no", "just playing man");
	} elsif ($m =~ /\b(hi|hello|hey|yo|good ?day|sup)\b/) {
		@replies = ("hey $user", "yo", "hi!", "hey what's up");
	} elsif ($m =~ /\b(how are you|how's it going|hru)\b/) {
		@replies = ("pretty good, farming a bit", "all good, you?", "chillin");
	} elsif ($m =~ /\b(where|map|spot)\b/) {
		my $map = ($field && $field->baseName) ? $field->baseName : 'around here';
		@replies = ("just around $map", "nearby, grinding", "here on $map");
	} elsif ($m =~ /\b(party|pt)\b/) {
		@replies = ("maybe later, finishing this run", "solo for now", "thanks though");
	} elsif ($m =~ /\b(buff|bless|agi|heal)\b/) {
		@replies = ("no buffs on me sorry", "can't help with that rn");
	} elsif ($m =~ /\b(zeny|zeny|money|cheap|sell|buy)\b/) {
		@replies = ("broke as usual lol", "saving up actually", "not trading rn");
	} elsif ($m =~ /\b(thanks|ty|thx)\b/) {
		@replies = ("np", "anytime", "sure");
	} elsif ($m =~ /\b(lol|haha|lmao|xd)\b/) {
		@replies = ("lol", "haha", "xD");
	} else {
		@replies = (
			"oh?",
			"hmm",
			"true",
			"haha yeah",
			"nice",
			"busy grinding a bit, what's up?",
		);
	}
	return $replies[int(rand(@replies))];
}

1;
