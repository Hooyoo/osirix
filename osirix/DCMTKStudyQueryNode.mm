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


#import "DCMTKStudyQueryNode.h"
#import <OsiriX/DCMCalendarDate.h>
#import "DCMTKSeriesQueryNode.h"
#import "DICOMToNSString.h"

#undef verify
#include "dcdeftag.h"


@implementation DCMTKStudyQueryNode

+ (id)queryNodeWithDataset:(DcmDataset *)dataset
						callingAET:(NSString *)myAET  
						calledAET:(NSString *)theirAET  
						hostname:(NSString *)hostname 
						port:(int)port 
						transferSyntax:(int)transferSyntax
						compression: (float)compression
						extraParameters:(NSDictionary *)extraParameters{
	return [[[DCMTKStudyQueryNode alloc] initWithDataset:(DcmDataset *)dataset
									callingAET:(NSString *)myAET  
									calledAET:(NSString *)theirAET  
									hostname:(NSString *)hostname 
									port:(int)port 
									transferSyntax:(int)transferSyntax
									compression: (float)compression
									extraParameters:(NSDictionary *)extraParameters] autorelease];
}

- (id)initWithDataset:(DcmDataset *)dataset
									callingAET:(NSString *)myAET  
									calledAET:(NSString *)theirAET  
									hostname:(NSString *)hostname 
									port:(int)port 
									transferSyntax:(int)transferSyntax
									compression: (float)compression
									extraParameters:(NSDictionary *)extraParameters{
	if (self = [super initWithDataset:(DcmDataset *)dataset
									callingAET:(NSString *)myAET  
									calledAET:(NSString *)theirAET  
									hostname:(NSString *)hostname 
									port:(int)port 
									transferSyntax:(int)transferSyntax
									compression: (float)compression
									extraParameters:(NSDictionary *)extraParameters]) {
		
		const char *string = nil;
		
//		dataset ->print( COUT);
		
		if (dataset ->findAndGetString(DCM_SpecificCharacterSet, string).good() && string != nil)
			_specificCharacterSet = [[NSString alloc] initWithCString:string encoding:NSISOLatin1StringEncoding];
		
		if (dataset ->findAndGetString(DCM_StudyInstanceUID, string).good() && string != nil) 
			_uid = [[NSString alloc] initWithCString:string encoding:NSISOLatin1StringEncoding];
			
		if (dataset ->findAndGetString(DCM_StudyDescription, string).good() && string != nil) 
			_theDescription = [[NSString alloc] initWithCString:string  DICOMEncoding:_specificCharacterSet];
			
		if (dataset ->findAndGetString(DCM_PatientsName, string).good() && string != nil)	
			_name =  [[NSString alloc] initWithCString:string  DICOMEncoding:_specificCharacterSet];
		
		if (dataset ->findAndGetString(DCM_PatientID, string).good() && string != nil)		
			_patientID = [[NSString alloc] initWithCString:string  DICOMEncoding:_specificCharacterSet];
			
		if (dataset ->findAndGetString(DCM_AccessionNumber, string).good() && string != nil)		
			_accessionNumber = [[NSString alloc] initWithCString:string  DICOMEncoding:_specificCharacterSet];
		
		if (dataset ->findAndGetString(DCM_PatientsBirthDate, string).good() && string != nil) {
			NSString *dateString = [[NSString alloc] initWithCString:string encoding:NSISOLatin1StringEncoding];
			_birthdate = [[DCMCalendarDate dicomDate:dateString] retain];
			[dateString release];
		}

		if (dataset ->findAndGetString(DCM_StudyDate, string).good() && string != nil) {
			NSString *dateString = [[NSString alloc] initWithCString:string encoding:NSISOLatin1StringEncoding];
			_date = [[DCMCalendarDate dicomDate:dateString] retain];
			[dateString release];
		}
		
		if (dataset ->findAndGetString(DCM_StudyTime, string).good() && string != nil) {
			NSString *dateString = [[NSString alloc] initWithCString:string encoding:NSISOLatin1StringEncoding];
			_time = [[DCMCalendarDate dicomTime:dateString] retain];
			[dateString release];
		}
		

		if (dataset ->findAndGetString(DCM_ModalitiesInStudy, string).good() && string != nil)	{
			_modality = [[NSString alloc] initWithCString:string encoding:NSISOLatin1StringEncoding];
		}
		else
		{
			if (dataset ->findAndGetString(DCM_Modality, string).good() && string != nil)	{
			_modality = [[NSString alloc] initWithCString:string encoding:NSISOLatin1StringEncoding];
			}
			/*
			else {
				// look for modality at the Series level and get modalities from children
				//This has not been tested yet LWP
				[self queryWithValues:nil];
				NSMutableSet *modalitiesInStudy = [NSMutableSet set];
				NSEnumerator *enumerator = [_children  objectEnumerator];
				DCMTKSeriesQueryNode * child;
				while (child = [enumerator nextObject]) {
					if ([child modality])
						[modalitiesInStudy addObject:[child modality]];
				}
				_modality = [[[modalitiesInStudy allObjects] componentsJoinedByString:@"/"] retain];
			}
			*/
		}
		
		if (dataset ->findAndGetString(DCM_NumberOfStudyRelatedInstances, string).good() && string != nil)
		{
			NSString	*numberString = [[NSString alloc] initWithCString:string encoding:NSISOLatin1StringEncoding];
			_numberImages = [[NSNumber numberWithInt: [numberString intValue]] retain];
			[numberString release];
		}
//		else if (dataset ->findAndGetString(DCM_ImageGroupLength, string).good() && string != nil)
//		{
//			NSString	*numberString = [[NSString alloc] initWithCString:string encoding:NSISOLatin1StringEncoding];
//			_numberImages = [[NSNumber numberWithInt: [numberString intValue]] retain];
//			[numberString release];
//		}
	}
	return self;
}

