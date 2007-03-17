# $Id$
package Tic::Common;

use strict;
use vars ('@ISA', '@EXPORT');
use Exporter;
use Term::Shelly;
use Term::ReadKey;
use POSIX qw(strftime);


@ISA = qw(Exporter);
@EXPORT = qw(debug deep_copy prettyprint prettylog login set_config get_config
				 expand_aliases next_arg load feature prompter);

my $state;
my $sh;

sub set_state { 
	my $self = shift;
	#debug("Setting state for ::Common");
	$state = shift;
	$sh = $state->{"sh"};
}

sub import {
	#debug("Importing from Tic::Common");
	Tic::Common->export_to_level(1,@_);
}

# beware, hackish!
	
sub load {
	my $module = shift;

	my ($filename) = $module;

	$filename =~ s!::!/!g;
	$filename .= ".pm" if ($module !~ m/\.[a-zA-Z]+$/);
	if (exists $INC{$filename}) {
		return 1 if $INC{$filename};
		die "Compilation failed in require";
	}
	my ($realfilename,$result);
ITER: {
		foreach my $prefix (@INC) {
			$realfilename = "$prefix/$filename";
			if (-f $realfilename) {
				$INC{$filename} = $realfilename;
				$result = do $realfilename;
				last ITER;
			}
		}
		print STDERR "Unable to load $filename\n";

		return 0;
	}
	if ($@) {
		$INC{$filename} = undef;
		die $@;
	} elsif (!$result) {
		delete $INC{$filename};
		die "$filename did not return true value";
	} else {

		return (wantarray() ? (0, $@) : 0) if ($@);
		import($module,@_);
		$module->set_state($state);
		return 1;
	}
}

sub debug { foreach (@_) { $sh->error("debug> $_\n"); } }

sub prettyprint {
	my ($state, $type, $data) = @_;
	my $output;

	if ($type eq "help") {
		$sh->out($data->{"help"});
		return;
	}

	if (($state->{"timestamp"}) || (select() ne "main::STDOUT")) {
		my $timestamp;
		if (select() eq 'main::STDOUT') {
			$timestamp = $state->{"config"}->{"timestamp"};
		} else {
			$timestamp = $state->{"config"}->{"logstamp"};
		}

		$output = strftime($timestamp, localtime(time()));
		$output .= " ";
	}

	if (defined(get_config("$type"))) {
		 #$output .= $state->{"config"}->{"$type"};
		 $output .= get_config("$type");

		 # What are the escapes?
		 # %% - literal %
		 # %S - your own screen name
		 # %a - alias name
		 # %c - chatroom related to this message
		 # %e - error message
		 # %g - Group user belongs to
		 # %h - help topic
		 # %i - idle time of user 
		 # %m - Message being sent
		 # %s - Screen name of target (or who is messaging you)
		 # %v - alias value
		 # %w - warning level

		 $data->{"sn"} = getrealsn($state, $data->{"sn"});

		 if (ref($data) eq "HASH") {
			 $output =~ s/%s/$data->{"sn"}/g if (defined($data->{"sn"}));
			 $output =~ s/%m/$data->{"msg"}/g if (defined($data->{"msg"}));
			 $output =~ s/%g/$data->{"group"}/g if (defined($data->{"group"}));
			 $output =~ s/%c/$data->{"chat"}/g if (defined($data->{"chat"}));
			 $output =~ s/%w/$data->{"warn"}/g if (defined($data->{"warn"}));
			 $output =~ s/%i/$data->{"idle"}/g if (defined($data->{"idle"}));
			 $output =~ s/%e/$data->{"error"}/g if (defined($data->{"error"}));
			 $output =~ s/%h/$data->{"subject"}/g if (defined($data->{"subject"}));
			 $output =~ s/%a/$data->{"alias"}/g if (defined($data->{"alias"}));
			 $output =~ s/%v/$data->{"value"}/g if (defined($data->{"value"}));
			 $output =~ s/%S/$state->{"sn"}/g;
			 $output =~ s/%%/%/g;
		 }
	}

	$output =~ s![\r]!!g;
	$output =~ s!<br(?: ?/)?>!\n!gis;
	$output =~ s!<(?:(?:(?:html|body|font|b|i|u)(?:\s[^>]+)?)|(?:/(?:html|body|font|b|i|u)))>!!gi;

	if ($type =~ m/^error/) {
		$sh->error($output);
	} else {
		#out("< $type > $output");
		$sh->out($output);
	}
}

