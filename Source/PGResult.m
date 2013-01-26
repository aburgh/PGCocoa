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
#import "libpq-fe.h"
#import <syslog.h>

#pragma mark - Prototypes

// libpq binary format for numeric types. Always sent big-endian.
struct numeric {
	int16_t  count;
	int16_t  exponent;
#ifdef __LITTLE_ENDIAN__
	uint16_t unknown1:6;
	uint16_t negative:1;
	uint16_t unknown2:9;
#else
	// untested
	uint16_t unknown1:14;
	uint16_t negative:1;
	uint16_t unknown2:1;
#endif
	uint16_t scale;
	uint16_t mantissa[];
};

void NSDecimalInit(NSDecimal *dcm, uint64_t mantissa, int8_t exp, BOOL isNegative);
void SwapBigBinaryNumericToHost(struct numeric *pgdata);
NSDecimalNumber * NSDecimalNumberFromBinaryNumeric(struct numeric *pgval);
NSString * NSStringFromPGresultStatus(ExecStatusType status);
NSError * NSErrorFromPGresult(PGresult *result);

#pragma mark -

@interface PGRow (PGRowPrivate)
- (id)_initWithResult:(PGResult *)parent rowNumber:(NSInteger)index;
@end


@implementation PGResult

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
	int64_t tmp64;
	int length;
	
	union PGresultValue {
		uint8_t *bytes;
		const char *string;
		int16_t *val16;
		int32_t *val32;
		int64_t *val64;
		struct numeric *numeric;
	} pgval;

	if (PQgetisnull(_result, rowNum, fieldNum)) return [NSNull null];
	
	BOOL isBinary = PQfformat(_result, fieldNum);
	pgval.string = PQgetvalue(_result, rowNum, fieldNum);
	
	if (isBinary) {
		// get Oid types with "SELECT oid, typname from pg_type;
		Oid oid = PQftype(_result, fieldNum);
		switch (oid) {
			case 16: // bool
				value = [NSNumber numberWithBool:(pgval.bytes[0] == 't')  ?  YES : NO];
				break;
			case 17:  // bytea
				value = [NSData dataWithBytes:pgval.bytes
									   length:PQgetlength(_result, rowNum, fieldNum)];
				break;
			case 18:  // char
				value = [NSNumber numberWithChar:pgval.bytes[0]];
				break;
			case 21:  // int2
				value = [NSNumber numberWithShort:NSSwapBigShortToHost(*pgval.val16)];
				break;
			case 23:  // int4
				value = [NSNumber numberWithInt:NSSwapBigIntToHost(*pgval.val32)];
				break;
			case 20:  // int8
				value = [NSNumber numberWithLongLong:NSSwapBigLongLongToHost(*pgval.val64)];
				break;
			case 700:  // float4
				value = [NSNumber numberWithFloat:NSSwapBigIntToHost(*pgval.val32)];
				break;
			case 701: {} // float8
				value = [NSNumber numberWithDouble:NSSwapBigLongLongToHost(*pgval.val64)];
				break;
			case 1114:  // timestamp
			case 1184:  // timestamptz
				// The default storage for timestamps in PostgreSQL 8.4 is int64 in microseconds. Prior to
				// 8.4, the default was a double, and is still a compile-time option. Supporting floats
				// is an exercise for the reader. Hint: the integer_datetimes connection parameter reflects
				// the server's setting.

				tmp64 = NSSwapBigLongLongToHost(*pgval.val64);
				NSTimeInterval interval = (NSTimeInterval) (tmp64 / 1000000);
				interval -= 31622400.0;												// adjust for Postgres' reference date of 1/1/2000
				interval += ((NSTimeInterval) (tmp64 % 1000000)) / 1000000 ;
				value = [NSDate dateWithTimeIntervalSinceReferenceDate:interval];
				break;
			case 1700: {} // numeric
				value = NSDecimalNumberFromBinaryNumeric(pgval.numeric);
				break;
			default:
				length = PQgetlength(_result, rowNum, fieldNum);
				value = [NSData dataWithBytes:pgval.bytes length:length];
				break;
		}
	}
	else value = [NSString stringWithCString:pgval.string encoding:NSUTF8StringEncoding];
	
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

#pragma mark - 

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
	if (!strncmp(severity, "ERROR", 3))
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

	[info setValue:[NSString stringWithUTF8String:primary] forKey:NSLocalizedDescriptionKey];

	[info setValue:[NSString stringWithFormat:@"[SQLSTATE: %s] %s", sqlstate, (detail ? detail : "")]
			forKey:NSLocalizedFailureReasonErrorKey];

	if (hint)
		[info setValue:[NSString stringWithUTF8String:hint] forKey:NSLocalizedRecoverySuggestionErrorKey];

	error = [NSError errorWithDomain:PostgreSQLErrorDomain code:status userInfo:info];

	syslog(level, "%s", error.localizedDescription.UTF8String);

	return error;
}

void NSDecimalInit(NSDecimal *dcm, uint64_t mantissa, int8_t exp, BOOL isNegative)
{
	NSDecimalNumber *object;

	object = [[NSDecimalNumber alloc] initWithMantissa:mantissa exponent:exp isNegative:isNegative];
	*dcm = object.decimalValue;
	[object release];
}

void SwapBigBinaryNumericToHost(struct numeric *pgdata)
{
	struct {
		int16_t  count;
		int16_t  exponent;
//		uint16_t unknown1:14;
//		uint16_t negative:1;
//		uint16_t unknown2:1;
		uint16_t flags;
		uint16_t scale;
		uint16_t mantissa[];
	} * swap;

	swap = (void *)pgdata;

	swap->count = NSSwapBigShortToHost(swap->count);
	swap->exponent = NSSwapBigShortToHost(swap->exponent);
	swap->flags = NSSwapBigShortToHost(swap->flags);
	swap->scale = NSSwapBigShortToHost(swap->scale);

	for (int i = 0; i < swap->count; i++)
		swap->mantissa[i] = NSSwapBigShortToHost(swap->mantissa[i]);
}

NSDecimalNumber * NSDecimalNumberFromBinaryNumeric(struct numeric *pgval)
{
	NSDecimal accum[2], component;
	NSCalculationError result;

	accum[0] = [[NSDecimalNumber zero] decimalValue];
	accum[1] = [[NSDecimalNumber zero] decimalValue];

	BOOL isNegative = pgval->negative;
	
	int count, j, k;

	count = NSSwapBigShortToHost(pgval->count);
	if (count > 9)
		[NSException raise:NSDecimalNumberExactnessException format:@"Value from database exceeds 36 digits of precision"];

	for (int i = 0; i < count; i++) {
		uint16_t mantissa = NSSwapBigShortToHost(pgval->mantissa[i]);
		uint16_t exponent = NSSwapBigShortToHost(pgval->exponent);

		NSDecimalInit(&component, mantissa, (exponent - i) << 2, isNegative);

		// alternate between accum decimals to avoid copying the result
		j = i & 0x1;
		k = (i + 1) & 0x1;

		result = NSDecimalAdd(&accum[j], &accum[k], &component, NSRoundPlain);
		if (result != NSCalculationNoError) {
			return [NSDecimalNumber notANumber];
		}
	}
	return [NSDecimalNumber decimalNumberWithDecimal:accum[j]];
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
