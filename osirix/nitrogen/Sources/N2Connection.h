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

#import <Cocoa/Cocoa.h>

extern NSString* const N2ConnectionStatusDidChangeNotification;

enum {
	N2ConnectionStatusClosed = 0,
	N2ConnectionStatusConnecting,
	N2ConnectionStatusOpening,
	N2ConnectionStatusOk
};
typedef	NSInteger N2ConnectionStatus;

@interface N2Connection : NSObject {
	NSString* _address;
	NSInteger _port;
	NSInputStream* _inputStream;
	NSOutputStream* _outputStream;
	NSMutableData *_inputBuffer, *_outputBuffer;
	//BOOL _hasBytesAvailable, _hasSpaceAvailable, _handleConnectionClose;
	NSUInteger _handleOpenCompleted, _maximumReadSizePerEvent;
	N2ConnectionStatus _status;
	BOOL _tlsFlag;
}

@property(readonly) NSString* address;
@property N2ConnectionStatus status;
@property NSUInteger maximumReadSizePerEvent;

// non-tls
+(NSData*)sendSynchronousRequest:(NSData*)request toAddress:(NSString*)address port:(NSInteger)port;
+(void)sendSynchronousRequest:(NSData*)request toAddress:(NSString*)address port:(NSInteger)port dataHandlerTarget:(id)target selector:(SEL)selector context:(void*)context; // -(NSInteger)connection:(N2Connection*)connection dummyDataHandler:(NSData*)data context:(void*)context
-(id)initWithAddress:(NSString*)address port:(NSInteger)port;
-(id)initWithAddress:(NSString*)address port:(NSInteger)port is:(NSInputStream*)is os:(NSOutputStream*)os;

// generic
+(NSData*)sendSynchronousRequest:(NSData*)request toAddress:(NSString*)address port:(NSInteger)port tls:(BOOL)tlsFlag;
+(void)sendSynchronousRequest:(NSData*)request toAddress:(NSString*)address port:(NSInteger)port tls:(BOOL)tlsFlag dataHandlerTarget:(id)target selector:(SEL)selector context:(void*)context; // -(NSInteger)connection:(N2Connection*)connection dummyDataHandler:(NSData*)data context:(void*)context
-(id)initWithAddress:(NSString*)address port:(NSInteger)port tls:(BOOL)tlsFlag;
-(id)initWithAddress:(NSString*)address port:(NSInteger)port tls:(BOOL)tlsFlag is:(NSInputStream*)is os:(NSOutputStream*)os;

-(void)reconnect;
-(void)close;
-(void)open; // declared for overloading only
-(void)invalidate; // TODO: why? release stuff?

-(void)startTLS;
-(BOOL)isSecure;

-(void)reconnectToAddress:(NSString*)address port:(NSInteger)port;

-(void)writeData:(NSData*)data;
-(void)handleData:(NSMutableData*)data; // overload on subclasses
-(NSInteger)availableSize;
-(NSData*)readData:(NSInteger)size;
-(NSInteger)readData:(NSInteger)size toBuffer:(void*)buffer;

-(void)connectionFinishedSendingData; // overload on subclasses

//+(BOOL)host:(NSString*)host1 isEqualToHost:(NSString*)host2;

@end


