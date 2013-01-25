//
//  PGPreparedQuery.h
//  PGCocoa
//
//  Created by Aaron Burghardt on 8/30/08.
//  Copyright 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "libpq-fe.h"

@class PGConnection;
@class PGResult;


@interface PGPreparedQuery : NSObject 
{
	PGConnection *_connection;
	PGconn *_conn;				// weak ref
	NSString *_query;
	NSString *_name;
	
	NSMutableArray *_params;
	int _nparams;
	void *_paramBytes;
	BOOL _deallocated;			// indicator for status of the prepared query 
	
	// The following are weak refs within _paramBytes
	Oid *_types;
	double *_values;
	const char **_valueRefs;
	int *_lengths;
	int *_formats;
}

- (void)bindValue:(id)value atIndex:(NSUInteger)paramIndex;

- (void)bindValues:(NSArray *)values;

- (PGResult *)execute;

- (void)deallocate;

@end
