# $Id$
package Tic::Commands;

use strict;
use Tic::Common;
use Getopt::Std;
use HTML::Entities;
use POSIX qw(strftime);
use vars qw(@ISA @EXPORT);
use Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(create_alias remove_alias command_addbuddy command_msg
				 command_alias command_unalias command_echo command_info
				 command_login command_quit command_buddylist command_default
				 command_undefault command_log command_timestamp command_who
				 command_timestamp command_getaway command_help command_date
				 command_delbuddy command_away command_set command_ignore
				 command_unignore);

my $state;
my $sh;

my %USERFLAGS = (
	"a" => sub { my ($b) = @_; ($b->{online} && !$b->{away} && !defined($b->{idle_since})) },
	"w" => sub { my ($b) = @_; ($b->{online} && $b->{away}) },
	"i" => sub { my ($b) = @_; ($b->{online} && $b->{idle}) },
	"m" => sub { my ($b) = @_; ($b->{online} && $b->{mobile}) },
	"o" => sub { my ($b) = @_; ($b->{online}) },
	"f" => sub { my ($b) = @_; (!$b->{online}) },
);

sub import {
	#debug("Importing from Tic::Commands");
	Tic::Commands->export_to_level(1,@_);
}

sub set_state {
	my $self = shift;
	#debug("Setting state for ::Commands");
	$state = shift;
	Tic::Common->set_state($state);
	$sh = $state->{"sh"};
}

sub create_alias {
	my ($alias, $cmd) = @_;
	$alias =~ s!^/!!;

	$state->{"aliases"}->{$alias} = $cmd;
}

sub remove_alias {
	my ($alias) = @_;

	undef($state->{"aliases"}->{$alias});
}

sub command_msg {
	return "%s" if ($_[0] eq "completion");
	return << "HELP" if ($_[0] eq "help");
Syntax: /msg <screenname> <message>
HELP

	my $aim = $state->{"aim"};

	$state = shift;

	my ($args) = @_;
	my ($sn, $msg);
  
	if (scalar(@_) == 1) {
		$sn = next_arg(\$args);
		$msg = $args;
	} else {
		($sn, $msg) = @_;
	} 

	$sh->error("Message who?") and return unless defined($sn);
	$sh->error("You didn't tell me what to say!") and return unless defined($msg)&& length($msg) > 0;

	my $away = undef;
	if ($state->{"away_responding"}->{"$sn"} == 1) {
		$away = 1;
		delete($state->{"away_responding"}->{"$sn"});
	}

	my $wholog = get_config("who_log");
	if ((get_config("logging") eq "all" || ((ref($wholog) eq 'HASH' && $wholog->{"$sn"} == 1)))) {
		prettylog($state,"out_msg", { sn => $sn, msg => $msg } );
	}
	prettyprint($state,"out_msg", { sn => $sn, msg => $msg } );

	$aim->send_im($sn, encode_entities($msg, '<>'), $away);
}

sub command_help {
	return "%c" if ($_[0] eq "completion");
	if ($_[0] eq "help") {
		my $commands = join(" ",map("/$_",sort(keys(%{$state->{"commands"}}))));
		#$commands = join("\n", split(/^.{1,75} /,$commands));
		return << "HELP";
Syntax: /help <command>

Available Commands:
$commands

Features worth knowing about:
 - Tab completion: You can tab-complete aliases, commands, and screennames
   (depending on where they are in the command prompt)
 - Aliases: Tired of typing /msg foobar? Make an alias of it! See /help /alias
HELP
	} # if "help"

	my ($state,$what) = @_;
	$what =~ s/\s.*//;

	$what = "help" unless ($what ne "");
	if (defined($what)) {
		$what =~ s!^/!!;
		my $cmd = $state->{"commands"}->{$what};
		if (defined($cmd)) {
			#print STDERR "CMD: $cmd\n";
			prettyprint($state,"help", { help => &{$cmd}("help") } );
			return;
		}

		my $alias = $state->{"aliases"}->{$what};
		if (defined($alias)) {
			prettyprint($state,"alias_is", { alias => $what, value => $alias });
			return;
		}

		prettyprint($state,"nohelp", { subject => $what });
	}
}

