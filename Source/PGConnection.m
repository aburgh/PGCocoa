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
#import "PGQueryParameters.h"
#import "PGQueryParameters_Private.h"

#pragma mark - Prototypes

NSInteger PGSecondsFromUTC(PGConnection *conn);

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
	PGresult *result = PQexecParams(_connection, query.UTF8String, 0, NULL, NULL, NULL, NULL, 1);

	return [[[PGResult alloc] _initWithResult:result] autorelease];
}

- (PGResult *)executeQuery:(NSString *)query parameters:(PGQueryParameters *)params
{
	PGresult *result;

	result = PQexecParams(_connection, query.UTF8String, params.count, params.types, params.valueRefs, params.lengths, params.formats, 1);

	return [[[PGResult alloc] _initWithResult:result] autorelease];
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


