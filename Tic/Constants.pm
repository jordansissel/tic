# $Id$
package Tic::Constants;

use Tic::Common;
use vars ('@ISA', '@EXPORT');

use Exporter;
use constant KEY_CONSTANTS => {
		"\e[A"    => "UP",
		"\e[B"    => "DOWN",
		"\e[C"    => "RIGHT",
		"\e[D"    => "LEFT",
};

use constant DEFAULT_SETTINGS => {

};

use constant DEFAULT_CONFIG => {
	"timestamp"        => "(%H:%M:%S)",
	"logstamp"         => "[%m/%d/%y %H:%M:%S]",
	"im_awaymsg"       => "[AWAY] <*%s*> %m",
	"im_msg"           => "\e[33m<*%s*>\e[0m %m",
	"out_msg"          => ">>%s>> %m", 

	"chat_buddy_in"    => "(%c) %s joined the chat.",
	"chat_buddy_out"   => "(%c) %s left the chat.",
	"chat_closed"      => "(%c) Chat closed. %e",
	"chat_im_in"       => "(%c) <*%s*> %m",

	"buddy_in"         => "* got buddy_in for %s",
	"buddy_online"     => "* %s (%g) is online",
	"buddy_offline"    => "* %s (%g) went offline",
	"buddy_away"       => "* %s went away",
	"buddy_notaway"    => "* %s is back",
	"buddy_idle"       => "* %s is idle (%i)",
	"buddy_notidle"    => "* %s is no longer idle",

	"evil_user"        => "* You were warned by %s. Your new warn level is %w%%",
	"evil_anon"        => "* You were warnked anonymously. Your new warn level is %w%%",

	"generic_status"   => "* %m",
	"nohelp"           => "There is no help available for %h",
	"alias_is"         => "%a is aliased to '%v'",

	"error_rate_alert" => "Slow down! You're sending messages too fast.",
"error_rate_limit" => "Message rate limit exceeded. Your messages are being ignored from the server :(",
	"error_rate_disco" => "You're about to be disconnected because you're sending too many messages.",

	"error_generic"    => "Error: %e",
	"error_unknown_command" => "Unknown command, '%k'",

	"idle_timeout"     => 600,

};

@ISA = qw(Exporter);
@EXPORT = qw(KEY_CONSTANTS DEFAULT_CONFIG DEFAULT_SETTINGS);

sub import {
	#debug("Importing from Tic::Constants");
	Tic::Constants->export_to_level(1,@_);
}

# true dat...
1;
