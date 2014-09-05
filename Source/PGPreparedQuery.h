//
//  PGPreparedQuery.h
//  PGCocoa
//
//  Created by Aaron Burghardt on 8/30/08.
//  Copyright 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <PGCocoa/PGQueryParameters.h>

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

/** Convenience creator using initWithName:query:types:connection:.
 @param name the name of prepared query
 @param sql the SQL statement
 @param paramTypes array of parameter types as NSNumbers
 @param conn the connection to use
 @return Returns an initialized instance or nil if an error occurred.
 */
+ (PGPreparedQuery *)queryWithName:(NSString *)name sql:(NSString *)sql types:(NSArray *)paramTypes connection:(PGConnection *)conn;

/**
 */
+ (PGPreparedQuery *)queryWithName:(NSString *)name sql:(NSString *)sql types:(PGQueryParameterType *)paramTypes count:(NSUInteger)numParams connection:(PGConnection *)conn;

/** Initialize a prepared query
 @param name the name of prepared query
 @param sql the SQL statement
 @param paramTypes array of parameter types as NSNumbers
 @param conn the connection to use
 */
- (id)initWithName:(NSString *)name query:(NSString *)query types:(NSArray *)paramTypes connection:(PGConnection *)conn;

/** The designated initializer.
 * @discussion The types may be NULL or may contain fewer elements than the number of placeholders
          in the query. Parameters not specified will be inferred or may be cast in the 
		  query statement.
 * @param name the prepared name, which must be unique per connection. A single unnamed
 *              query can be specified by passing nil or @"".
 * @param query the SQL statement
 * @param types a C-array of parameter type constants
 * @param count the number of parameters in the array of types
 * @param conn the connection to use
 * @return the initialized instance on success; nil on error. If nil is return, the error
 *         can be retrieved from the connection object.
 */
- (id)initWithName:(NSString *)name query:(NSString *)query types:(PGQueryParameterType *)types count:(NSUInteger)numTypes connection:(PGConnection *)conn;

/** Execute the prepared query with the given values.
 * @param values the values to bind to be bound to query parameters
 * @return A result object is always returned.
 */
- (PGResult *)executeWithValues:(NSArray *)values;

/** Deallocates the prepared query on the server. This is invoked if needed when the
 *  instance is dealloc'ed.
 */
- (void)deallocate;

@end
