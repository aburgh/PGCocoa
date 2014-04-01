//
//  PGPreparedQuery.m
//  PGCocoa
//
//  Created by Aaron Burghardt on 8/30/08.
//  Copyright 2008. All rights reserved.
//

#import "PGPreparedQuery.h"
#import "PGQueryParameters_Private.h"
#import "PGConnection.h"
#import "PGResult.h"
#import "PGInternal.h"
#import <syslog.h>

#pragma mark - Prototypes

#pragma mark -

@implementation PGPreparedQuery


+ (PGPreparedQuery *)queryWithName:(NSString *)name sql:(NSString *)sql types:(NSArray *)paramTypes connection:(PGConnection *)conn
{
	return [[[PGPreparedQuery alloc] initWithName:name query:sql types:paramTypes connection:conn] autorelease];
}

+ (PGPreparedQuery *)queryWithName:(NSString *)name sql:(NSString *)sql types:(PGQueryParameterType *)paramTypes count:(NSUInteger)numParams connection:(PGConnection *)conn
{
	return [[[PGPreparedQuery alloc] initWithName:name query:sql types:paramTypes count:numParams connection:conn] autorelease];
}

- (void)deallocate
{
	if (_allocated) {
		char *query;
		PGresult *result;
		PGExecStatusType status;

		if (asprintf(&query, "DEALLOCATE %s;", _name.UTF8String) > 0) {

			result = PQexec(_connection.conn, query);

			if ((status = PQresultStatus(result)) == PGRES_COMMAND_OK)
				_allocated = NO;
			else
				syslog(LOG_ERR, "DEALLOCATE %s: %s (%d)", _name.UTF8String, PQresultErrorMessage(result), status);

			free(query);
			PQclear(result);
		}
		else {
			perror("Error preparing DEALLOCATE");
		}
	}
}

- (void)dealloc
{
	if (_allocated) [self deallocate];
	
	[_name release];
	[_query release];
	[_connection release];
	[super dealloc];
}

- (id)initWithName:(NSString *)name query:(NSString *)query types:(PGQueryParameterType *)paramTypes count:(NSUInteger)numParams connection:(PGConnection *)conn
{
	if (self = [super init]) {
		_connection = [conn retain];
		_query = [query copy];
		_name = [name copy];

		PGresult *result = PQprepare(_connection.conn, _name.UTF8String, _query.UTF8String, numParams, paramTypes);
		if (PQresultStatus(result) == PGRES_COMMAND_OK) {
			_allocated = YES;
		}
		else {
			[self dealloc];
			self = nil;
		}
	}
	return self;
}

- (id)initWithName:(NSString *)name query:(NSString *)query types:(NSArray *)paramTypes connection:(PGConnection *)conn
{
	PGQueryParameterType *types = calloc(paramTypes.count, sizeof(PGQueryParameterType));

	for (int i = 0; i < paramTypes.count; i++)
		types[i] = [paramTypes[i] intValue];

	self = [self initWithName:name query:query types:types count:paramTypes.count connection:conn];

	free(types);

	return self;
}

- (PGResult *)executeWithParameters:(PGQueryParameters *)params;
{
	PGresult *result = PQexecPrepared(_connection.conn, _name.UTF8String, params.count, params.valueRefs, params.lengths, params.formats, 1);

	return [[[PGResult alloc] _initWithResult:result] autorelease];
}

@end
