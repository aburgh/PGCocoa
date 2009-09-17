//
//  PGQueryDocument.h
//  PGCocoa
//
//  Created by Aaron Burghardt on 9/2/08.
//  Copyright 2008 No Company. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PGConnection;
@class PGResult;

@interface PGQueryDocument : NSDocument 
{
//	IBOutlet NSWindow *_window;
	IBOutlet NSWindow *connectPanel;
	IBOutlet NSTableView *tableView;
	
	IBOutlet NSObjectController *ownerController;
	
	NSString *_query;
	PGResult *_result;
	
	NSString *_username;
	NSString *_password;
	NSString *_hostname;
	NSString *_database;
	PGConnection *_connection;
}

- (IBAction)executeQuery:(id)sender;

- (IBAction)connect:(id)sender;
- (IBAction)cancel:(id)sender;

@end
