//
//  PGPreparedQuery.m
//  PGCocoa
//
//  Created by Aaron Burghardt on 8/30/08.
//  Copyright 2008. All rights reserved.
//

#import "PGPreparedQuery.h"
#import "PGConnection.h"
#import "PGResult.h"
#import "PGInternal.h"
#import "libpq-fe.h"

#pragma mark - Prototypes

NSInteger PGSecondsFromUTC(PGConnection *connection);

#pragma mark -

@implementation PGPreparedQuery

- (void)deallocate
{
	if (!_deallocated) {
		char *query;
		PGresult *result;
		
		if (asprintf(&query, "DEALLOCATE %s;", _name.UTF8String) > 0) {

			result = PQexec(_conn, query);

			if (PQresultStatus(result) == PGRES_COMMAND_OK) 
				_deallocated = YES;
			else
				fprintf(stderr, "Error deallocating prepared query: %s\n", PQresultErrorMessage(result));

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
	[_params release];
	[_name release];
	[_query release];
	[_connection release];	
	if (_paramBytes) free(_paramBytes);
	[super dealloc];
}

- (id)_initWithName:(NSString *)name query:(NSString *)query types:(NSArray *)paramTypes connection:(PGConnection *)conn;
{
	if (self = [super init]) {
		@try {
			_connection = [conn retain];
			_conn = [_connection _conn];
			
			_query = [query copy];
			_name = [name copy];
			
			// PGQueryParameter is used to calculate sizeof, but the actual params are grouped as arrays of paramaters
			_params = [paramTypes mutableCopy];
			_nparams = paramTypes.count;
			_paramBytes = malloc(_nparams * sizeof(struct PGQueryParameter));
			_types = _paramBytes;
			_values		= (void *) _types  + (_nparams * sizeof(Oid));
			_valueRefs	= (void *) _values + (_nparams * sizeof(union PGMaxSizeType));
			_lengths	= (void *) _valueRefs + (_nparams * sizeof(char *));
			_formats	= (void *) _lengths + (_nparams * sizeof(int));
			
			[self bindValues:paramTypes];
			
			_deallocated = NO;

			PGresult *result = PQprepare(_conn, _name.UTF8String, _query.UTF8String, _nparams, _types);
			if (PQresultStatus(result) != PGRES_COMMAND_OK) {
				[self dealloc];
				self = nil;
			}
		}
		@catch (NSException *e) {
			[self dealloc];
			@throw(e);
		}
	}
	return self;
}

- (void)bindValue:(id)value atIndex:(NSUInteger)paramIndex;
{
	int i = paramIndex;
	[_params replaceObjectAtIndex:i withObject:value];
	
	if ([value isKindOfClass:NSString.class]) {
		*(_types + i) = 25;	// text
		*(_valueRefs + i) = (char *)[value UTF8String];
		*(_lengths + i) = 0;  // ignored
		*(_formats + i) = 0; 
	}
	else if ([value isKindOfClass:NSDate.class]) {
		// TODO
		*(_types + i) = 1184; // timestamp == 1114,  timestamptz == 1184
		NSTimeInterval interval = [value timeIntervalSinceReferenceDate] + 31622400.0; // timestamp(tz) ref date == 2000-01-01 midnight
		*(long long *)(_values + i) = NSSwapHostLongLongToBig(*(long long *)&interval);  // cast needed to prevent converting swap result to a double
		*(_valueRefs + i) = (char *)(_values + i);
		*(_lengths + i) = 8;
		*(_formats + i) = 1;
	}
	else if ([value isKindOfClass:NSData.class]) {
		*(_types + i) = 17;  // bytea
		*(_valueRefs + i) = (char *)[value bytes];
		*(_lengths + i) = (int)[value length];
		*(_formats + i) = 1;
	}
	else if ([value isKindOfClass:NSNumber.class]) {
		
		const char *objCType = [value objCType];
		switch (*objCType) {
			case 'c':
			case 's':
			case 'i':
			case 'q':
				*(_types + i) = 20; // int8
				long long tmpLongLong = [value longLongValue];
				*(long long *)(_values + i) = NSSwapHostLongLongToBig(tmpLongLong); // cast needed to prevent converting swap result to a double
				*(_lengths + i) = sizeof(long long);
				break;
			case 'f':
			case 'd':
				*(_types + i) = 701; // float4 = 700, float8 == 701
				double tmpDouble = [value doubleValue];
				*(long long *)(_values + i) = NSSwapHostLongLongToBig(*(long long *)&tmpDouble); // cast needed to prevent converting swap result to a double
				*(_lengths + i) = sizeof(double);
				break;
			default: 
				@throw([NSException exceptionWithName:NSInvalidArgumentException
											   reason:@"Unsupported NSNumber objCType" 
											 userInfo:nil]);
				break;
		}
		
		*(_valueRefs + i) = (char *)(_values + i);
		*(_formats + i) = 1;
	}
	else if (value == NSNull.null) {
		*(_valueRefs + i) = NULL;
		*(_lengths + i) = 0;  // ignored
		*(_formats + i) = 0; 
	}
	
}

- (void)bindValues:(NSArray *)values;
{
	NSUInteger nparams = values.count;
	
	NSAssert(_nparams == nparams, @"Number of values doesn't match the number of query parameters.");
	
	for (int i = 0; i < _nparams; i++) 
		[self bindValue:values[i] atIndex:i];
}

- (PGResult *)execute;
{
	PGresult *result = PQexecPrepared(_conn, _name.UTF8String, _nparams, _valueRefs, _lengths, _formats, 1);

	return [[[PGResult alloc] _initWithResult:result] autorelease];
}

@end