sub command_alias {
	return "%a %c %ca" if ($_[0] eq "completion");
	return << "HELP" if ($_[0] eq "help");
Syntax: /alias <alias> <stuff to alias>
For example, let's say you wanted /p to be aliased to /msg psikronic
   /alias p /msg psikronic
Now typing "/p hey!" will send psikronic a message saying "hey!"
Aliases can be recursive, that is:
  /alias foo /msg
  /alias bar /foo psikronic
  /alias baz /bar Hey!
HELP

	$state = shift;
	my ($args) = @_;
	my ($alias, $cmd) = split(/\s+/, $args, 2);
	my $aliases = $state->{"aliases"};

	if ($alias =~ m/^$/) {
		if (scalar(keys(%{$aliases})) == 0) {
			$sh->out("There are no aliases set.");
		} else {
			$sh->out("Aliases:");
			foreach my $alias (keys(%{$aliases})) {
				next unless (defined($aliases->{$alias}));
				$sh->out("$alias => " . $aliases->{$alias});
			}
		}
		return;
	}

	if ($cmd =~ m/^$/) {
		if (defined($aliases->{$alias})) {
			$sh->out("$alias => " . $aliases->{$alias});
		} else {
			$sh->error("No such alias, \"$alias\"");
		}
	} else {
		create_alias($alias, $cmd);
	}
}

sub command_unalias {
	return "%a" if ($_[0] eq "completion");
	return << "HELP" if ($_[0] eq "help");
Syntax: /unalias <alias>
This command will remove an alias.
HELP
	$state = shift;
	my ($args) = @_;
	my ($alias) = split(/\s+/, $args);

	if ($alias =~ m/^$/) {
		$sh->error("Unalias what?");
		return;
	}

	remove_alias($alias);
	$sh->out("Removed the alias \"/$alias\"");
}

sub command_echo {
	return "" if ($_[0] eq 'completion');
	return << "HELP" if ($_[0] eq "help");
Syntax: /echo <string>
This isn't really useful, but whatever. It's obvious what this does.
HELP
	$state = shift;
	my ($args) = @_;
	$sh->out($args);
}

sub command_getaway {
	return "%s" if ($_[0] eq "completion");
	return << "HELP" if ($_[0] eq "help");
Syntax: /getaway <screenname>
Grabs the away message of the screenname you specify.
HELP
	$state = shift;
	my ($args) = @_;
	my $aim = $state->{"aim"};
	my $sn;

	$sn = next_arg(\$args);

	if ($sn eq '') {
		$sh->error("Invalid number of arguments to /getaway");
		return;
	}
	$aim->get_away($sn);

}

sub command_info {
	return "%s" if ($_[0] eq "completion");
	return << "HELP" if ($_[0] eq "help");
Syntax: /info <screenname>
This will look up the user's profile and display it. If you have lynx installed,
the output will be filtered through it so that html will be pretty.
HELP
	$state = shift;
	my ($args) = @_;
	my $aim = $state->{"aim"};
	my ($sn,$key);

	$sn = next_arg(\$args);
	$key = $args;

	if ($sn eq '') {
		$sh->error("Invalid number of arguments to /info.");
		return;
	}

	if ($key eq '') {
		$sh->out("Fetching user info for $sn");
		$aim->get_info($sn);
	} else {
		$sh->out("State info for $sn");
		$sh->out("$key: " . $aim->buddy($sn)->{$key});
	}
}

sub command_login {
	return "" if ($_[0] eq 'completion');
	return << "HELP" if ($_[0] eq "help");
Syntax: /login
Re-login. Useful if you've been disconnected.
HELP
	$state = shift;
	my ($args) = @_;
	my $aim = $state->{"aim"};
	if ($args eq '-f') {
		login();
	} else {
		if ($aim->is_on()) {
			$sh->error("You are already logged in, use /login -f to force reconnection.");
		} else {
			login();
		}
	}
}

sub command_quit {
	return "" if ($_[0] eq 'completion');
	return << "HELP" if ($_[0] eq "help");
Syntax: /quit
Duh.
HELP
	$state = shift;
	my ($args) = @_;
	my $aim = $state->{"aim"};
	$sh->error("Bye :)");
	$aim->signoff();
	exit;
}

