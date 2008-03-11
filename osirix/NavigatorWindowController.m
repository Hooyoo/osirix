/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - GPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

#import "NavigatorWindowController.h"
#import "ViewerController.h"
#import "AppController.h"

static NavigatorWindowController *nav = 0L;

@implementation NavigatorWindowController

@synthesize navigatorView;
@synthesize viewerController;

+ (NavigatorWindowController*) navigatorWindowController
{
	return nav;
}

- (id)initWithViewer:(ViewerController*)viewer;
{
	self = [super initWithWindowNibName:@"Navigator"];
	if (self != nil)
	{
		nav = self;
		
		[self window];	// generate the awake from nib ! and populates the nib variables like navigatorView
		
		[self setViewer: viewer];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closeViewerNotification:) name:@"CloseViewerNotification" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setWindowLevel:) name:@"NSApplicationWillBecomeActiveNotification" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setWindowLevel:) name:@"NSApplicationWillResignActiveNotification" object:nil];
	}
	return self;
}

- (void)awakeFromNib; 
{
	
	
	[[self window] setAcceptsMouseMovedEvents:YES];
}

- (void)setViewer:(ViewerController*)viewer;
{
	[navigatorView saveTransformForCurrentViewer];
	if( viewerController != viewer)
	{
		[viewerController release];
		viewerController = [viewer retain];
	}
	
	if( [viewerController isDataVolumicIn4D: YES] == NO)
	{
		NSLog( @"unsupported data for 4D");
		[[self window] close];
		return;
	}
	
	[self initView];
	
	[navigatorView setViewer];
}

- (void)initView;
{
	[navigatorView setViewer];
	[self computeMinAndMaxSize];
	[self adjustWindowPosition];
	[[self window] setAcceptsMouseMovedEvents:YES];
	[[self window] makeFirstResponder:navigatorView];
}

- (IBAction)showWindow:(id)sender
{
	[self initView];
	[super showWindow:sender];
}

- (void)closeViewerNotification:(NSNotification*)notif;
{
//	if( [notif object] == viewerController)
//	{
//		[self setViewer: 0L];
//	}
	
	if([[ViewerController getDisplayed2DViewers] count] == 0)
	{
		[[self window] close];
	}
}

- (void) adjustWindowPositionWithTiling: (BOOL) withTiling;
{
	dontReEnter = YES;
	
	int height = [[self window] frame].size.height;
	
	NSRect r = [NavigatorView rect];
	
	r.origin.y = [[[self window] screen] visibleFrame].origin.y;
	r.size.height = height + [[self window] frame].origin.y - r.origin.y;
	
	if( r.size.height > [NavigatorView rect].size.height)
		r.size.height = [NavigatorView rect].size.height;
		
	if( r.size.height < [navigatorView minimumWindowHeight])
		r.size.height = [navigatorView minimumWindowHeight];
	
	[[self window] setFrame: r display:YES];
	
	if( r.size.height != height && withTiling == YES)
		[[AppController sharedAppController] tileWindows:self];
	
	dontReEnter = NO;
}

- (void) adjustWindowPosition;
{
	return [self adjustWindowPositionWithTiling: YES];
}

- (void)windowDidMove:(NSNotification *)notification
{
	if( dontReEnter == NO)
		[self adjustWindowPositionWithTiling: YES];
}

- (void)windowDidResize:(NSNotification *)aNotification
{
	if( dontReEnter == NO)
		[self adjustWindowPositionWithTiling: YES];
}

- (void)windowWillClose:(NSNotification *)notification
{
	[[self window] orderOut:self];
	[self release];
}

- (void)dealloc
{
	NSLog(@"NavigatorWindowController dealloc");
	nav = 0L;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[viewerController release];
	[super dealloc];
	[[AppController sharedAppController] tileWindows:self];
}

- (void)computeMinAndMaxSize;
{	
	NSSize maxSize = [navigatorView frame].size;
	maxSize.height += 16; // 16px for the title bar
	float screenWidth = [[[viewerController window] screen] frame].size.width;
	maxSize.width = screenWidth;
	if([[self window] frame].size.width < [navigatorView frame].size.width) maxSize.height += 11; // 11px for the horizontal scroller

	[[self window] setMaxSize:maxSize];
	
	NSSize minSize = NSMakeSize(navigatorView.thumbnailWidth, navigatorView.thumbnailHeight);
	minSize.height += 16; // 16px for the title bar
	minSize.width = screenWidth;
	if([[self window] frame].size.width < [navigatorView frame].size.width) minSize.height += 11; // 11px for the horizontal scroller
	
	[[self window] setMinSize:minSize];
}

- (void)setWindowLevel:(NSNotification*)notification;
{
	NSString *name = [notification name];
	if([name isEqualToString:NSApplicationWillBecomeActiveNotification])
		[[self window] setLevel:NSFloatingWindowLevel];
	else if([name isEqualToString:NSApplicationWillResignActiveNotification])
		[[self window] setLevel:[[viewerController window] level]];
}

@end