/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - GPL
  
  See http://homepage.mac.com/rossetantoine/osirix/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/


/***************************************** MODIFICATION HISTORY *********************************************

Version 2.3

	20060114	DDP	Moving duplicated and common inherited code up from children.
					: endClut and its variables.
					: ApplyCLUT, AddCLUT and clutAction.
					: UpdateCLUTMenu, clutPopup.
					: The next stage is probably to create an intermediary class between the 3D controllers and ViewerController,
					  which both inherit from NSWindowController (one step at a time though).
					: offFullScreen (was called offFullscren).
	20060115	DDP	: CLUTChanged, deleteCLUT.
					: Declared ApplyCLUTString, but this currently remains overriden in children.
					: endNameWLWW.
					: endOpacity, ApplyOpacity, deleteOpacity, deleteWLWW, wlwwPopup, OpacityPopup.
					Moved #defines of DATABASEPATH and STATEDATABASE into this header file.
	20060116	DDP Corrected introduced error failing the endoscopy viewer.  This file now refers to [self view] instead of view.



*/






#import "Window3DController.h"
#import "Mailer.h"
#import "Papyrus3/Papyrus3.h"
#import "Accelerate.h"
#import "DCMPix.h"
#import "VRController.h"
#import "printView.h"

extern NSString* convertDICOM( NSString *inputfile);
extern NSString * documentsDirectory();

@implementation Window3DController

- (NSArray*) pixList
{
	return 0L;
}

- (NSArray*) fileList
{
	return 0L;
}

- (void)printOperationDidRun:(NSPrintOperation *)printOperation
                success:(BOOL)success
                contextInfo:(void*)info
{
    if (success)
	{
	
    }
	
	NSString	*tmpFolder = [NSString stringWithFormat:@"/tmp/print"];
	
	[[NSFileManager defaultManager] removeFileAtPath: tmpFolder handler:nil];
}

- (void) print:(id) sender
{
	NSMutableDictionary	*settings = [NSMutableDictionary dictionaryWithDictionary: [[NSUserDefaults standardUserDefaults] objectForKey: @"previousPrintSettings"]];
	
	[settings setObject: [NSNumber numberWithInt: 1] forKey: @"columns"];
	[settings setObject: [NSNumber numberWithInt: 1] forKey: @"rows"];
		
	// ************
	NSString	*tmpFolder = [NSString stringWithFormat:@"/tmp/print"];
	
	NSMutableArray	*files = [NSMutableArray array];

	[[NSFileManager defaultManager] removeFileAtPath: tmpFolder handler:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:tmpFolder attributes:nil];

	NSImage *im = ( [[self view] respondsToSelector: @selector(nsimageQuicktime:)] ) ?
		[[[self view] nsimageQuicktime] autorelease] : nil;
	
	NSData *imageData = [im  TIFFRepresentation];
	NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
	NSData *bitmapData = [imageRep representationUsingType:NSJPEGFileType properties:[NSDictionary dictionaryWithObject:[NSDecimalNumber numberWithFloat:0.9] forKey:NSImageCompressionFactor]];
	
	[files addObject: [tmpFolder stringByAppendingFormat:@"/%d", 1]];
	
	[bitmapData writeToFile: [files lastObject] atomically:YES];

	// ************
	
	printView	*pV = [[[printView alloc] initWithViewer: self settings: settings files: files] autorelease];
			
	NSPrintOperation * printOperation = [NSPrintOperation printOperationWithView: pV];
	
	[printOperation setCanSpawnSeparateThread: YES];
	
	[printOperation runOperationModalForWindow:[self window]
		delegate:self
		didRunSelector: @selector(printOperationDidRun:success:contextInfo:)
		contextInfo:0L];
}

//====================================================================================================================================================================================================================

- (BOOL)is4D;
{
	return NO;
}