sub command_buddylist {
	return "" if ($_[0] eq 'completion');
	return << "HELP" if ($_[0] eq "help");
Syntax: /buddylist
Displays your buddy list in a semi-formatted, partially ordered fashion.
HELP
	$state = shift;
	my ($args) = @_;
	my $aim = $state->{"aim"};

	foreach my $g ($aim->groups()) {
		$sh->out($g);
		foreach my $b ($aim->buddies($g)) {
			my $bud = $aim->buddy($b,$g);

			my $extra;
			if ($bud) {
				$extra .= " [MOBILE]" if $bud->{mobile};
				$extra .= " [TYPINGSTATUS]" if $bud->{typingstatus};
				$extra .= " [ONLINE]" if $bud->{online};
				$extra .= " [TRIAL]" if $bud->{trial};
				$extra .= " [AOL]" if $bud->{aol};
				$extra .= " [FREE]" if $bud->{free};
				$extra .= " [AWAY]" if $bud->{away};
				$extra .= " {".$bud->{comment}."}" if defined $bud->{comment};
				$extra .= " {{".$bud->{alias}."}}" if defined $bud->{alias};
				$extra .= " (".$bud->{extended_status}.")" if defined $bud->{extended_status};
			}

			$sh->out("$b ($extra)");
		}
	}
}

sub command_default {
	return "%s" if ($_[0] eq "completion");
	return << "HELP" if ($_[0] eq "help");
Syntax: /default <screenname>
Sets the default user to send messages do. Once set, you no longer have to type
/msg to send this person a message. You can simply type at the prompt. This is
useful for convenience-sake and for pasting things to someone
HELP
	$state = shift;
	my ($args) = @_;
	my $aim = $state->{"aim"};
	($args) = split(/\s+/,$args);

	if ($args eq '') {
		if ($state->{"default"}) {
			$sh->out("Default target: " . $state->{"default"});
		} else {
			$sh->error("No default target yet");
		}
	} else {
		$args = next_arg(\$args);
		if ($aim->buddy("$args")) {
			$state->{"default"} = $args;
			$sh->out("New default target: $args");
			prompter("TARGET", $state->{"default"});
		} elsif ($args eq ';') {
			if ($state->{"last_from"}) {
				$state->{"default"} = $state->{"last_from"};
				$sh->out("New default target: " . $state->{"default"});
				prompter("TARGET", $state->{"default"});
			} else {
				$sh->error("No one has sent you a message yet... what are you trying to do?!");
			}
		} else {
			$sh->error("The buddy $args is not on your buddylist, I won't default to it.");
		}
	}
}

sub command_undefault {
	return "" if ($_[0] eq 'completion');
	return << "HELP" if ($_[0] eq "help");
Syntax: /undefault
This will clear the default target setting.
HELP
	$state = shift;
	my ($args) = @_;
	$sh->out("Default target cleared.");
	prompter("TARGET", undef);
	undef($state->{"default"});
}

sub command_log {
	return "%s" if ($_[0] eq "completion");
	return << "HELP" if ($_[0] eq "help");
Syntax: /log <<+|->screenname>|<on|off>
This has lots of different uses:
/log +                  Turn logging on for *everyone*
/log +screenname        Turn logging on for only this screenname. You can log
                        multiple people at once, this simply adds people to
								the list of ones to log.
/log -screenname        Disable logging for this screenname
/log -                  Completely disable all logging
/log on                 Enable logging (NOT THE SAME AS /log +)
/log off                Same as /log -
HELP
                        
	$state = shift;
	my ($args) = @_;

	if ($args eq "+" || $args eq "all") {
		set_config("logging", "all");
		$sh->out("Now logging all messages.");
		$sh->out("Getconfig log: " . get_config("logging"));
	} elsif (($args eq "-") || ($args =~ m/^off$/i)) {
		set_config("logging", "off");
		$sh->out("Stopping all logging.");
	} elsif ($args =~ m/^on$/) {
		set_config("logging", "on");
		$sh->out("Logging is now on.");
	} elsif ($args eq '') {
		set_config("logging", "off") unless (defined(get_config("logging")));
		my $logstate = get_config("logging");
		$sh->out("Logging: $logstate");
		if ($logstate =~ m/^only/) {
			my $who = get_config("who_log");
			my @wholog = grep($who->{$_} == 1, keys(%{$who}));
			$sh->out("Currently logging: " . join(", ", @wholog));
		}
	} else {
		set_config("logging", "only specified users");
		set_config("who_log", {}) unless defined(get_config("who_log"));

		foreach (split(/\s+/,$args)) {
			if (m/^-(.*)/) {
				get_config("who_log")->{$1} = undef;
				$sh->out("Stopped logging $1");
			} elsif (m/^\+?(.+)/) {
				get_config("who_log")->{$1} = 1;
				$sh->out("Logging for $1 started");
			}
		}
	}

}

