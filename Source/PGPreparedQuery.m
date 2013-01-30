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


+ (PGPreparedQuery *)preparedQueryWithName:(NSString *)name query:(NSString *)sql types:(NSArray *)paramTypes connection:(PGConnection *)conn
{
	return [[[PGPreparedQuery alloc] initWithName:name query:sql types:paramTypes connection:conn] autorelease];
}

+ (PGPreparedQuery *)preparedQueryWithName:(NSString *)name query:(NSString *)sql types:(PGQueryParameterType *)paramTypes count:(NSUInteger)numParams connection:(PGConnection *)conn
{
	return [[[PGPreparedQuery alloc] initWithName:name query:sql types:paramTypes count:numParams connection:conn] autorelease];
}

- (void)deallocate
{
	if (!_deallocated) {
		char *query;
		PGresult *result;
		
		if (asprintf(&query, "DEALLOCATE %s;", _name.UTF8String) > 0) {

			result = PQexec(_connection.conn, query);

			if (PQresultStatus(result) == PGRES_COMMAND_OK) 
				_deallocated = YES;
			else
				syslog(LOG_ERR, "DEALLOCATE %s: %s", _name.UTF8String, PQresultErrorMessage(result));

			free(query);
			
		}
		else {
			perror("Error preparing DEALLOCATE");
		}
	}
}

- (void)dealloc
{
	if (!_deallocated) [self deallocate];
//	[_params release];
	[_name release];
	[_query release];
	[_connection release];	

//	free(_types);
//	free(_values);
//	free(_valueRefs);
//	free(_lengths);
//	free(_formats);
	[super dealloc];
}

- (id)initWithName:(NSString *)name query:(NSString *)query types:(PGQueryParameterType *)paramTypes count:(NSUInteger)numParams connection:(PGConnection *)conn
{
	if (self = [super init]) {
		_connection = [conn retain];
		_query = [query copy];
		_name = [name copy];

		_deallocated = NO;

		PGresult *result = PQprepare(_connection.conn, _name.UTF8String, _query.UTF8String, numParams, paramTypes);
		if (PQresultStatus(result) != PGRES_COMMAND_OK) {
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

//- (void)bindValue:(id)value atIndex:(NSUInteger)i;
//{
//	[_params replaceObjectAtIndex:i withObject:value];
//
//	// The default storage for timestamps in PostgreSQL 8.4 is int64 in microseconds. Prior to
//	// 8.4, the default was a double, and is still a compile-time option. Supporting floats
//	// is an exercise for the reader. Hint: the integer_datetimes connection parameter reflects
//	// the server's setting.
//
//	// Prefer isKindOfClass: over isMemberOfClass: to allow class clusters,
//	// but check subclasses first (i.e., NSDecimalNumber before NSNumber).
//	
//	if ([value isKindOfClass:NSString.class]) {
//		_types[i] = 25;	// text
//		_valueRefs[i] = (char *)[value UTF8String];
//		_lengths[i] = 0;  // ignored
//		_formats[i] = 0; 
//	}
//	else if ([value isKindOfClass:NSDate.class]) {
//		_types[i] = 1184; // timestamp == 1114, timestamptz == 1184
//
//		long double interval = [value timeIntervalSinceReferenceDate]; // upcast to preserve precision
//		interval += 31622400.0; // timestamp(tz) ref date == 2000-01-01 midnight
//		interval *= 1000000.0;
//		_values[i].val64 = interval;
//		_values[i].val64 = NSSwapHostLongLongToBig(_values[i].val64);
//		_valueRefs[i] = _values[i].bytes;
//		_lengths[i] = 8;
//		_formats[i] = 1;
//	}
//	else if ([value isKindOfClass:NSData.class]) {
//		_types[i] = 17;  // bytea
//		_valueRefs[i] = (char *)[value bytes];
//		_lengths[i] = (int)[value length];
//		_formats[i] = 1;
//	}
//	else if ([value isKindOfClass:NSNumber.class]) {
//		
//		const char *objCType = [value objCType];
//		switch (objCType[0]) {
//			case 'c':
//			case 's':
//			case 'i':
//			case 'q':
//				_types[i] = 20; // int8
//				_values[i].val64 = NSSwapHostLongLongToBig([value longLongValue]);
//				_lengths[i] = 8;
//				break;
//			case 'f':
//			case 'd':
//				_types[i] = 701; // float4 = 700, float8 == 701
//				// store as double but swap as long long to prevent converting swap result to a double
//				_values[i].d = [value doubleValue];
//				_values[i].val64 = NSSwapHostLongLongToBig(_values[i].val64);
//				_lengths[i] = sizeof(double);
//				break;
//			default:
//				[NSException raise:NSInvalidArgumentException format:@"Unsupported NSNumber objCType"];
//				break;
//		}
//		
//		_valueRefs[i] = _values[i].bytes;
//		_formats[i] = 1;
//	}
//	else if (value == NSNull.null) {
//		_valueRefs[i] = NULL;
//		_lengths[i] = 0;  // ignored
//		_formats[i] = 0;
//	}
//	
//}
//
//- (void)bindValues:(NSArray *)values;
//{
//	NSUInteger nparams = values.count;
//	
//	NSAssert(_params.count == nparams, @"Number of values doesn't match the number of query parameters.");
//	
//	for (int i = 0; i < _params.count; i++)
//		[self bindValue:values[i] atIndex:i];
//}

- (PGResult *)executeWithParameters:(PGQueryParameters *)params;
{
	PGresult *result = PQexecPrepared(_connection.conn, _name.UTF8String, params.count, params.valueRefs, params.lengths, params.formats, 1);

	return [[[PGResult alloc] _initWithResult:result] autorelease];
}

@end
