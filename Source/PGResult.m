//
//  PGResult.m
//  PGCocoa
//
//  Created by Aaron Burghardt on 8/12/08.
//  Copyright 2008. All rights reserved.
//

#import "PGResult.h"
#import "PGConnection.h"
#import "PGRow.h"
#import "PGInternal.h"
#import <syslog.h>

#pragma mark - Prototypes


void NSDecimalInit(NSDecimal *dcm, uint64_t mantissa, int8_t exp, BOOL isNegative);
void SwapBigBinaryNumericToHost(pg_numeric_t *pgdata);
NSDecimalNumber * NSDecimalNumberFromBinaryNumeric(pg_numeric_t *pgval);
NSString * NSStringFromPGresultStatus(ExecStatusType status);
NSError * NSErrorFromPGresult(PGresult *result);

#pragma mark -

@interface PGRow (PGRowPrivate)
- (id)_initWithResult:(PGResult *)parent rowNumber:(NSInteger)index;
@end


@implementation PGResult

+ (instancetype)_resultWithResult:(PGresult *)result
{
	return [[[PGResult alloc] _initWithResult:result] autorelease];
}

- (id)_initWithResult:(PGresult *)result
{
	if (self = [super init]) {
		_result = result;
	}
	else {
		PQclear(result);
	}
	return self;
}

- (NSArray *)fieldNames
{
	@synchronized(self) {
		if (_fieldNames) return _fieldNames;
		
		int count = PQnfields(_result);
		NSMutableArray *names = [[NSMutableArray alloc] initWithCapacity:count];
		
		for (int i = 0; i < count; i++) {
			//		printf("Field: %s  type: %i\n", PQfname(result, i), PQftype(result, i));
			NSString *name = [[NSString alloc] initWithCString:PQfname(_result, i) encoding:NSUTF8StringEncoding];
			[names addObject:name];
		}
		_fieldNames = [names copy];
		[names release];
	}	
	return _fieldNames;
}

- (NSUInteger)numberOfFields
{
	return (NSUInteger)PQnfields(_result);
}

- (NSUInteger)numberOfRows
{
	return (NSUInteger)PQntuples(_result);
}

- (PGRow *)rowAtIndex:(NSUInteger)index
{
	return [[[PGRow alloc] _initWithResult:self rowNumber:index] autorelease];
}

- (PGRow *)objectAtIndexedSubscript:(NSUInteger)idx
{
	return [self rowAtIndex:idx];
}

- (NSArray *)rows
{
	NSUInteger rowCount = self.numberOfRows;
	NSMutableArray *rows = [[NSMutableArray alloc] initWithCapacity:rowCount];
	
	for (NSUInteger i = 0; i < rowCount; i++) {
		[rows addObject:[[[PGRow alloc] _initWithResult:self rowNumber:i] autorelease]];
	}
	NSArray *retval = [rows copy];
	[rows release];

	return retval;
}

- (NSUInteger)indexForFieldName:(NSString *)name
{
	return PQfnumber(_result, name.UTF8String);
}

- (id)valueAtRowIndex:(NSUInteger)rowNum fieldIndex:(NSUInteger)fieldNum
{
	id value;
	char *pgval;
	int length;
	Oid oid;
	BOOL isBinary;

	if (PQgetisnull(_result, rowNum, fieldNum))
		return [NSNull null];
	
	pgval = PQgetvalue(_result, rowNum, fieldNum);
	isBinary = PQfformat(_result, fieldNum);

	if (isBinary) {
		// get Oid types with "SELECT oid, typname from pg_type;"
		length = PQgetlength(_result, rowNum, fieldNum);
		oid = PQftype(_result, fieldNum);
		value = NSObjectFromPGBinaryValue(pgval, length, oid);
	}
	else
		value = [NSString stringWithCString:pgval encoding:NSUTF8StringEncoding];
	
	return value;
}

