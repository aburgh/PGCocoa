//
//  PGConnection.m
//  PGCocoa
//
//  Created by Aaron Burghardt on 7/14/08.
//  Copyright 2008. All rights reserved.
//

#import "PGConnection.h"
#import "PGResult.h"
#import "PGPreparedQuery.h"
#import "PGInternal.h"

#pragma mark - Prototypes

NSInteger PGSecondsFromUTC(PGConnection *conn);


@interface PGPreparedQuery (PGPreparedQueryPGConnectionPrivate)

- (id)_initWithName:(NSString *)name query:(NSString *)query types:(NSArray *)sampleParams connection:(PGConnection *)conn;

@end

#pragma mark -

@implementation PGConnection

- (id)initWithParameters:(NSDictionary *)params;
{
	if (self = [super init]) {
		_params = [params copy];
	}

	return self;
}

- (BOOL)connect
{
	NSArray *keys = _params.allKeys;

	if ([keys containsObject:@"application_name"] == NO) {
		NSString *name = [[NSProcessInfo processInfo] processName];
		name = [name stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]; // escape backlashes with double-backslash
		name = [name stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];    // escape single quote with backslash-quote
	}
	
	NSMutableString *connString = [NSMutableString string];

	for (int i = 0; i < keys.count; i++) {
		NSString *key = keys[i];
		[connString appendFormat:@"%@='%@' ", key, _params[key]];
	}
	
	_connection = PQconnectdb([connString cStringUsingEncoding:NSUTF8StringEncoding]);

	return (PQstatus(_connection) == CONNECTION_OK);
}

- (void)disconnect
{
	if (_connection) {
		PQfinish(_connection);
		_connection = NULL;
	}
}

- (void)reset
{
	PQreset(_connection);
}

- (PGResult *)executeQuery:(NSString *)query
{
	PGresult *result = PQexec(_connection, query.UTF8String);

	return [[[PGResult alloc] _initWithResult:result] autorelease];
}

- (PGResult *)executeQuery:(NSString *)query parameters:(NSArray *)params
{
	int nparams = params.count;
//	void *paramBytes = malloc(nparams * sizeof(struct PGQueryParameter));

//	Oid *types		= paramBytes;
	Oid *types       = calloc(nparams, sizeof(Oid));
	pg_value_t *values = calloc(nparams, sizeof(pg_value_t));
	char **valueRefs = calloc(nparams, sizeof(char *));
	int *lengths     = calloc(nparams, sizeof(int));
	int *formats     = calloc(nparams, sizeof(int));
	
	for (int i = 0; i < nparams; i++) {
		id param = params[i];
		
		if ([param isKindOfClass:[NSString class]]) {
			types[i] = 25;	// text
			valueRefs[i] = (char *)[param UTF8String];
			lengths[i] = 0;  // ignored
			formats[i] = 0;
		}
		else if ([param isKindOfClass:[NSDate class]]) {
			types[i] = 1184; // timestamp == 1114,  timestamptz == 1184

			long double interval = [param timeIntervalSinceReferenceDate];
			interval += 31622400.0; // timestamp(tz) ref date == 2000-01-01 midnight
			interval *= 1000000.0;
			values[i].val64 = NSSwapHostLongLongToBig(interval);

			valueRefs[i] = values[i].string;
			lengths[i] = 8;
			formats[i] = 1;
		}
		else if ([param isKindOfClass:[NSData class]]) {
			types[i] = 17;  // bytea
			valueRefs[i] = (char *)[param bytes];
			lengths[i] = (int)[param length];
			formats[i] = 1;
		}
		else if ([param isKindOfClass:[NSNumber class]]) {
			
			const char *objCType = [param objCType];
			switch (objCType[0]) {
				case 'c':
				case 's':
				case 'i':
				case 'q':
					types[i] = 20; // int8
					values[i].val64 = NSSwapHostLongLongToBig([param longLongValue]);
					lengths[i] = sizeof(long long);
					break;
				case 'f':
				case 'd':
					types[i] = 701; // float4 = 700, float8 == 701
					values[i].d = [param doubleValue];
					values[i].val64 = NSSwapHostLongLongToBig(values[i].val64);
					lengths[i] = sizeof(double);
					break;
				default:
					free(types);
					free(values);
					free(valueRefs);
					free(lengths);
					free(formats);
					[NSException raise:NSInvalidArgumentException format:@"Unsupported NSNumber objCType '%s'", objCType];
					break;
			}

			valueRefs[i] = (char *) &values[i];
			formats[i] = 1;
		}
	}

	PGresult *result = PQexecParams(_connection, query.UTF8String, nparams, types, (const char * const *) valueRefs, lengths, formats, 1);

	free(types);
	free(values);
	free(valueRefs);
	free(lengths);
	free(formats);

	return [[[PGResult alloc] _initWithResult:result] autorelease];
}

