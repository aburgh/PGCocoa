//
//  PGPreparedQuery.h
//  PGCocoa
//
//  Created by Aaron Burghardt on 8/30/08.
//  Copyright 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PGConnection;
@class PGResult;
union pg_value;

@interface PGPreparedQuery : NSObject 
{
	PGConnection *_connection;
	NSString *_query;
	NSString *_name;
	
	NSMutableArray *_params;
	BOOL _deallocated;			// indicator for status of the prepared query
	
	unsigned int *_types;		// Same type as Oid
	union pg_value *_values;
	const char **_valueRefs;
	int *_lengths;
	int *_formats;
}

- (void)bindValue:(id)value atIndex:(NSUInteger)paramIndex;

- (void)bindValues:(NSArray *)values;

- (PGResult *)execute;

- (void)deallocate;

@end
