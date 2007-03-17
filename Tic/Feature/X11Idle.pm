#!/usr/bin/perl 
# $Id$

package Tic::Feature::X11Idle;

use strict;
use Inline C => << "CODE", INC => '-I/usr/X11R6/include', LIBS => '-L/usr/X11R6/lib -lX11 -lXss -lXext';

#include <X11/Xlib.h>
#include <X11/extensions/scrnsaver.h>
#include <stdio.h>

static Display *dpy;
static Window rootwin;

void foo() {
	printf("hello world\\n");
}

int XConnect(char* display) {
	if (dpy == NULL) {
		if ( (dpy = XOpenDisplay(display)) == NULL) {
			fprintf(stderr, "Error: Can't open display: %s\\n", display);
			return 0;
		}
		rootwin = XDefaultRootWindow(dpy);
	}
	return 1;
}

int XGetIdle() {
	static XScreenSaverInfo *mit_info = NULL;
	int event_base, error_base;
	int idle = 0;

	if (XScreenSaverQueryExtension(dpy, &event_base, &error_base)) {
		if (mit_info == NULL) {
			mit_info = XScreenSaverAllocInfo();
		}
		XScreenSaverQueryInfo(dpy, rootwin, mit_info);
		idle = (mit_info->idle) / 1000;
	} else {
		fprintf(stderr, "XScreenSaverExtension not available on this display\\n");
	}

	return idle;
}

CODE

my $sh;
my $state;

sub set_state {
	my $self = shift;
	$state = shift;
	$sh = $state->{"sh"};
	$state->{"idle_callback"} = \&X11IdleCheck;
}

sub X11IdleCheck() {
	#my $state = shift;
	my $aim = $state->{"aim"};

	#if ($state->{"settings"}->{"idle_method"} =~ m/X(11)?/i)
	if (defined($state->{"settings"}->{"x11_display"})) {
		if ($state->{"last_x11_idle_check"} < time()) {

			$sh->out("Checking idle X11-style");
			# XConnect only connects if we aren't.
			if (XConnect($state->{"settings"}->{"x11_display"})) {
				$state->{"idle"} = time() - XGetIdle();
				$state->{"last_x11_idle_check"} = time();
				$sh->out("Idle: " . $state->{"idle"});

				if ($state->{"idle"} == time() && $state->{"is_idle"} == 1) {
					$sh->out("Setting not-idle");
					$aim->set_idle(0);
					$state->{"is_idle"} = 0;
				}
			} else {
				$sh->error("Resetting x11_display, cannot connect.");
				$state->{"settings"}->{"idle_method"} = undef;
			}
		}
	}
	#
}

sub testy { print "TESTING!\n"; }

print ("X11Idle loaded\n");

1;