- (PGExecStatusType)status
{
	return PQresultStatus(_result);
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len
{
	NSUInteger i, maxLen, index;
	
	index = state->state;
	maxLen = PQntuples(_result);
	
	for (i = 0; i < len && index < maxLen ; i++, index++) {
		stackbuf[i] = [[[PGRow alloc] _initWithResult:self rowNumber:index] autorelease];
	}
	state->state = index;
	state->itemsPtr = stackbuf;
	state->mutationsPtr = (unsigned long *)self;  // Not sufficient if the instance is not read-only

	return i;
}

- (NSError *)error
{
	return NSErrorFromPGresult(_result);
}
			
- (void)dealloc
{
	[_fieldNames release];
	if (_result) PQclear(_result);
	[super dealloc];
}

@end


NSString * NSStringFromPGresultStatus(ExecStatusType status)
{
	NSString *desc;	
	
	switch (status) {
		case PGRES_EMPTY_QUERY:
			desc = @"The string sent to the server was empty.";
			break;
		case PGRES_COMMAND_OK:
			desc = @"Successful completion of a command returning no data.";
			break;
		case PGRES_TUPLES_OK:
			desc = @"Successful completion of a command returning data (such as a SELECT or SHOW).";
			break;
		case PGRES_COPY_OUT:
			desc = @"Copy Out (from server) data transfer started.";
			break;
		case PGRES_COPY_IN:
			desc = @"Copy In (to server) data transfer started.";
			break;
		case PGRES_BAD_RESPONSE:
			desc = @"The server's response was not understood.";
			break;
		case PGRES_NONFATAL_ERROR:
			desc = @"A nonfatal error (a notice or warning) occurred.";
			break;
		case PGRES_FATAL_ERROR:
			desc = @"A fatal error occurred.";
			break;
		default:
			desc = @"Unknown database error";
	}
	return desc;	
}

NSError * NSErrorFromPGresult(PGresult *result)
{
	NSError *error;
	ExecStatusType status = PQresultStatus(result);

	char *severity = PQresultErrorField(result, PG_DIAG_SEVERITY);         // always present
	char *primary  = PQresultErrorField(result, PG_DIAG_MESSAGE_PRIMARY);  // always present
	char *sqlstate = PQresultErrorField(result, PG_DIAG_SQLSTATE);         // always present
	char *detail   = PQresultErrorField(result, PG_DIAG_MESSAGE_DETAIL);
	char *hint     = PQresultErrorField(result, PG_DIAG_MESSAGE_HINT);

	int level;
	if (!severity)
		level = LOG_INFO;
	else if (!strncmp(severity, "ERROR", 3))
		level = LOG_ERR;
	else if (!strncmp(severity, "FATAL", 3))
		level = LOG_CRIT;
	else if (!strncmp(severity, "PANIC", 3))
		level = LOG_CRIT;
	else if (!strncmp(severity, "WARNING", 3))
		level = LOG_WARNING;
	else if (!strncmp(severity, "NOTICE", 3))
		level = LOG_NOTICE;
	else if (!strncmp(severity, "DEBUG", 3))
		level = LOG_DEBUG;
	else if (!strncmp(severity, "INFO", 3))
		level = LOG_INFO;
	else if (!strncmp(severity, "LOG", 3))
		level = LOG_DEBUG;
	else if (status == PGRES_NONFATAL_ERROR)
		level = LOG_WARNING;
	else if (status == PGRES_FATAL_ERROR)
		level = LOG_ERR;
	else
		level = LOG_INFO;

	NSMutableDictionary *info = [NSMutableDictionary dictionary];

	if (primary)
		[info setValue:[NSString stringWithUTF8String:primary] forKey:NSLocalizedDescriptionKey];
	else
		[info setValue:NSStringFromPGresultStatus(status) forKey:NSLocalizedDescriptionKey];

	if (sqlstate && detail)
	[info setValue:[NSString stringWithFormat:@"[SQLSTATE: %s] %s", sqlstate, (detail ? detail : "")]
			forKey:NSLocalizedFailureReasonErrorKey];

	if (hint)
		[info setValue:[NSString stringWithUTF8String:hint] forKey:NSLocalizedRecoverySuggestionErrorKey];

	error = [NSError errorWithDomain:PostgreSQLErrorDomain code:status userInfo:info];

	syslog(level, "%s", error.localizedDescription.UTF8String);

	return error;
}

///* Accessor functions for PGresult objects */
//extern ExecStatusType PQresultStatus(const PGresult *res);
//extern char *PQresStatus(ExecStatusType status);
//extern char *PQresultErrorMessage(const PGresult *res);
//extern char *PQresultErrorField(const PGresult *res, int fieldcode);
//extern int	PQntuples(const PGresult *res);
//extern int	PQnfields(const PGresult *res);
//extern int	PQbinaryTuples(const PGresult *res);
//extern char *PQfname(const PGresult *res, int field_num);
//extern int	PQfnumber(const PGresult *res, const char *field_name);
//extern Oid	PQftable(const PGresult *res, int field_num);
//extern int	PQftablecol(const PGresult *res, int field_num);
//extern int	PQfformat(const PGresult *res, int field_num);
//extern Oid	PQftype(const PGresult *res, int field_num);
//extern int	PQfsize(const PGresult *res, int field_num);
//extern int	PQfmod(const PGresult *res, int field_num);
//extern char *PQcmdStatus(PGresult *res);
//extern char *PQoidStatus(const PGresult *res);	/* old and ugly */
//extern Oid	PQoidValue(const PGresult *res);	/* new and improved */
//extern char *PQcmdTuples(PGresult *res);
//extern char *PQgetvalue(const PGresult *res, int tup_num, int field_num);
//extern int	PQgetlength(const PGresult *res, int tup_num, int field_num);
//extern int	PQgetisnull(const PGresult *res, int tup_num, int field_num);
//extern int	PQnparams(const PGresult *res);
//extern Oid	PQparamtype(const PGresult *res, int param_num);
//
///* Describe prepared statements and portals */
//extern PGresult *PQdescribePrepared(PGconn *conn, const char *stmt);
//extern PGresult *PQdescribePortal(PGconn *conn, const char *portal);
//extern int	PQsendDescribePrepared(PGconn *conn, const char *stmt);
//extern int	PQsendDescribePortal(PGconn *conn, const char *portal);
//
///* Delete a PGresult */
//extern void PQclear(PGresult *res);
