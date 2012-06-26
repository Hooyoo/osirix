/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - LGPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

#import "WebPortalUser.h"
#import "WebPortalStudy.h"
#import "WebPortalDatabase.h"
#import "DicomDatabase.h"
#import "PSGenerator.h"
#import "WebPortal.h"
#import "AppController.h"
#import "NSError+OsiriX.h"
#import "DDData.h"
#import "NSData+N2.h"
#import "DicomStudy.h"

static PSGenerator *generator = nil;
static NSMutableDictionary *studiesForUserCache = nil;

@implementation WebPortalUser

@dynamic address;
@dynamic autoDelete;
@dynamic canAccessPatientsOtherStudies;
@dynamic canSeeAlbums;
@dynamic creationDate;
@dynamic deletionDate;
@dynamic downloadZIP;
@dynamic email;
@dynamic emailNotification;
@dynamic encryptedZIP;
@dynamic isAdmin;
@dynamic name;
@dynamic password;
@dynamic passwordHash;
@dynamic passwordCreationDate;
@dynamic phone;
@dynamic sendDICOMtoAnyNodes;
@dynamic sendDICOMtoSelfIP;
@dynamic shareStudyWithUser;
@dynamic createTemporaryUser;
@dynamic studyPredicate;
@dynamic uploadDICOM;
@dynamic downloadReport;
@dynamic uploadDICOMAddToSpecificStudies;
@dynamic studies;

