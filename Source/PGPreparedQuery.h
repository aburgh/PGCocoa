//
//  PGPreparedQuery.h
//  PGCocoa
//
//  Created by Aaron Burghardt on 8/30/08.
//  Copyright 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PGQueryParameters.h"

@class PGConnection;
@class PGResult;

@interface PGPreparedQuery : NSObject 
{
	PGConnection *_connection;
	NSString *_query;
	NSString *_name;
	
//	NSMutableArray *_params;
	BOOL _allocated;			// indicator for status of the prepared query
	
}

+ (PGPreparedQuery *)queryWithName:(NSString *)name sql:(NSString *)sql types:(NSArray *)paramTypes connection:(PGConnection *)conn;

+ (PGPreparedQuery *)queryWithName:(NSString *)name sql:(NSString *)sql types:(PGQueryParameterType *)paramTypes count:(NSUInteger)numParams connection:(PGConnection *)conn;

- (id)initWithName:(NSString *)name query:(NSString *)query types:(NSArray *)sampleParams connection:(PGConnection *)conn;

- (id)initWithName:(NSString *)name query:(NSString *)query types:(PGQueryParameterType *)paramTypes count:(NSUInteger)numParams connection:(PGConnection *)conn;

- (PGResult *)executeWithParameters:(PGQueryParameters *)params;

- (void)deallocate;

@end
