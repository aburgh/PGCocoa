//
//  PGResult.m
//  PGCocoa
//
//  Created by Aaron Burghardt on 8/12/08.
//  Copyright 2008 No Company. All rights reserved.
//

#import "PGResult.h"
#import "PGConnection.h"
#import "PGRow.h"

@interface PGRow (PGRowPrivate)
- (id)_initWithResult:(PGResult *)parent rowNumber:(NSInteger)index;
@end


@implementation PGResult

- (id)_initWithResult:(PGresult *)result
{
//	printf("Result command status: %s\n", PQcmdStatus(result));
	
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
		_fieldNames = [[NSMutableArray alloc] initWithCapacity:count];
		
		for (int i = 0; i < count; i++) {
			//		printf("Field: %s  type: %i\n", PQfname(result, i), PQftype(result, i));
			NSString *name = [[NSString alloc] initWithCString:PQfname(_result, i) encoding:NSUTF8StringEncoding];
			[(NSMutableArray *)_fieldNames addObject:name];
		}
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

- (NSArray *)rows
{
	NSUInteger rowCount = [self numberOfRows];
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:rowCount];
	
	for (NSUInteger i = 0; i < rowCount; i++) {
		[rows addObject:[[[PGRow alloc] _initWithResult:self rowNumber:i] autorelease]];
	}
	
	return rows;
}

- (NSUInteger)indexForFieldName:(NSString *)name
{
	return PQfnumber(_result, [name UTF8String]);
}

- (id)valueAtRowIndex:(NSUInteger)rowNum fieldIndex:(NSUInteger)fieldNum
{
	id value;
	
	if (PQgetisnull(_result, rowNum, fieldNum)) return [NSNull null];
	
	BOOL isBinary = PQfformat(_result, fieldNum);
	void *valuePtr = PQgetvalue(_result, rowNum, fieldNum);
	
	if (isBinary) {
		// get Oid types with "SELECT oid, typname from pg_type;
		Oid oid = PQftype(_result, fieldNum);
		switch (oid) {
			case 16: // bool
				value = [NSNumber numberWithBool:(*(char *)valuePtr == 't')  ?  YES : NO];
				break;
			case 17: // bytea
				value = [NSData dataWithBytes:valuePtr 
									   length:PQgetlength(_result, rowNum, fieldNum)];
				break;
			case 18: // char
				value = [NSNumber numberWithChar:*(char *)valuePtr];
				break;
			case 21: {} // int2 
				*(int *)valuePtr = NSSwapBigShortToHost(*(int *)valuePtr);
				short *shortPtr = valuePtr;
				value = [NSNumber numberWithShort:*shortPtr];
				break;
			case 23: {} // int4
				*(int *)valuePtr = NSSwapBigIntToHost(*(int *)valuePtr);
				value = [NSNumber numberWithInt:*(int *)valuePtr];
				break;
			case 20: {} // int8
				*(long long *)valuePtr = NSSwapBigLongLongToHost(*(long long *)valuePtr);
				value = [NSNumber numberWithLongLong:*(long long *)valuePtr];
				break;
			case 700: {} // float4
				*(int *)valuePtr = NSSwapBigIntToHost(*(int *)valuePtr);
				value = [NSNumber numberWithFloat:*(float *)valuePtr];
				break;
			case 701: {} // float8
				*(long long *)valuePtr = NSSwapBigLongLongToHost(*(long long *)valuePtr);
				value = [NSNumber numberWithDouble:*(double *)valuePtr];
				break;
			case 1114: {} // timestamp
			case 1184: {} // timestamptz
				*(long long *)valuePtr = NSSwapBigLongLongToHost(*(long long *)valuePtr);
				NSTimeInterval interval = *(NSTimeInterval *)valuePtr;
				interval -= 31622400.0;												// adjust for Postgres' reference date of 1/1/2000
				value = [NSDate dateWithTimeIntervalSinceReferenceDate:interval];
				break;
			default:
				value = [NSString stringWithCString:valuePtr encoding:NSUTF8StringEncoding];
				break;
		}
	}
	else value = [NSString stringWithCString:valuePtr encoding:NSUTF8StringEncoding];
	
	return value;
}

- (ExecStatusType)status
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
	ExecStatusType status = PQresultStatus(result);

	NSString *reason = [[[NSString alloc] initWithCString:PQresultErrorMessage(result) encoding:NSUTF8StringEncoding] autorelease];
	
	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
						  NSStringFromPGresultStatus(status), NSLocalizedDescriptionKey,
						  reason, NSLocalizedRecoverySuggestionErrorKey,
						  reason, NSLocalizedFailureReasonErrorKey,
						  nil];
	
	return [NSError errorWithDomain:PostgreSQLErrorDomain code:status userInfo:info];
}


#if 0
/* Accessor functions for PGresult objects */
extern ExecStatusType PQresultStatus(const PGresult *res);
extern char *PQresStatus(ExecStatusType status);
extern char *PQresultErrorMessage(const PGresult *res);
extern char *PQresultErrorField(const PGresult *res, int fieldcode);
extern int	PQntuples(const PGresult *res);
extern int	PQnfields(const PGresult *res);
extern int	PQbinaryTuples(const PGresult *res);
extern char *PQfname(const PGresult *res, int field_num);
extern int	PQfnumber(const PGresult *res, const char *field_name);
extern Oid	PQftable(const PGresult *res, int field_num);
extern int	PQftablecol(const PGresult *res, int field_num);
extern int	PQfformat(const PGresult *res, int field_num);
extern Oid	PQftype(const PGresult *res, int field_num);
extern int	PQfsize(const PGresult *res, int field_num);
extern int	PQfmod(const PGresult *res, int field_num);
extern char *PQcmdStatus(PGresult *res);
extern char *PQoidStatus(const PGresult *res);	/* old and ugly */
extern Oid	PQoidValue(const PGresult *res);	/* new and improved */
extern char *PQcmdTuples(PGresult *res);
extern char *PQgetvalue(const PGresult *res, int tup_num, int field_num);
extern int	PQgetlength(const PGresult *res, int tup_num, int field_num);
extern int	PQgetisnull(const PGresult *res, int tup_num, int field_num);
extern int	PQnparams(const PGresult *res);
extern Oid	PQparamtype(const PGresult *res, int param_num);

/* Describe prepared statements and portals */
extern PGresult *PQdescribePrepared(PGconn *conn, const char *stmt);
extern PGresult *PQdescribePortal(PGconn *conn, const char *portal);
extern int	PQsendDescribePrepared(PGconn *conn, const char *stmt);
extern int	PQsendDescribePortal(PGconn *conn, const char *portal);

/* Delete a PGresult */
extern void PQclear(PGresult *res);
#endif