sub command_timestamp {
	return "" if ($_[0] eq 'completion');
	return << "HELP" if ($_[0] eq "help");
Syntax: /timestamp on|off
Turns timestamping of output on or off.
HELP

	$state = shift;
	my ($args) = @_;
	#$sh->out("command_timestamp($state,$args)");

	if ($args =~ m/^(yes|on|plz)$/i) {
		$state->{"timestamp"} = 1;
		prettyprint($state, "generic_status", { msg => "Timestamps are now on." } );
	} elsif ($args =~ m/^(no|off)$/i) {
		$state->{"timestamp"} = 0;
		prettyprint($state, "generic_status", { msg => "Timestamps are now off." } );
	} elsif ($args =~ m/^$/) {
		my $status = ( ($state->{"timestamp"}) ? "on" : "off" );
		prettyprint($state, "generic_status", { msg => "Timestamps are $status." } );
	} else {
		prettyprint($state, "error_generic", "Invalid parameter to /timestamp");
	}
}

sub command_date {
	return "" if ($_[0] eq 'completion');
	return << "HELP" if ($_[0] eq "help");
Syntax: /date
Display's a timestamp.
HELP
	$sh->out("Time: " . strftime(get_config("timestamp"),localtime(time)));

}

sub command_who {
	return "" if ($_[0] eq 'completion');
	return << "HELP" if ($_[0] eq "help");
Syntax: /who
Displays your buddy list
HELP
	$state = shift;

	my ($args) = @_;
	my $aim = $state->{"aim"};

	my $count = 0;
	foreach my $g ($aim->groups()) {
		my @buddies = $aim->buddies($g);
		@buddies = map { 
			my $bd = $aim->buddy($_,$g);
			unless ($bd->{"online"}) {
				$bd = { "online" => 0, "screenname" => $_ };
			}
			$bd;
		} @buddies;

		#map { $sh->out("B: " . $_->{"screenname"}); } @buddies;
		
		# Only display all matches to their query?
		# -a    active
		# -w    away
		# -o    offline
		# -i    idle
		# -m    mobile

		my %opts;
		@ARGV = split(/\s+/, $args);
		getopts('awoimf', \%opts);

		foreach my $flag (grep($opts{$_} == 1, keys(%opts))) { 
			my $sub = $USERFLAGS{$flag};
			#out("Grepping for $flag - " . scalar(@buddies) . "before");
			@buddies = grep($sub->($_), @buddies);
			#out("After:" . scalar(@buddies));
		}

		my $reg = join(" ", @ARGV);
		if (length($reg) > 0) {
			eval "m/$reg/";
			if ($@) {
				$sh->error("Invalid regular expression, '$reg'");
				return;
			}
			@buddies = grep($_->{"screenname"} =~ m/$reg/i, @buddies);
		}

		$sh->out("$g") if scalar(@buddies);
		$count += scalar(@buddies);
		my @buddies = sort { lc($a->{"screenname"}) cmp lc($b->{"screenname"}) } @buddies;
		foreach my $b (@buddies) {
			next unless (ref($b) eq 'HASH');
			my $bl = $b->{"screenname"} . " (";
			$bl .= " active" if (&{$USERFLAGS{"a"}}($b));
			$bl .= " away" if (&{$USERFLAGS{"w"}}($b));
			$bl .= " online" if (&{$USERFLAGS{"o"}}($b));
			$bl .= " offline" if (&{$USERFLAGS{"f"}}($b));
			$bl .= " mobile" if (&{$USERFLAGS{"m"}}($b));
			$bl .= " idle [" . idletime($b) . "]" if (&{$USERFLAGS{"i"}}($b));
			$bl .= " )";
			$sh->out("\t$bl");
		}
	}
	$sh->error("No buddies matching your query, '$args'") if ($count == 0);
}

sub command_addbuddy {
	return "" if ($_[0] eq 'completion');
	return << "HELP" if ($_[0] eq "help");
Syntax: /addbuddy <buddy name> [group]
Adds a buddy to your buddy list. Put quotes around the name if there are spaces
in it. If you want to add them to a particular group, then specify that too.
Again, as with buddies, if you have spaces in your group name enclose it in
quotes.
HELP
	$state = shift;

	my ($args) = @_;
	my $aim = $state->{"aim"};

	my ($sn, $group);
	if ($args =~ m/^"([^"]+)"\s+(.*$)/) {
		($sn, $args) = ($1, $2);
	} else {
		($sn, $args) = split(/\s/, $args, 2);
	}

	if ($args =~ m/^"([^"]+)"(.*$)/) {
		($group, $args) = ($1, $2);
	} else {
		($group, $args) = split(/\s/, $args, 2);
	}

	$sh->error("No buddy specified to add :(") and return unless length($sn) > 0;

	$group = "Buddies" if (length($group) == 0);
	$aim->add_buddy($group, $sn);
	$aim->commit_buddylist();
}