- (PGPreparedQuery *)preparedQueryWithName:(NSString *)name query:(NSString *)sql types:(NSArray *)paramTypes;
{
	return [[[PGPreparedQuery alloc] _initWithName:name query:sql types:paramTypes connection:self] autorelease];
}

- (NSString *)errorMessage
{
	char *errorCString = PQerrorMessage(_connection);
	if (!errorCString) return nil;

	return [NSString stringWithCString:PQerrorMessage(_connection) encoding:NSASCIIStringEncoding];
}

- (NSError *)error;
{
	NSString *errorMessage = [self errorMessage];
	if (!errorMessage) return nil;
	
	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
						  @"Database Connection Error", NSLocalizedDescriptionKey,
						  errorMessage, NSLocalizedRecoverySuggestionErrorKey,
						  errorMessage, NSLocalizedFailureReasonErrorKey, 
						  nil];

	return [NSError errorWithDomain:PostgreSQLErrorDomain code:-1 userInfo:info];
}

- (BOOL)beginTransaction
{
	PGresult *result = PQexec(_connection, "BEGIN");

	ExecStatusType status = PQresultStatus(result);
	PQclear(result);

	return (status == PGRES_COMMAND_OK);
}

- (BOOL)commitTransaction
{
	PGresult *result = PQexec(_connection, "COMMIT");

	ExecStatusType status = PQresultStatus(result);
	PQclear(result);

	return (status == PGRES_COMMAND_OK);
}

- (BOOL)rollbackTransaction
{
	PGresult *result = PQexec(_connection, "ROLLBACK");

	ExecStatusType status = PQresultStatus(result);
	PQclear(result);
	
	return (status == PGRES_COMMAND_OK);
}

- (PGConnStatusType)status
{
	return PQstatus(_connection);
}

- (PGTransactStatusType)transactionStatus
{
	return PQtransactionStatus(_connection);
}

- (NSString *)valueForServerParameter:(NSString *)paramName
{
	const char *status = PQparameterStatus(_connection, paramName.UTF8String);

	return [NSString stringWithCString:status encoding:NSUTF8StringEncoding];
}

- (struct pg_conn *)conn
{
	return _connection;
}

- (void)dealloc
{
	[_params release];
	if (_connection) PQfinish(_connection);
	[super dealloc];
}

@end

NSInteger PGSecondsFromUTC(PGConnection *conn)
{
	NSString *tzName = [conn valueForServerParameter:@"TimeZone"];

	NSTimeZone *zone = [NSTimeZone timeZoneWithName:tzName];

	return zone.secondsFromGMT;
}


NSString *const PostgreSQLErrorDomain = @"PostgreSQLErrorDomain";

// Connection Parameter Keys
NSString *const PGConnectionParameterHostKey = @"host";
NSString *const PGConnectionParameterHostAddressKey = @"hostaddr";
NSString *const PGConnectionParameterPortKey = @"port";
NSString *const PGConnectionParameterDatabaseNameKey = @"dbname";
NSString *const PGConnectionParameterUsernameKey = @"user";
NSString *const PGConnectionParameterPasswordKey = @"password";
NSString *const PGConnectionParameterConnectionTimeoutKey = @"connect_timeout";
NSString *const PGConnectionParameterOptionsKey = @"options";
NSString *const PGConnectionParameterSSLModeKey = @"sslmode";
NSString *const PGConnectionParameterKerberosServiceNameKey = @"krbsrvname";
NSString *const PGConnectionParameterServiceNameKey = @"service";


