//
//  DCMNAction.h
//  OsiriX
//
//  Created by Lance Pysher on 9/2/05.

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


#import <Cocoa/Cocoa.h>
#import "DCMCommandMessage.h"


@interface DCMNActionRequest : DCMCommandMessage {
	unsigned short actionType;
}

+ (id)nActionRequestWithSopClassUID:(NSString *)sopClassUID 
		sopInstanceUID:(NSString *)sopInstanceUID 
		actionTypeID:(unsigned short)actionTypeID
		hasDataset:(BOOL)hasDataset;

- (id)initWithSopClassUID:(NSString *)sopClassUID 
		sopInstanceUID:(NSString *)sopInstanceUID 
		actionTypeID:(unsigned short)actionTypeID
		hasDataset:(BOOL)hasDataset;

@end