sub command_delbuddy {
	return "%s" if ($_[0] eq 'completion');
	return << "HELP" if ($_[0] eq "help");
Syntax: /delbuddy <buddy name>
Deletes a buddy from your buddy list. Put quotes around the name if there are spaces in it. 
HELP
	$state = shift;

	my ($args) = @_;
	my $aim = $state->{"aim"};

	my ($sn, $group);
	$sn = next_arg(\$args);

	if (length($sn) == 0) {
		$sh->error("No buddy specified to delete :(");
		return;
	}

	my $buddy = $state->{"aim"}->buddy($sn);
	$group = $aim->findbuddy($buddy->{"screenname"});
	if (defined($group)) {
		$aim->remove_buddy($group, $buddy);
		$aim->commit_buddylist();
	} else {
		$sh->error("No such buddy, '$sn' found in your buddy list.");
	}

}

sub command_away {
	return "%s" if ($_[0] eq 'completion');
	return << "HELP" if ($_[0] eq "help");
Syntax: /away [ message ]
Sets away if you include an away message. Sets you back (not away) if no message is given.
HELP
	$state = shift;

	my ($args) = @_;
	my $aim = $state->{"aim"};

	my $msg = $args;

	if (length($msg) == 0) {
		if (defined($state->{"away"})) {
			$sh->prompt("");
			$sh->out("You are no longer away...");
			$aim->set_away("");
			delete $state->{"away"};
		} else {
			$sh->error("Go away with what message?");
		}
	} else {
		$sh->prompt("AWAY> ");
		$aim->set_away($args);
		$state->{"away"} = $args;
		$sh->out("You have gone away: $args");
	}
}

sub command_set {
	return "%s" if ($_[0] eq 'completion');
	return << "HELP" if ($_[0] eq "help");
Syntax: /set option[=value]
If the value is specified, it will set the given option to the value. If the value is omitted, then the current value will be printed.
HELP
	my $state = shift;
	my ($args) = @_;

	my ($key, $val) = split(/\s*=\s*/, $args, 2);

	$state->{"settings"}->{$key} = $val if ($val);
	$sh->out("$key = $val");
}

sub command_ignore {
	return "%s" if ($_[0] eq 'completion');
	return << "HELP" if ($_[0] eq 'help');
Syntax: /ignore <buddy name>
Ignores the given buddy. Shame on them for bothering you!
HELP
	my $state = shift;
	my ($args) = @_;
	my $sn = next_arg(\$args);

	$state->{"aim"}->add_deny($sn);
	$state->{"aim"}->commit_buddylist();
}

sub command_ignore {
	return "%s" if ($_[0] eq 'completion');
	return << "HELP" if ($_[0] eq 'help');
Syntax: /unignore <buddy name>
Stops ignoring the given buddy. I guess you like them again?
HELP
	my $state = shift;
	my ($args) = @_;
	my $sn = next_arg(\$args);

	$state->{"aim"}->remove_deny($sn);
	$state->{"aim"}->commit_buddylist();
}

sub compare {
	local $a = buddyscore($a);
	local $b = buddyscore($b);
	return $a <=> $b;
}

sub buddyscore {
	my $buddy = shift;
	$buddy = $state->{"aim"}->buddy($buddy);
	my $sum = 0;
	return -11 if (!defined($buddy));

	$sum += 10 if ($buddy->{online});
	$sum -= 10 unless ($buddy->{online}); 
	$sum -= 5 if ($buddy->{away});
	$sum -= 3 if ($buddy->{idle});
	#out($buddy->{"screenname"} . " = $sum");

	return $sum;
}

sub idletime {
	my $buddy = shift;
	my $time = time() - $buddy->{"idle_since"};

	my ($s, $m, $h);

	$h = int($time / 3600); $time = $time % 3600;
	$m = int($time / 60); 
	$s= $time % 60;

	return sprintf("%02d:%02d:%02d",$h, $m, $s);
}

1;
