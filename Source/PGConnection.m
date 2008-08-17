//
//  PGConnection.m
//  PGCocoa
//
//  Created by Aaron Burghardt on 7/14/08.
//  Copyright 2008 No Company. All rights reserved.
//

#import "PGConnection.h"
#import "PGResult.h"

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
	NSArray *keys = [_params allKeys];
	NSMutableString *connString = [NSMutableString string];

	for (int i = 0; i < [keys count]; i++) {
		NSString *key = [keys objectAtIndex:i];
		[connString appendFormat:@"%@=%@ ", key, [_params objectForKey:key]];
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
	PGresult *result = PQexec(_connection, [query UTF8String]);
	
	return [[[PGResult alloc] _initWithResult:result] autorelease];
}

- (PGResult *)executeQuery:(NSString *)query parameters:(NSArray *)params
{
	int nparams = [params count];
	Oid *types		= malloc(nparams * sizeof(Oid));
	double *values	= malloc(nparams * sizeof(double));
	char **valueRefs= malloc(nparams * sizeof(char *));
	int *lengths	= malloc(nparams * sizeof(int));
	int *formats	= malloc(nparams * sizeof(int));

	for (int i = 0; i < nparams; i++) {
		id param = [params objectAtIndex:i];
		
//		Class class = [param class];
//		
		if ([param isKindOfClass:[NSString class]]) {
			*(types + i) = 25;	// text
			*(valueRefs + i) = (char *)[param UTF8String];
			*(lengths + i) = 0;  // ignored
			*(formats + i) = 0; 
		}
		else if ([param isKindOfClass:[NSDate class]]) {
			// TODO
			*(types + i) = 702; // abstime
			*(values + i) = 0;
			*(valueRefs + i) = (char *)(values + i);
			*(lengths + i) = 0;
			*(formats + i) = 0;
		}
		else if ([param isKindOfClass:[NSData class]]) {
			*(types + i) = 17;  // bytea
			*(valueRefs + i) = (char *)[param bytes];
			*(lengths + i) = (int)[param length];
			*(formats + i) = 1;
		}
		else if ([param isKindOfClass:[NSNumber class]]) {
			
			[param getValue:(values + i)];
			*(valueRefs + i) = (char *)(values + i);
			*(formats + i) = 1;

			const char *objCType = [param objCType];
			switch (*objCType) {
				case 'c':
					*(types + i) = 17; // bytea
					*(lengths + i) = sizeof(char);
					break;
				case 's':
					*(types + i) = 21; // int2
					*(lengths + i) = sizeof(short);
					*(values + i) = NSSwapHostShortToBig(*(values + i));
					break;
				case 'i':
					*(types + i) = 23; // int4
					*(lengths + i) = sizeof(int);
					*(values + i) = NSSwapHostIntToBig(*(values + i));
					break;
				case 'q':
					*(types + i) = 20; // int8
					*(lengths + i) = sizeof(long long);
					*(values + i) = NSSwapHostLongLongToBig(*(values + i));
					break;
				case 'f':
					*(types + i) = 700; // float4
					*(lengths + i) = sizeof(float);
					*(values + i) = NSSwapHostIntToBig(*(values + i));
					break;
				case 'd':
					*(types + i) = 701; // float8
					*(lengths + i) = sizeof(double);
					*(values + i) = NSSwapHostLongLongToBig(*(values + i));
					break;
				default:
					// TODO: throw exception
					break;
			}
		}
	}
	
//	PGresult *result = PQprepare(_connection, " ", [query UTF8String], [params count], NULL);
	PGresult *result = PQexecParams(_connection, [query UTF8String], nparams, types, (const char * const *) valueRefs, lengths, formats, 1);
	free(types);
	free(values);
	free(valueRefs);
	free(lengths);
	free(formats);

	return [[[PGResult alloc] _initWithResult:result] autorelease];
}


- (NSString *)errorMessage;
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
						  @"Database Error", NSLocalizedDescriptionKey,
						  [self errorMessage], NSLocalizedFailureReasonErrorKey, 
						  nil];

	return [NSError errorWithDomain:PostgreSQLErrorDomain code:-1 userInfo:info];
}
	
- (PGTransactionStatusType)transactionStatus
{
	return PQtransactionStatus(_connection);
}

- (void)dealloc
{
	[_params release];
	if (_connection) PQfinish(_connection);
	[super dealloc];
}

@end

NSString *PostgreSQLErrorDomain = @"PostgreSQLErrorDomain";