- (DcmDataset *)queryPrototype{
	DcmDataset *dataset = new DcmDataset();
	dataset-> insertEmptyElement(DCM_SeriesDescription, OFTrue);
	dataset-> insertEmptyElement(DCM_SeriesDate, OFTrue);
	dataset-> insertEmptyElement(DCM_SeriesTime, OFTrue);
	dataset-> insertEmptyElement(DCM_StudyInstanceUID, OFTrue);
	dataset-> insertEmptyElement(DCM_SeriesInstanceUID, OFTrue);
	dataset-> insertEmptyElement(DCM_SeriesNumber, OFTrue);
	dataset-> insertEmptyElement(DCM_NumberOfSeriesRelatedInstances, OFTrue);
	dataset-> insertEmptyElement(DCM_Modality, OFTrue);
	dataset-> putAndInsertString(DCM_StudyInstanceUID, [_uid UTF8String], OFTrue);
	dataset-> putAndInsertString(DCM_QueryRetrieveLevel, "SERIES", OFTrue);
	
	return dataset;
	
}

- (DcmDataset *)moveDataset{
	DcmDataset *dataset = new DcmDataset();
	dataset-> putAndInsertString(DCM_StudyInstanceUID, [_uid UTF8String], OFTrue);
	dataset-> putAndInsertString(DCM_QueryRetrieveLevel, "STUDY", OFTrue);
	return dataset;
}


- (void)addChild:(DcmDataset *)dataset{
	if (!_children)
		_children = [[NSMutableArray alloc] init];
	[_children addObject:[DCMTKSeriesQueryNode queryNodeWithDataset:dataset
			callingAET:_callingAET  
			calledAET:_calledAET
			hostname:_hostname 
			port:_port 
			transferSyntax:_transferSyntax
			compression: _compression
			extraParameters:_extraParameters]];
}

@end