- (void) sendMailImage: (NSImage*) im
{
	Mailer		*email;
	
	NSArray *representations;
	NSData *bitmapData;

	representations = [im representations];

	bitmapData = [NSBitmapImageRep representationOfImageRepsInArray:representations usingType:NSJPEGFileType properties:[NSDictionary dictionaryWithObject:[NSDecimalNumber numberWithFloat:0.9] forKey:NSImageCompressionFactor]];

	[bitmapData writeToFile:[documentsDirectory() stringByAppendingFormat:@"/TEMP/OsiriX.jpg"] atomically:YES];
				
	email = [[Mailer alloc] init];
	
	[email sendMail:@"--" to:@"--" subject:@"" isMIME:YES name:@"--" sendNow:NO image: [documentsDirectory() stringByAppendingFormat:@"/TEMP/OsiriX.jpg"]];
	
	[email release];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (ViewerController*) blendingController
{
	return 0L;
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (id) view
{
	return 0L;
}

-(long) movieFrames { return 1;}

- (void) setMovieFrame: (long) l
{

}

- (void) dealloc
{
	NSLog(@"Window3DController dealloc");
	
	[curCLUTMenu release];
	[curWLWWMenu release];
	[curOpacityMenu release];
	
	[super dealloc];
}

/* nothing to do
- (void)finalize {
}
*/

//====================================================================================================================================================================================================================
#pragma mark-
#pragma mark Common WL/WW Functions

- (void) setWLWW: (float) wl : (float) ww
{
// Override
	NSLog(@"Error: inherited [Window3DController setWLWW] should not be called");
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) getWLWW: (float*) wl : (float*) ww
{
// Override
	NSLog(@"Error: inherited [Window3DController getWLWW] should not be called");
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

static float oldsetww, oldsetwl;

- (IBAction) updateSetWLWW:(id) sender
{
	if( [sender tag] == 0)
	{
		[self setWLWW: [wlset floatValue] :[wwset floatValue]];
		
		[fromset setStringValue: [NSString stringWithFormat:@"%.3f", [wlset floatValue] - [wwset floatValue]/2]];
		[toset setStringValue: [NSString stringWithFormat:@"%.3f", [wlset floatValue] + [wwset floatValue]/2]];
	}
	else
	{
		[self setWLWW: [fromset floatValue] + ([toset floatValue] - [fromset floatValue])/2 :[toset floatValue] - [fromset floatValue]];
		[wlset setStringValue: [NSString stringWithFormat:@"%.3f", [fromset floatValue] + ([toset floatValue] - [fromset floatValue])/2]];
		[wwset setStringValue: [NSString stringWithFormat:@"%.3f", [toset floatValue] - [fromset floatValue]]];
	}
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (IBAction) SetWLWW: (id) sender
{
	float iwl, iww;
	
    [self getWLWW:&iwl :&iww];
    
	oldsetww = iww;
	oldsetwl = iwl;
	
    [wlset setStringValue:[NSString stringWithFormat:@"%.3f", iwl ]];
    [wwset setStringValue:[NSString stringWithFormat:@"%.3f", iww ]];
	
	[fromset setStringValue:[NSString stringWithFormat:@"%.3f", [wlset floatValue] - [wwset floatValue]/2]];
	[toset setStringValue:[NSString stringWithFormat:@"%.3f", [wlset floatValue] + [wwset floatValue]/2]];
	
    [NSApp beginSheet: setWLWWWindow modalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (IBAction) endSetWLWW: (id) sender
{
	[wlset selectText: self];
		
    [setWLWWWindow orderOut: sender];
    
    [NSApp endSheet: setWLWWWindow returnCode: [sender tag]];
    
    if( [sender tag])   //User clicks OK Button
    {
		[self setWLWW: [wlset floatValue] :[wwset floatValue] ];
    }
	else
	{
		[self setWLWW: oldsetwl : oldsetww ];
	}
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (IBAction) endNameWLWW: (id) sender
{
	float					iww, iwl;
	
    NSLog(@"endNameWLWW");
    
    iwl = [wl floatValue];
    iww = [ww floatValue];
    if (iww == 0) iww = 1;

    [addWLWWWindow orderOut: sender];
    
    [NSApp endSheet:addWLWWWindow returnCode: [sender tag]];
    
    if( [sender tag])					//User clicks OK Button
    {
		NSMutableDictionary *presetsDict = [[[[NSUserDefaults standardUserDefaults] dictionaryForKey: @"WLWW3"] mutableCopy] autorelease];
        [presetsDict setObject:[NSArray arrayWithObjects:[NSNumber numberWithFloat:iwl], [NSNumber numberWithFloat:iww], 0L] forKey:[newName stringValue]];
		[[NSUserDefaults standardUserDefaults] setObject: presetsDict forKey: @"WLWW3"];
		
		if( curWLWWMenu != [newName stringValue])
		{
			[curWLWWMenu release];
			curWLWWMenu = [[newName stringValue] retain];
		}
        [[NSNotificationCenter defaultCenter] postNotificationName: @"UpdateWLWWMenu" object: curWLWWMenu userInfo: 0L];
    }
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) deleteWLWW: (NSWindow *) sheet returnCode: (int) returnCode contextInfo: (void*) contextInfo
{
	NSString	*name = (id) contextInfo;
	
    if( returnCode == 1)
    {
		NSMutableDictionary *presetsDict = [[[[NSUserDefaults standardUserDefaults] dictionaryForKey: @"WLWW3"] mutableCopy] autorelease];
        [presetsDict removeObjectForKey: name];
		[[NSUserDefaults standardUserDefaults] setObject: presetsDict forKey: @"WLWW3"];
		[[NSNotificationCenter defaultCenter] postNotificationName: @"UpdateWLWWMenu" object: curWLWWMenu userInfo: 0L];
    }
	
	[name release];
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (NSPopUpButton*) wlwwPopup
{
	return wlwwPopup;
}


//====================================================================================================================================================================================================================
#pragma mark-
#pragma mark Common CLUT Functions

- (IBAction) AddCLUT: (id) sender
{
	[self clutAction: self];
	[clutName setStringValue: NSLocalizedString(@"Unnamed", Nil)];
	
    [NSApp beginSheet: addCLUTWindow modalForWindow: [self window] modalDelegate: self didEndSelector: Nil contextInfo: Nil];
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (IBAction) clutAction: (id) sender
{
	long				i;
	NSMutableArray		*array;

//	[view setCLUT:matrix :[[sizeMatrix selectedCell] tag] :[matrixNorm intValue]];
//	[imageView setIndex:[imageView curImage]];
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (IBAction) endCLUT: (id) sender
{
    [addCLUTWindow orderOut:sender];
    
    [NSApp endSheet:addCLUTWindow returnCode:[sender tag]];
    
    if( [sender tag])   //User clicks OK Button
    {
		NSMutableDictionary *clutDict		= [[[[NSUserDefaults standardUserDefaults] dictionaryForKey: @"CLUT"] mutableCopy] autorelease];
		NSMutableDictionary *aCLUTFilter	= [NSMutableDictionary dictionary];
		unsigned char		red[256], green[256], blue[256];
		long				i;
		
		[clutView ConvertCLUT: red: green: blue];
		
		NSMutableArray		*rArray = [NSMutableArray arrayWithCapacity:0];
		NSMutableArray		*gArray = [NSMutableArray arrayWithCapacity:0];
		NSMutableArray		*bArray = [NSMutableArray arrayWithCapacity:0];
		for( i = 0; i < 256; i++) [rArray addObject: [NSNumber numberWithLong: red[ i]]];
		for( i = 0; i < 256; i++) [gArray addObject: [NSNumber numberWithLong: green[ i]]];
		for( i = 0; i < 256; i++) [bArray addObject: [NSNumber numberWithLong: blue[ i]]];
		
		[aCLUTFilter setObject:rArray forKey:@"Red"];
		[aCLUTFilter setObject:gArray forKey:@"Green"];
		[aCLUTFilter setObject:bArray forKey:@"Blue"];
		
		[aCLUTFilter setObject:[NSArray arrayWithArray:[[[clutView getPoints] copy] autorelease]] forKey:@"Points"];
		[aCLUTFilter setObject:[NSArray arrayWithArray:[[[clutView getColors] copy] autorelease]] forKey:@"Colors"];

		
		[clutDict setObject: aCLUTFilter forKey:[clutName stringValue]];
		[[NSUserDefaults standardUserDefaults] setObject: clutDict forKey: @"CLUT"];
		
		// Apply it!
		if( curCLUTMenu != [clutName stringValue])
		{
			[curCLUTMenu release];
			curCLUTMenu = [[clutName stringValue] retain];
        }
		[[NSNotificationCenter defaultCenter] postNotificationName: @"UpdateCLUTMenu" object: curCLUTMenu userInfo: 0L];
		
		[self ApplyCLUTString: curCLUTMenu];
    }
	else
	{
		[self ApplyCLUTString: curCLUTMenu];
	}
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) ApplyCLUT: (id) sender
{
    if ([[[NSApplication sharedApplication] currentEvent] modifierFlags]  & NSShiftKeyMask)
    {
        NSBeginAlertSheet(NSLocalizedString(@"Remove a Color Look Up Table", nil), NSLocalizedString(@"Delete", nil), NSLocalizedString(@"Cancel", nil), nil, [self window],
		  self, @selector(deleteCLUT:returnCode:contextInfo:), NULL, [sender title], [NSString stringWithFormat: NSLocalizedString( @"Are you sure you want to delete this CLUT : '%@'", 0L), [sender title]]);
		[[NSNotificationCenter defaultCenter] postNotificationName: @"UpdateCLUTMenu" object: curCLUTMenu userInfo: 0L];
	}
	else if ([[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSAlternateKeyMask)
    {
		NSDictionary		*aCLUT;
		NSArray				*array;
		long				i;
		unsigned char		red[256], green[256], blue[256];
		
		[self ApplyCLUTString: [sender title]];
		
		aCLUT = [[[NSUserDefaults standardUserDefaults] dictionaryForKey: @"CLUT"] objectForKey: curCLUTMenu];
		if (aCLUT)
		{
			if( [aCLUT objectForKey:@"Points"] != 0L)
			{
				[self clutAction:self];
				[clutName setStringValue: [sender title]];
				
				NSMutableArray	*pts = [clutView getPoints];
				NSMutableArray	*cols = [clutView getColors];
				
				[pts removeAllObjects];
				[cols removeAllObjects];
				
				[pts addObjectsFromArray: [aCLUT objectForKey: @"Points"]];
				[cols addObjectsFromArray: [aCLUT objectForKey: @"Colors"]];
				
				[NSApp beginSheet: addCLUTWindow modalForWindow: [self window] modalDelegate: self didEndSelector: Nil contextInfo: Nil];
				
				[clutView setNeedsDisplay: YES];
			}
			else
			{
				NSRunAlertPanel(NSLocalizedString(@"Error", nil), NSLocalizedString(@"Only CLUT created in OsiriX 1.3.1 or higher can be edited...", nil), nil, nil, nil);
			}
		}
	}
    else
    {
		[self ApplyCLUTString: [sender title]];
    }
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) ApplyCLUTString: (NSString*) str
{
//	Override.
	NSLog(@"Error: inherited [Window3DController ApplyCLUTString] should not be called");
}

- (void) ApplyOpacityString: (NSString*) str
{
//	Override.
	NSLog(@"Error: inherited [Window3DController ApplyOpacityString] should not be called");
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) deleteCLUT: (NSWindow*) sheet returnCode: (int) returnCode contextInfo: (void*) contextInfo
{
    if (returnCode==1)
    {
		NSMutableDictionary *clutDict	= [[[[NSUserDefaults standardUserDefaults] dictionaryForKey: @"CLUT"] mutableCopy] autorelease];
		[clutDict removeObjectForKey: (id) contextInfo];
		[[NSUserDefaults standardUserDefaults] setObject: clutDict forKey: @"CLUT"];

		[[NSNotificationCenter defaultCenter] postNotificationName: @"UpdateCLUTMenu" object: curCLUTMenu userInfo: 0L];
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) UpdateCLUTMenu: (NSNotification*) note
{
    //*** Build the menu
    short							i;
    NSArray							*keys;
    NSArray							*sortedKeys;

    // Presets VIEWER Menu
	
	keys = [[[NSUserDefaults standardUserDefaults] dictionaryForKey: @"CLUT"] allKeys];
    sortedKeys = [keys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	
    i = [[clutPopup menu] numberOfItems];
    while(i-- > 0) [[clutPopup menu] removeItemAtIndex:0];
	
	[[clutPopup menu] addItemWithTitle:NSLocalizedString(@"No CLUT", nil) action:nil keyEquivalent:@""];
    [[clutPopup menu] addItemWithTitle:NSLocalizedString(@"No CLUT", nil) action:@selector (ApplyCLUT:) keyEquivalent:@""];
	[[clutPopup menu] addItem: [NSMenuItem separatorItem]];
	
    for( i = 0; i < [sortedKeys count]; i++)
    {
        [[clutPopup menu] addItemWithTitle:[sortedKeys objectAtIndex:i] action:@selector (ApplyCLUT:) keyEquivalent:@""];
    }
    [[clutPopup menu] addItem: [NSMenuItem separatorItem]];
    [[clutPopup menu] addItemWithTitle:NSLocalizedString(@"8-bit CLUT Editor", nil) action:@selector (AddCLUT:) keyEquivalent:@""];

	[[[clutPopup menu] itemAtIndex:0] setTitle:curCLUTMenu];
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) CLUTChanged: (NSNotification*) note
{
	unsigned char   r[256], g[256], b[256];

	
	[[note object] ConvertCLUT: r : g : b];
	[[self view] setCLUT: r : g : b];
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (NSPopUpButton*) clutPopup
{
	return clutPopup;
}


//====================================================================================================================================================================================================================
#pragma mark-
#pragma mark Common Opacity Functions


- (void) ApplyOpacity: (id) sender
{
    if ([[[NSApplication sharedApplication] currentEvent] modifierFlags]  & NSShiftKeyMask)
    {
        NSBeginAlertSheet(NSLocalizedString(@"Remove an Opacity Table",nil), NSLocalizedString(@"Delete",nil), NSLocalizedString(@"Cancel", nil), nil, [self window], self, @selector(deleteOpacity:returnCode:contextInfo:), NULL, [sender title],
		  [NSString stringWithFormat: NSLocalizedString(@"Are you sure you want to delete this Opacity Table : '%@'?", Nil), [sender title]]);
		[[NSNotificationCenter defaultCenter] postNotificationName: @"UpdateOpacityMenu" object: curOpacityMenu userInfo: 0L];
	}
	else if ([[[NSApplication sharedApplication] currentEvent] modifierFlags]  & NSAlternateKeyMask)
    {
		NSDictionary		*aOpacity, *aCLUT;
		NSArray				*array;
		long				i;
		unsigned char		red[256], green[256], blue[256];
		
		[self ApplyOpacityString: [sender title]];
		
		aOpacity = [[[NSUserDefaults standardUserDefaults] dictionaryForKey: @"OPACITY"] objectForKey: curOpacityMenu];
		if( aOpacity)
		{
			aCLUT = [[[NSUserDefaults standardUserDefaults] dictionaryForKey: @"CLUT"] objectForKey: curCLUTMenu];
			if( aCLUT)
			{
				array = [aCLUT objectForKey:@"Red"];
				for( i = 0; i < 256; i++)
				{
					red[i] = [[array objectAtIndex: i] longValue];
				}
				
				array = [aCLUT objectForKey:@"Green"];
				for( i = 0; i < 256; i++)
				{
					green[i] = [[array objectAtIndex: i] longValue];
				}
				
				array = [aCLUT objectForKey:@"Blue"];
				for( i = 0; i < 256; i++)
				{
					blue[i] = [[array objectAtIndex: i] longValue];
				}
				
				[OpacityView setCurrentCLUT:red :green: blue];
			}
	
			if( [aOpacity objectForKey:@"Points"] != 0L)
			{
				[OpacityName setStringValue: curOpacityMenu];
				
				NSMutableArray	*pts = [OpacityView getPoints];
				
				[pts removeAllObjects];
				
				[pts addObjectsFromArray: [aOpacity objectForKey:@"Points"]];
				
				[NSApp beginSheet: addOpacityWindow modalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
				
				[OpacityView setNeedsDisplay:YES];
			}
		}
	}
    else
    {
		[self ApplyOpacityString:[sender title]];
    }
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (IBAction) endOpacity: (id) sender
{
    [addOpacityWindow orderOut: sender];
    
    [NSApp endSheet: addOpacityWindow returnCode: [sender tag]];
    
    if ([sender tag])						//User clicks OK Button
    {
		NSMutableDictionary		*opacityDict		= [[[[NSUserDefaults standardUserDefaults] dictionaryForKey: @"OPACITY"] mutableCopy] autorelease];
		NSMutableDictionary		*aOpacityFilter		= [NSMutableDictionary dictionary];
		NSArray					*points;
		long					i;
		
		[aOpacityFilter setObject: [[[OpacityView getPoints] copy] autorelease] forKey: @"Points"];
		[opacityDict setObject: aOpacityFilter forKey: [OpacityName stringValue]];
		[[NSUserDefaults standardUserDefaults] setObject: opacityDict forKey: @"OPACITY"];
		
		// Apply it!
		
		[self ApplyOpacityString: [OpacityName stringValue]];
        [[NSNotificationCenter defaultCenter] postNotificationName: @"UpdateOpacityMenu" object: curOpacityMenu userInfo: 0L];
    }
	else
	{
		[self ApplyOpacityString: curOpacityMenu];
	}
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) deleteOpacity: (NSWindow*) sheet returnCode: (int) returnCode contextInfo: (void*) contextInfo
{
    if (returnCode == 1)
    {
		NSMutableDictionary *opacityDict = [[[[NSUserDefaults standardUserDefaults] dictionaryForKey: @"OPACITY"] mutableCopy] autorelease];
		[opacityDict removeObjectForKey: (id) contextInfo];
		[[NSUserDefaults standardUserDefaults] setObject: opacityDict forKey: @"OPACITY"];
        
		[[NSNotificationCenter defaultCenter] postNotificationName: @"UpdateOpacityMenu" object: curOpacityMenu userInfo: 0L];
    }
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (NSPopUpButton*) OpacityPopup
{
	return OpacityPopup;
}


//====================================================================================================================================================================================================================
#pragma mark-
#pragma mark Common Full Screen Functions

- (void) offFullScreen
{
	if (FullScreenOn)
		[self fullScreenMenu: self];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

- (IBAction) fullScreenMenu: (id) sender
{
    if( FullScreenOn == YES )									// we need to go back to non-full screen
    {
        [StartingWindow setContentView: contentView];
//		[FullScreenWindow setContentView: nil];
    
        [FullScreenWindow setDelegate:nil];
        [FullScreenWindow close];
        [FullScreenWindow release];
        
//		[contentView release];
        
        [StartingWindow makeKeyAndOrderFront: self];
//		[StartingWindow makeFirstResponder: self];
        FullScreenOn = NO;
    }
    else														// FullScreenOn == NO
    {
        unsigned int windowStyle;
        NSRect       contentRect;
        
        
        StartingWindow = [self window];
        windowStyle    = NSBorderlessWindowMask; 
        contentRect    = [[NSScreen mainScreen] frame];
        FullScreenWindow = [[NSFullScreenWindow alloc] initWithContentRect:contentRect styleMask: windowStyle backing:NSBackingStoreBuffered defer: NO];
        if(FullScreenWindow != nil)
        {
            NSLog(@"Window was created");			
            [FullScreenWindow setTitle: @"myWindow"];			
            [FullScreenWindow setReleasedWhenClosed: NO];
            [FullScreenWindow setLevel: NSScreenSaverWindowLevel - 1];
            [FullScreenWindow setBackgroundColor:[NSColor blackColor]];
            
            
            
            contentView = [[self window] contentView];
            [FullScreenWindow setContentView: contentView];
            
            [FullScreenWindow makeKeyAndOrderFront: self];
            [FullScreenWindow makeFirstResponder: [self view]];
            
            [FullScreenWindow setDelegate: self];
            [FullScreenWindow setWindowController: self];
            
            FullScreenOn = YES;
        }
    }
}



@end