sub prettylog {
	my ($state, $type, $data) = @_;
	if (defined($data)) {
		if (defined($data->{"sn"})) {
			my $sn = getrealsn($state,$data->{"sn"});
			open(IMLOG, ">> ".$ENV{HOME}."/.tic/" . $sn . ".log") or 
				die("Failed trying to open ~/.tic/".$sn.".log - $!\nEvent: $type\n");
			select IMLOG;
			prettyprint(@_);
			select STDOUT;
			close(IMLOG);
		}
	}
}

sub deep_copy {
	my ($data) = shift;
	my $foo;

	if (ref($data) eq "HASH") {
		map { $foo->{$_} = $data->{$_} } keys(%{$data});
	}
	return $foo;
}

sub getrealsn {
	my ($state,$sn) = @_;
	my $foo = $state->{"aim"}->buddy($sn);
	return $foo->{"screenname"} if (defined($foo->{"screenname"}));
	return $sn;
}

sub login {
	my ($user,$pass) = @_;
	my ($fail) = 0;

	if (defined($pass)) {
		$state->{"login_password"} = $pass;
	}
	if (defined($user)) {
		get_username($user);
	} else {
		$sh->prompt("Login: ");
		$sh->{"readline_callback"} = \&get_username;
	}

}

sub get_username {
	$state->{"login_username"} = shift;

	unless (defined($state->{"login_password"})) {
		$sh->prompt("Password: ");
		$sh->{"readline_callback"} = \&get_password;
		$sh->echo(0);
	} else {
		get_password($state->{"login_password"});
	}
}

sub get_password {
	$state->{"login_password"} = shift;

	# Reset the prompt and echoing...
	$sh->prompt("");
	$sh->echo(1);

	do_login();
}

sub do_login {

	my $user = $state->{"login_username"};
	my $pass = $state->{"login_password"};

	$state->{"signon"} = 1;
	$state->{"aimok"} = 1;
	$sh->out("Logging in to AIM, please wait :)");
	my %hash = ( screenname => $user, 
					 password => $pass );
	$hash{"port"} = $state->{"settings"}->{"port"} || "5190";
	$hash{"host"} = $state->{"settings"}->{"server"} || "login.oscar.aol.com";

	$sh->out("Connecting to " . $hash{"host"} . ":" . $hash{"port"} . " as " . $hash{"screenname"});
	$state->{"aim"}->signon(%hash);

	$sh->{"readline_callback"} = $state->{"command_callback"};
}

sub get_config {
	my ($a) = @_;
	#out("$state | get_config($a) = " . $state->{"config"}->{$a});
	return $state->{"config"}->{$a};
}

sub set_config {
	my ($a,$b) = @_;
	#out("$state | set_config($a,$b)");
	$state->{"config"}->{$a} = $b;
}

sub expand_aliases {
	my ($string) = shift;
	my ($cmd,$args) = split(/\s+/, $string, 2);
	my ($commands, $aliases) = ($state->{"commands"}, $state->{"aliases"});

	if ($cmd =~ s!^/!!) {
		if (defined($commands->{$cmd})) {
			return "/$cmd $args";
		} elsif (defined($aliases->{$cmd})) {
			$state->{"recursion_check"}++;
			if ($state->{"recursion_check"} > 10) {
				$sh->out("Too much recursion in this alias. Aborting execution");
				$state->{"recursion_check"} = 0;
				return;
			}  
			($cmd, $args) = $aliases->{$cmd} . " " . $args;
			$string = expand_aliases($cmd,$args);
			$state->{"recursion_check"}--;
		}
	}


	return $string;
}

sub next_arg ($) {
	my $ref = shift;
	my $line = ${$ref};
	my $string;

	# The following is a use of (?(cond)yespattern|nopattern)
	# See perldoc perlre, look for "Conditional expressions"
  	my $ok = $line =~ s!^\s*(
								 (^")?        # Is there a doublequote at beginning?
								 (?(2)        # If regex $2 matched: Find the rest of
								              # string ending at another doublequote.
									[^"]+"     # Find the end of the quoted string
								  |           # else
								  \S+         # Match a word bounded by whitespace.
								 )
								)!!x;
	$string = $1;
	$string =~ s/^"(.*)"$/$1/;

	${$ref} = $line;

	return $string;
}

sub feature {
	my $feature = shift;

	return exists $INC{"Tic/Feature/$feature.pm"};
}

sub prompter($;$) {
   # Set/get certain parts of the prompt, and.. stuff
   # This could be putting AWAY in the prompt, showing message target, etc
   my $type = shift;
   my $value = shift || $state->{"prompter"}->{$type};
   
   #$sh->out("$type = $value");
   $state->{"target"} = $value if ($type eq 'TARGET');
   
   my $prompt = '';
   $prompt .= $value if ($type eq 'TARGET');
   if ($prompt) {
      $sh->prompt($prompt . '> ');
   } else {
      $sh->prompt("");
   }

   return $value;
}

1;