- (void) generatePassword
{
	if( generator == nil)
		generator = [[PSGenerator alloc] initWithSourceString: @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" minLength: 12 maxLength: 12];
	
	[self setValue: [[generator generate: 1] lastObject] forKey: @"password"];
}

- (NSString*) email
{
	if( [self primitiveValueForKey: @"email"] == nil)
		return @"";
	
	return [self primitiveValueForKey: @"email"];
}

- (NSString*) phone
{
	if( [self primitiveValueForKey: @"phone"] == nil)
		return @"";
	
	return [self primitiveValueForKey: @"phone"];
}

- (NSString*) address
{
	if( [self primitiveValueForKey: @"address"] == nil)
		return @"";
	
	return [self primitiveValueForKey: @"address"];
}

- (void) awakeFromInsert
{
	[super awakeFromInsert];
	
	if( [self primitiveValueForKey: @"passwordCreationDate"] == nil)
		[self setPrimitiveValue: [NSDate date] forKey: @"passwordCreationDate"];
	
	if( [self primitiveValueForKey: @"creationDate"] == nil)
		[self setPrimitiveValue: [NSDate date] forKey: @"creationDate"];
	
	if( [self primitiveValueForKey: @"dateAdded"] == nil)
		[self setPrimitiveValue: [NSDate date] forKey: @"dateAdded"];

	if( [self primitiveValueForKey: @"studyPredicate"] == nil)
		[self setPrimitiveValue: @"(YES == NO)" forKey: @"studyPredicate"];
	
	[self generatePassword];

	// Create a unique name
	unsigned long long uid = 100. * [NSDate timeIntervalSinceReferenceDate];
	[self setPrimitiveValue: [NSString stringWithFormat: @"user %llu", uid] forKey: @"name"];
}


- (void) setAutoDelete: (NSNumber*) v
{
	if( [v boolValue])
	{
		[self setValue: [NSDate dateWithTimeIntervalSinceReferenceDate: [NSDate timeIntervalSinceReferenceDate] + [[NSUserDefaults standardUserDefaults] integerForKey: @"temporaryUserDuration"] * 60L*60L*24L] forKey: @"deletionDate"];
	}
	
	[self setPrimitiveValue: v forKey: @"autoDelete"];
}

- (void) setName: (NSString*) newName
{
    if( [newName isEqualToString: self.name] == NO)
    {
        if( [self.password length] > 0 && [self.password isEqualToString: HASHPASSWORD] == NO)
        {
            
        }
        else
        {
            NSLog( @"------- WebPortalUser : name changed -> password reset");
            [self generatePassword];
            
            [[NSNotificationCenter defaultCenter] postNotificationName: @"WebPortalUsernameChanged" object: self];
        }
        
        [self willChangeValueForKey: @"name"];
        [self setPrimitiveValue: newName forKey: @"name"];
        [self didChangeValueForKey: @"name"];
    }
}

- (void) setPassword: (NSString*) newPassword
{
	if( [newPassword length] >= 4 && [newPassword isEqualToString: HASHPASSWORD] == NO)
	{
		[self setValue: [NSDate date] forKey: @"passwordCreationDate"];
        
        [self willChangeValueForKey: @"password"];
        [self setPrimitiveValue: newPassword forKey: @"password"];
        [self didChangeValueForKey: @"password"];
        
        [self setPrimitiveValue: @"" forKey: @"passwordHash"];
        [self setPrimitiveValue: [NSDate date] forKey: @"passwordCreationDate"];
    }
}

- (void) convertPasswordToHashIfNeeded
{
    if( [self.password length] > 0 && [self.password isEqualToString: HASHPASSWORD] == NO) // We dont want to store password, only sha1Digest version ! 
    {
        self.passwordHash = [[[[self.password stringByAppendingString: self.name] dataUsingEncoding:NSUTF8StringEncoding] sha1Digest] hex];
        
        [self willChangeValueForKey: @"password"];
        [self setPrimitiveValue: HASHPASSWORD forKey: @"password"];
        [self didChangeValueForKey: @"password"];
        
        NSLog( @"---- Convert password to hash string. Delete original password for user: %@", self.name);
    }
}

-(BOOL)validatePassword:(NSString**)value error:(NSError**)error
{
    NSString *password2validate = *value;
    
    if( [password2validate isEqualToString: HASHPASSWORD] == NO)
    {
        if( [[password2validate stringByReplacingOccurrencesOfString: @"*" withString: @""] length] == 0)
        {
            if (error) *error = [NSError osirixErrorWithCode:-31 localizedDescription:NSLocalizedString( @"Password cannot contain only '*' characters.", NULL)];
            return NO;
        }
	    
        if( [password2validate length] < 4)
        {
            if (error) *error = [NSError osirixErrorWithCode:-31 localizedDescription:NSLocalizedString( @"Password needs to be at least 4 characters long.", NULL)];
            return NO;
        }
        
        if( [password2validate stringByTrimmingCharactersInSet: [NSCharacterSet decimalDigitCharacterSet]].length == 0)
        {
            if (error) *error = [NSError osirixErrorWithCode:-31 localizedDescription:NSLocalizedString( @"Password cannot contain only numbers: add letters.", NULL)];
            return NO;
        }
        
        if( [password2validate stringByReplacingOccurrencesOfString: [password2validate substringToIndex: 1] withString: @""].length == 0)
        {
            if (error) *error = [NSError osirixErrorWithCode:-31 localizedDescription:NSLocalizedString( @"Password cannot contain only the same character.", NULL)];
            return NO;
        }
        
        NSUInteger invidualCharacters = 0;
        NSMutableArray *array = [NSMutableArray array];
        for( int i = 0; i < [password2validate length]; i++)
        {
            NSString *character = [password2validate substringWithRange: NSMakeRange( i, 1)];
            if( [array containsObject: character] == NO)
            {
                invidualCharacters++;
                [array addObject: character];
            }
        }
        
        if( invidualCharacters < 3)
        {
            if (error) *error = [NSError osirixErrorWithCode:-31 localizedDescription:NSLocalizedString( @"Password needs to have at least 3 different characters.", NULL)];
            return NO;
        }
        
    }
	
	return YES;
}

-(BOOL)validateDownloadZIP:(NSNumber**)value error:(NSError**)error {
	if ([*value boolValue] && !AppController.hasMacOSXSnowLeopard) {
		if (error) *error = [NSError osirixErrorWithCode:-31 localizedDescription:NSLocalizedString(@"ZIP download requires MacOS 10.6 or higher.", NULL)];
		return NO;
	}
	
	return YES;
}

-(BOOL)validateName:(NSString**)value error:(NSError**)error {
	if ([*value length] < 2) {
		if (error) *error = [NSError osirixErrorWithCode:-31 localizedDescription:NSLocalizedString(@"Name needs to be at least 2 characters long.", NULL)];
		return NO;
	}
	
	[self.managedObjectContext lock];
	@try {
		NSError* err = NULL;
		NSFetchRequest* request = [[[NSFetchRequest alloc] init] autorelease];
		request.entity = [NSEntityDescription entityForName:@"User" inManagedObjectContext:self.managedObjectContext];
		request.predicate = [NSPredicate predicateWithFormat:@"name == %@", *value];
		NSArray* users = [self.managedObjectContext executeFetchRequest:request error:&err];
		if (err) [NSException exceptionWithName:NSGenericException reason:@"Database error." userInfo:[NSDictionary dictionaryWithObject:err forKey:NSUnderlyingErrorKey]];
		
		if ((users.count == 1 && users.lastObject != self) || users.count > 1) {
			if (error) *error = [NSError osirixErrorWithCode:-31 localizedDescription:NSLocalizedString(@"A user with that name already exists. Two users cannot have the same name.", NULL)];
			return NO;
		}
	} @catch (NSException* e) {
		NSLog(@"*** [WebPortalUser validateName:error:] exception: %@", e);
		NSDictionary* info = [NSDictionary dictionaryWithObject:NSLocalizedString(@"Internal database error.", NULL) forKey:NSLocalizedDescriptionKey];
		if (error) *error = [NSError errorWithDomain:@"OsiriXDomain" code:-31 userInfo:info];
		return NO;
	} @finally {
		[self.managedObjectContext unlock];
	}

	return YES;
}

-(BOOL)validateStudyPredicate:(NSString**)value error:(NSError**)error {
	@try {
		NSFetchRequest* request = [[[NSFetchRequest alloc] init] autorelease];
		request.entity = [NSEntityDescription entityForName:@"Study" inManagedObjectContext:self.managedObjectContext];
		request.predicate = [DicomDatabase predicateForSmartAlbumFilter:*value];
		
		NSError* e = NULL;
		[WebPortal.defaultWebPortal.dicomDatabase.managedObjectContext executeFetchRequest:request error:&e];
		if (e) {
			if (error) *error = [NSError osirixErrorWithCode:-31 localizedDescriptionFormat:NSLocalizedString(@"Syntax error in study predicate filter: %@", NULL), e.localizedDescription? e.localizedDescription : NSLocalizedString(@"Unknown Error", NULL)];
			return NO;
		}
	} @catch (NSException* e) {
		NSLog(@"*** [WebPortalUser validateStudyPredicate:error:] exception: %@", e);
		*error = [NSError osirixErrorWithCode:-31 localizedDescription:[NSString stringWithFormat:NSLocalizedString(@"Error: %@", nil), e]];
		return NO;
	}
	
	return YES;
}

-(NSArray*)arrayByAddingSpecificStudiesToArray:(NSArray*)array
{
	NSMutableArray *specificArray = nil;
	
    if( array == nil)
        array = [NSArray array];
    
	@try
	{
		NSArray* userStudies = self.studies.allObjects;
		
		if( userStudies.count == 0)
			return array;
        
        NSString *userID = [self.name stringByAppendingString: @" specificStudies"];
        
        @synchronized( studiesForUserCache)
        {
            if( [studiesForUserCache objectForKey: userID] && [[[studiesForUserCache objectForKey: userID] objectForKey: @"date"] timeIntervalSinceNow] > -60*60) // one hour
            {
                specificArray = [[studiesForUserCache objectForKey: userID] objectForKey: @"array"];
            }
        }
        
        if( specificArray == nil)
        {
            NSArray* studiesArray = nil;
            
            @synchronized( studiesForUserCache)
            {
                if( [studiesForUserCache objectForKey: @"all DB studies"] && [[[studiesForUserCache objectForKey: @"all DB studies"] objectForKey: @"date"] timeIntervalSinceNow] > -60*60)
                    studiesArray = [[studiesForUserCache objectForKey: @"all DB studies"] objectForKey: @"array"];
            }
            
            if( studiesArray == nil)
            {
                // Find all studies
                NSFetchRequest* req = [[[NSFetchRequest alloc] init] autorelease];
                req.entity = [NSEntityDescription entityForName: @"Study" inManagedObjectContext:WebPortal.defaultWebPortal.dicomDatabase.managedObjectContext];
                req.predicate = [NSPredicate predicateWithValue: YES];
                studiesArray = [WebPortal.defaultWebPortal.dicomDatabase.managedObjectContext executeFetchRequest:req error:NULL];
                
                @synchronized( studiesForUserCache)
                {
                    if( studiesArray)
                        [studiesForUserCache setObject: [NSDictionary dictionaryWithObjectsAndKeys: studiesArray, @"array", [NSDate date], @"date", nil] forKey: @"all DB studies"];
                }
            }
            
            specificArray = [NSMutableArray array];
            
            for (WebPortalStudy* study in userStudies)
            {
                NSArray *obj = nil;
                
                if (self.canAccessPatientsOtherStudies.boolValue)
                    obj = [studiesArray filteredArrayUsingPredicate: [NSPredicate predicateWithFormat: @"patientUID == %@", study.patientUID]];
                else
                    obj = [studiesArray filteredArrayUsingPredicate: [NSPredicate predicateWithFormat: @"patientUID == %@ AND studyInstanceUID == %@", study.patientUID, study.studyInstanceUID]];
                
                if ([obj count] >= 1)
                {
                    for( id o in obj)
                    {
                        if ([array containsObject: o] == NO && [specificArray containsObject: o] == NO)
                            [specificArray addObject: o];
                    }
                }
                else if ([obj count] == 0)
                {
                    // It means this study doesnt exist in the entire DB -> remove it from this user list
                    NSLog( @"This study is not longer available in the DB -> delete it : %@", [study valueForKey: @"patientUID"]);
                    [self.managedObjectContext deleteObject:study];
                }
            }
            
            @synchronized( studiesForUserCache)
            {
                [studiesForUserCache setObject: [NSDictionary dictionaryWithObjectsAndKeys: specificArray, @"array", [NSDate date], @"date", nil] forKey: userID];
            }
        }
	}
	@catch (NSException * e)
	{
		NSLog( @"********** addSpecificStudiesToArray : %@", e);
	}
	
	for (id study in array)
		if (![specificArray containsObject:study])
			[specificArray addObject:study];
	
	return specificArray;
}

-(NSArray*)studiesForPredicate:(NSPredicate*)predicate
{
	return [self studiesForPredicate:predicate sortBy:NULL];
}

-(NSArray*)studiesForPredicate:(NSPredicate*)predicate sortBy:(NSString*)sortValue
{
	return [self studiesForPredicate: predicate sortBy: sortValue fetchLimit: 0 fetchOffset: 0 numberOfStudies: nil];
}

-(NSArray*)studiesForPredicate:(NSPredicate*)predicate sortBy:(NSString*)sortValue fetchLimit:(int) fetchLimit fetchOffset:(int) fetchOffset numberOfStudies:(int*) numberOfStudies
{
    return [WebPortalUser studiesForUser: self predicate: predicate sortBy: sortValue fetchLimit: fetchLimit fetchOffset: fetchOffset numberOfStudies: numberOfStudies];
}

+(NSArray*)studiesForUser: (WebPortalUser*) user predicate:(NSPredicate*)predicate;
{
    return [WebPortalUser studiesForUser: user predicate: predicate sortBy: nil fetchLimit: 0 fetchOffset: 0 numberOfStudies: nil];
}

+(NSArray*)studiesForUser: (WebPortalUser*) user predicate:(NSPredicate*)predicate sortBy:(NSString*)sortValue;
{
    return [WebPortalUser studiesForUser: user predicate: predicate sortBy: sortValue fetchLimit: 0 fetchOffset: 0 numberOfStudies: nil];
}

+(NSArray*)studiesForUser: (WebPortalUser*) user predicate:(NSPredicate*)predicate sortBy:(NSString*)sortValue fetchLimit:(int) fetchLimit fetchOffset:(int) fetchOffset numberOfStudies:(int*) numberOfStudies
{
	NSArray* studiesArray = nil;
	
	[WebPortal.defaultWebPortal.dicomDatabase.managedObjectContext lock];
	
	@try
	{
		NSFetchRequest* req = [[[NSFetchRequest alloc] init] autorelease];
		req.entity = [NSEntityDescription entityForName:@"Study" inManagedObjectContext:WebPortal.defaultWebPortal.dicomDatabase.managedObjectContext];
		
		BOOL allStudies = NO;
		if( user.studyPredicate.length == 0)
			allStudies = YES;
		
		if( allStudies == NO)
		{
            req.predicate = [DicomDatabase predicateForSmartAlbumFilter: user.studyPredicate];
			
            if( studiesForUserCache == nil && user)
            {
                studiesForUserCache = [[NSMutableDictionary alloc] init];
                [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(managedObjectChangedNotificationReceived:) name: NSManagedObjectContextObjectsDidChangeNotification object: nil];
            }
            
            NSString *userID = user.name;
            
            @synchronized( studiesForUserCache)
            {
                if( user && [studiesForUserCache objectForKey: userID] && [[[studiesForUserCache objectForKey: userID] objectForKey: @"date"] timeIntervalSinceNow] > -60*60)
                    studiesArray = [[studiesForUserCache objectForKey: userID] objectForKey: @"array"];
            }
            
            if( studiesArray == nil)
            {
                studiesArray = [WebPortal.defaultWebPortal.dicomDatabase.managedObjectContext executeFetchRequest:req error:NULL];
                
                @synchronized( studiesForUserCache)
                {
                    if( studiesArray)
                        [studiesForUserCache setObject: [NSDictionary dictionaryWithObjectsAndKeys: studiesArray, @"array", [NSDate date], @"date", nil] forKey: userID];
                }
            }
            
            if( user && user.studyPredicate.length > 0)
				studiesArray = [user arrayByAddingSpecificStudiesToArray: studiesArray];
            
            if( predicate)
                studiesArray = [studiesArray filteredArrayUsingPredicate: predicate];
            
			if( user.canAccessPatientsOtherStudies.boolValue)
			{
				NSFetchRequest* req = [[NSFetchRequest alloc] init];
				req.entity = [NSEntityDescription entityForName:@"Study" inManagedObjectContext:WebPortal.defaultWebPortal.dicomDatabase.managedObjectContext];
				req.predicate = [NSPredicate predicateWithFormat:@"patientID IN %@", [studiesArray valueForKey:@"patientID"]];
				
				int previousStudiesArrayCount = studiesArray.count;
				
				studiesArray = [WebPortal.defaultWebPortal.dicomDatabase.managedObjectContext executeFetchRequest:req error:NULL];
				
				if( predicate && studiesArray.count != previousStudiesArrayCount)
					studiesArray = [studiesArray filteredArrayUsingPredicate: predicate];
				
				[req release];
			}
		}
		else
		{
			if( predicate == nil)
				predicate = [NSPredicate predicateWithValue: YES];
			
			req.predicate = predicate;
			
			studiesArray = [WebPortal.defaultWebPortal.dicomDatabase.managedObjectContext executeFetchRequest:req error:NULL];
		}
        
        if( [sortValue length])
		{
			if( [sortValue rangeOfString: @"date"].location == NSNotFound)
				studiesArray = [studiesArray sortedArrayUsingDescriptors: [NSArray arrayWithObject: [NSSortDescriptor sortDescriptorWithKey: sortValue ascending: YES selector: @selector( caseInsensitiveCompare:)]]];
			else
				studiesArray = [studiesArray sortedArrayUsingDescriptors: [NSArray arrayWithObject: [NSSortDescriptor sortDescriptorWithKey: sortValue ascending: NO]]];
		}
        
		if( numberOfStudies)
			*numberOfStudies = studiesArray.count;
		
        if( fetchLimit)
        {
            NSRange range = NSMakeRange( fetchOffset, fetchLimit);
            
            if( range.location > studiesArray.count)
                range.location = studiesArray.count;
            
            if( range.location + range.length > studiesArray.count)
                range.length = studiesArray.count - range.location;
            
            studiesArray = [studiesArray subarrayWithRange: range];
        }
		
	} @catch(NSException* e) {
		NSLog(@"Error: [WebPortal studiesForUser:predicate:sortBy:] %@", e);
	} @finally {
		[WebPortal.defaultWebPortal.dicomDatabase.managedObjectContext unlock];
	}
	
	return studiesArray;
}

-(NSArray*)studiesForAlbum:(NSString*)albumName
{
	return [self studiesForAlbum:albumName sortBy:nil];
}

-(NSArray*)studiesForAlbum:(NSString*)albumName sortBy:(NSString*)sortValue
{
    return [self studiesForAlbum: albumName sortBy: sortValue fetchLimit: 0 fetchOffset: 0 numberOfStudies: nil];
}

-(NSArray*)studiesForAlbum:(NSString*)albumName sortBy:(NSString*)sortValue fetchLimit:(int) fetchLimit fetchOffset:(int) fetchOffset numberOfStudies:(int*) numberOfStudies
{
    return [WebPortalUser studiesForUser: self album: albumName sortBy: sortValue fetchLimit: fetchLimit fetchOffset: fetchOffset numberOfStudies: numberOfStudies];
}

+(NSArray*)studiesForUser: (WebPortalUser*) user album:(NSString*)albumName;
{
    return [WebPortalUser studiesForUser: user album: albumName sortBy: nil fetchLimit: 0 fetchOffset: 0 numberOfStudies: nil];
}

+(NSArray*)studiesForUser: (WebPortalUser*) user album:(NSString*)albumName sortBy:(NSString*)sortValue;
{
    return [WebPortalUser studiesForUser: user album: albumName sortBy: sortValue fetchLimit: 0 fetchOffset: 0 numberOfStudies: nil];
}

+ (void) managedObjectChangedNotificationReceived: (NSNotification*) n
{
    @synchronized( studiesForUserCache)
    {
        NSMutableSet *set = [NSMutableSet set];
        
        if( [n.userInfo objectForKey: NSInsertedObjectsKey])
            [set unionSet: [n.userInfo objectForKey: NSInsertedObjectsKey]];
        
        if( [n.userInfo objectForKey: NSDeletedObjectsKey])
            [set unionSet: [n.userInfo objectForKey: NSDeletedObjectsKey]];
        
        for( NSManagedObject *object in set)
        {
            if( [object isKindOfClass: [DicomStudy class]] || [object isKindOfClass: [WebPortalUser class]] || [object isKindOfClass: [WebPortalStudy class]])
            {
                [studiesForUserCache removeAllObjects];
                break;
            }
        }
    }
}

+(NSArray*)studiesForUser: (WebPortalUser*) user album:(NSString*)albumName sortBy:(NSString*)sortValue fetchLimit:(int) fetchLimit fetchOffset:(int) fetchOffset numberOfStudies:(int*) numberOfStudies
{
	
	NSArray *studiesArray = nil, *albumArray = nil;
	
    if( studiesForUserCache == nil && user)
    {
        studiesForUserCache = [[NSMutableDictionary alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(managedObjectChangedNotificationReceived:) name: NSManagedObjectContextObjectsDidChangeNotification object: nil];
    }
    
    NSString *userID = [user.name stringByAppendingFormat:@" %@", albumName];
    
    @synchronized( studiesForUserCache)
    {
        if( user && [studiesForUserCache objectForKey: userID] && [[[studiesForUserCache objectForKey: userID] objectForKey: @"date"] timeIntervalSinceNow] > -60*60)
        {
            studiesArray = [[studiesForUserCache objectForKey: userID] objectForKey: @"array"];
            
            if ([sortValue length] && [sortValue isEqualToString: @"date"] == NO)
                studiesArray = [studiesArray sortedArrayUsingDescriptors: [NSArray arrayWithObject: [[[NSSortDescriptor alloc] initWithKey: sortValue ascending: YES selector: @selector( caseInsensitiveCompare:)] autorelease]]];
            else
                studiesArray = [studiesArray sortedArrayUsingDescriptors: [NSArray arrayWithObject: [[[NSSortDescriptor alloc] initWithKey: @"date" ascending:NO] autorelease]]];
        }
    }
    
    studiesArray = nil;
    
    if( studiesArray == nil)
    {
        [WebPortal.defaultWebPortal.dicomDatabase.managedObjectContext lock];
        
        @try
        {
            NSFetchRequest* req = [[[NSFetchRequest alloc] init] autorelease];
            req.entity = [NSEntityDescription entityForName:@"Album" inManagedObjectContext:WebPortal.defaultWebPortal.dicomDatabase.managedObjectContext];
            req.predicate = [NSPredicate predicateWithFormat:@"name == %@", albumName];
            albumArray = [WebPortal.defaultWebPortal.dicomDatabase.managedObjectContext executeFetchRequest:req error:NULL];
        }
        @catch(NSException *e)
        {
            NSLog(@"******** studiesForAlbum exception: %@", e.description);
        }
        
        [WebPortal.defaultWebPortal.dicomDatabase.managedObjectContext unlock];
        
        NSManagedObject *album = [albumArray lastObject];
        
        if ([[album valueForKey:@"smartAlbum"] intValue] == 1)
        {
            studiesArray = [WebPortalUser studiesForUser: user predicate:[DicomDatabase predicateForSmartAlbumFilter:[album valueForKey:@"predicateString"]] sortBy:sortValue];
        }
        else
        {
            NSArray *originalAlbum = [[album valueForKey:@"studies"] allObjects];
            
            if( user.studyPredicate.length)
            {
                @try
                {
                    studiesArray = [originalAlbum filteredArrayUsingPredicate: [DicomDatabase predicateForSmartAlbumFilter: user.studyPredicate]];
                    
                    NSArray *specificArray = [user arrayByAddingSpecificStudiesToArray: nil];
                    
                    for ( NSManagedObject *specificStudy in specificArray)
                    {
                        if ([originalAlbum containsObject: specificStudy] == YES && [studiesArray containsObject: specificStudy] == NO)
                        {
                            studiesArray = [studiesArray arrayByAddingObject: specificStudy];						
                        }
                    }
                }
                @catch( NSException *e)
                {
                    NSLog( @"****** User Filter Error : %@", e);
                    NSLog( @"****** NO studies will be displayed.");
                    
                    studiesArray = nil;
                }
            }
            else studiesArray = originalAlbum;
            
            if ([sortValue length] && [sortValue isEqualToString: @"date"] == NO)
                studiesArray = [studiesArray sortedArrayUsingDescriptors: [NSArray arrayWithObject: [[[NSSortDescriptor alloc] initWithKey: sortValue ascending: YES selector: @selector( caseInsensitiveCompare:)] autorelease]]];
            else
                studiesArray = [studiesArray sortedArrayUsingDescriptors: [NSArray arrayWithObject: [[[NSSortDescriptor alloc] initWithKey: @"date" ascending:NO] autorelease]]];
        }
        
        @synchronized( studiesForUserCache)
        {
            if( studiesArray)
                [studiesForUserCache setObject: [NSDictionary dictionaryWithObjectsAndKeys: studiesArray, @"array", [NSDate date], @"date", nil] forKey: userID];
        }
    }
        
    if( numberOfStudies)
        *numberOfStudies = studiesArray.count;
    
    if( fetchLimit)
    {
        NSRange range = NSMakeRange( fetchOffset, fetchLimit);
        
        if( range.location > studiesArray.count)
            range.location = studiesArray.count;
        
        if( range.location + range.length > studiesArray.count)
            range.length = studiesArray.count - range.location;
        
        studiesArray = [studiesArray subarrayWithRange: range];
    }
    
	return studiesArray;
}


@end


