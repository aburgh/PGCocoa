//
//  PGQueryDocument.m
//  PGCocoa
//
//  Created by Aaron Burghardt on 9/2/08.
//  Copyright 2008 No Company. All rights reserved.
//

#import "PGQueryDocument.h"
#import <PGCocoa/PGCocoa.h>


@implementation PGQueryDocument

- (NSString *)windowNibName {
    // Implement this to return a nib to load OR implement -makeWindowControllers to manually create your controllers.
    return @"PGQueryDocument";
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to write your document to data of the specified type. If the given outError != NULL, ensure that you set *outError when returning nil.

    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.

    // For applications targeted for Panther or earlier systems, you should use the deprecated API -dataRepresentationOfType:. In this case you can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.

    return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to read your document from the given data of the specified type.  If the given outError != NULL, ensure that you set *outError when returning NO.

    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead. 
    
    // For applications targeted for Panther or earlier systems, you should use the deprecated API -loadDataRepresentation:ofType. In this case you can also choose to override -readFromFile:ofType: or -loadFileWrapperRepresentation:ofType: instead.
    
    return YES;
}

- (void)_openConnectPanel
{
	[NSApp beginSheet:connectPanel
	   modalForWindow:[self windowForSheet]
		modalDelegate:self 
	   didEndSelector:@selector(connectPanelDidEnd:returnCode:context:) 
		  contextInfo:NULL];
}	
- (void)awakeFromNib
{
	[self setValue:@"localhost" forKey:@"hostname"];
	[self setValue:NSUserName() forKey:@"username"];
	[self performSelector:@selector(_openConnectPanel) withObject:nil afterDelay:0.0];
}

- (IBAction)executeQuery:(id)sender;
{
	[ownerController commitEditing];
	
	PGResult *result = [_connection executeQuery:_query];
	if ([result status] == PGRES_TUPLES_OK) {
		[_result autorelease];
		_result = [result retain];
		[self _rebuildTableView];
	}
	else {
		[NSApp presentError:[result error]];
	}
}

- (void)connectPanelDidEnd:(NSPanel *)panel returnCode:(int)code context:(void *)ctx
{
	[panel orderOut:self];
	
	if (code == NSOKButton) {
		NSMutableDictionary *params = [NSMutableDictionary dictionary];
		if (_hostname) [params setObject:_hostname forKey:PGConnectionParameterHostKey];
		if (_database) [params setObject:_database forKey:PGConnectionParameterDatabaseNameKey];
		if (_username) [params setObject:_username forKey:PGConnectionParameterUsernameKey];
		if (_password) [params setObject:_password forKey:PGConnectionParameterPasswordKey];
		
		_connection = [[PGConnection alloc] initWithParameters:params];
		if (![_connection connect]) {
			[NSApp presentError:[_connection error]];
			[self awakeFromNib];
		}
	}
	else {
		[self close];		
	}
}

- (IBAction)connect:(id)sender;
{
	[NSApp endSheet:connectPanel returnCode:NSOKButton];	
}

- (IBAction)cancel:(id)sender;
{
	[NSApp endSheet:connectPanel returnCode:NSCancelButton];
}

#pragma mark TableView Data Source

- (void)_rebuildTableView;
{
	NSArray *headers = [_result fieldNames];

	// remove extra columns
	NSArray *oldColumns = [tableView tableColumns];
	for (int i = [headers count]; i < [oldColumns count]; i++)
		[tableView removeTableColumn:[oldColumns objectAtIndex:i]];

	NSTableColumn *col;
	
	for (int i = 0; i < [_result numberOfFields]; i++) {
		if (i < [oldColumns count]) {
			col = [oldColumns objectAtIndex:i];
			[col setIdentifier:[headers objectAtIndex:i]];
		}
		else {
			col = [[NSTableColumn alloc] initWithIdentifier:[headers objectAtIndex:i]];
			[tableView addTableColumn:col];
			[col release];
		}
		[[col headerCell] setStringValue:[headers objectAtIndex:i]];
	}


	[tableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
	return _result ? [_result numberOfRows] : 0;
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tc row:(int)rowIndex
{
    id value = nil;
	
    NSParameterAssert(rowIndex >= 0 && rowIndex < [_result numberOfRows]);
	
    NSInteger fieldNum = [[_result fieldNames] indexOfObject:[tc identifier]];
	
	if (fieldNum == NSNotFound)
		value = nil;
	else
		value = [_result valueAtRowIndex:rowIndex fieldIndex:fieldNum];

    return value;
}

- (void)dealloc
{
	[_connection release];
	[super dealloc];
}

@end
