//
//  PGResult.m
//  PGCocoa
//
//  Created by Aaron Burghardt on 8/12/08.
//  Copyright 2008 No Company. All rights reserved.
//

#import "PGResult.h"
#import "PGConnection.h"
@implementation PGResult

- (id)_initWithResult:(PGresult *)result
{
	printf("Result command status: %s\n", PQcmdStatus(result));
	
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
	if (!_fieldNames) {
		int count = PQnfields(_result);
		NSMutableArray *names = [[NSMutableArray alloc] initWithCapacity:count];
		
		for (int i = 0; i < count; i++) {
			//		printf("Field: %s  type: %i\n", PQfname(result, i), PQftype(result, i));
			NSString *name = [[NSString alloc] initWithCString:PQfname(_result, i) encoding:NSUTF8StringEncoding];
			[names addObject:name];
			[name release];
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


- (id)valueAtRowIndex:(NSUInteger)rowNum fieldIndex:(NSUInteger)fieldNum
{
	id value;
	
	if (PQgetisnull(_result, rowNum, fieldNum)) return [NSNull null];
	
	else {
		BOOL isBinary = PQfformat(_result, fieldNum);

		if (isBinary) {
			// get Oid types with "SELECT oid, typname from pg_type;
			Oid oid = PQftype(_result, fieldNum);
			switch (oid) {
				case 16: // bool
					value = [NSNumber numberWithBool:(*(PQgetvalue(_result, rowNum, fieldNum)) == 't')  ?  YES : NO];
					break;
				case 17: // bytea
				case 18: // int8
				case 21: // int2
				case 23: // int4
					value = [NSNumber numberWithInt:(*(PQgetvalue(_result, rowNum, fieldNum)))];
					break;
				default:
					value = [NSString stringWithCString:PQgetvalue(_result, rowNum, fieldNum) encoding:NSUTF8StringEncoding];
					break;
			}
		}
		else value = [NSString stringWithCString:PQgetvalue(_result, rowNum, fieldNum) encoding:NSUTF8StringEncoding];

	}
	return value;
}

				
- (NSUInteger)numberOfRows
{
	return (NSUInteger)PQntuples(_result);
}

- (ExecStatusType)status
{
	return PQresultStatus(_result);
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

NSError * NSErrorFromPGresult(PGresult *result)
{
	NSString *desc;	
	ExecStatusType status = PQresultStatus(result);
	
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
			
	NSString *reason = [[[NSString alloc] initWithCString:PQresultErrorMessage(result) encoding:NSUTF8StringEncoding] autorelease];
	
	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
						  @"Database Error", NSLocalizedDescriptionKey,
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