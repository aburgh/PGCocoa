//
//  pgtest.m
//  PGCocoa
//
//  Created by Aaron Burghardt on 8/12/08.
//  Copyright 2008. All rights reserved.
//


#import <PGCocoa/PGConnection.h>
#import <PGCocoa/PGResult.h>
#import <PGCocoa/PGPreparedQuery.h>
#import <PGCocoa/PGRow.h>
#import <err.h>
#import <errno.h>
#import <syslog.h>

static NSString *table_ints   = @"CREATE TEMP TABLE ints (val1 BOOLEAN, val16 SMALLINT, val32 INTEGER, val64 BIGINT);";
static NSString *table_floats = @"CREATE TEMP TABLE floats (val4 FLOAT4, val8 DOUBLE PRECISION, val15 DECIMAL(30, 5));";
static NSString *table_times  = @"CREATE TEMP TABLE times (val_ts TIMESTAMP, val_tz TIMESTAMPTZ);";
static NSString *table_arrays = @"CREATE TEMP TABLE arrays (val_text TEXT, val_bytes BYTEA);";

static NSString *qryInsertInts   = @"INSERT INTO ints (val1, val16, val32, val64) VALUES ($1, $2, $3, $4);";
static NSString *qryInsertFloats = @"INSERT INTO floats (val4, val8, val15) VALUES ($1, $2, $3);";
static NSString *qryInsertTimes  = @"INSERT INTO times (val_ts, val_tz) VALUES ($1::timestamp, $2::timestamptz);";
static NSString *qryInsertData   = @"INSERT INTO arrays (val_text, val_bytes) VALUES ($1, $2);";

static NSString *qrySelectInts   = @"SELECT * FROM ints;";
static NSString *qrySelectFloats = @"SELECT * FROM floats;";
static NSString *qrySelectTimes  = @"SELECT * FROM times;";
static NSString *qrySelectData   = @"SELECT * FROM arrays;";

static NSString *qryDeleteInts   = @"DELETE FROM ints;";
static NSString *qryDeleteFloats = @"DELETE FROM floats;";
static NSString *qryDeleteTimes  = @"DELETE FROM times;";
static NSString *qryDeleteData   = @"DELETE FROM arrays;";


void TestInts(PGConnection *conn)
{
	printf("%s:\n", __func__);

	PGResult *result;
	NSArray *values;
	PGRow *row;

	values = @[ @(YES), @(32000), @(123456789), @(12345678901234) ];

	result = [conn executeQuery:qryInsertInts values:values];
	if (result.status != kPGResultCommandOK)
		errx(EXIT_FAILURE, "%s", result.error.description.UTF8String);

	result = [conn executeQuery:qrySelectInts];
	if (result.status != kPGResultTuplesOK)
		errx(EXIT_FAILURE, "%s", result.error.description.UTF8String);

	row = result[0];
	NSCAssert([row[0] isEqual:@(YES)], @"[row[0] isEqual:@(YES)]");
	NSCAssert([row[1] isEqual:@(32000)], @"[row[1] isEqual:@(32000)]");
	NSCAssert([row[2] isEqual:@(123456789)], @"[row[2] isEqual:@(123456789)]");
	NSCAssert([row[3] isEqual:@(12345678901234)], @"[row[3] isEqual:@(12345678901234)]");

	[conn executeQuery:qryDeleteInts];
}

void TestFloats(PGConnection *conn)
{
	printf("%s:\n", __func__);

	PGResult *result;
	NSArray *values;
	NSDecimalNumber *decimal1, *decimal2;
	PGRow *row;

	decimal1 = [NSDecimalNumber decimalNumberWithString:@"1234567890.12345"];
	values = @[ @(123.456), @(1234567890.12345), decimal1 ];

	result = [conn executeQuery:qryInsertFloats values:values];
	if (result.status != kPGResultCommandOK)
		errx(EXIT_FAILURE, "%s", result.error.description.UTF8String);

	decimal2 = [NSDecimalNumber decimalNumberWithString:@"-1234567890.1234e15"];
	values = @[ @(-1.2345e10), @(-1234567890.12345), decimal2];

	result = [conn executeQuery:qryInsertFloats values:values];
	if (result.status != kPGResultCommandOK)
		errx(EXIT_FAILURE, "%s", result.error.description.UTF8String);


	result = [conn executeQuery:qrySelectFloats];
	if (result.status != kPGResultTuplesOK)
		errx(EXIT_FAILURE, "%s", result.error.description.UTF8String);

	row = result[0];
	NSCAssert( [[row[0] description] isEqual:@"123.456"], @"row[0] ~ 123.456");
	NSCAssert( [[row[1] description] isEqual:@"1234567890.12345"], @"row[1] ~ 1234567890.12345");
	NSCAssert( [[row[2] description] isEqual:@"1234567890.12345"], @"row[2] ~ 1234567890.12345");

	row = result[1];
	NSCAssert( [[row[0] description] isEqual:@"-1.2345e+10"], @"row[0] ~ -1.2345e+10");
	NSCAssert( [[row[1] description] isEqual:@"-1234567890.12345"], @"row[1] ~ -1234567890.12345");
	NSCAssert( [[row[2] description] isEqual:@"-1234567890123400000000000"], @"row[2] ~ -1234567890123400000000000");

}

void TestTimes(PGConnection *conn)
{
	printf("%s:\n", __func__);

	PGResult *result;
	PGRow *row;
	NSDate *now, *date1, *date2;
	NSString *date3, *date4;
	NSTimeZone *gmt;
	NSArray *values;
	PGQueryParameters *params;
	NSString *desc1, *desc2;

	// insert row 1

	now = [NSDate date];
	values = @[ now, now ];

	result = [conn executeQuery:qryInsertTimes values:values];
	if (result.status != kPGResultCommandOK)
		errx(EXIT_FAILURE, "%s", result.error.description.UTF8String);

	// insert row 2

	date3 = @"2013-01-15 23:59:59";

	values = @[ date3, date3 ];
	result = [conn executeQuery:qryInsertTimes values:values];
	if (result.status != kPGResultCommandOK)
		errx(EXIT_FAILURE, "%s", result.error.description.UTF8String);

	// insert row 3

	date4 = @"2013-01-15 23:59:59 +0000";

	values = @[ date4, date4 ];
	result = [conn executeQuery:qryInsertTimes values:values];
	if (result.status != kPGResultCommandOK)
		errx(EXIT_FAILURE, "%s", result.error.description.UTF8String);

	// insert row 4

	date1 = [NSDate dateWithTimeIntervalSinceReferenceDate:0.0]; // 1/1/2001

	values = @[ date1, date1 ];
	result = [conn executeQuery:qryInsertTimes values:values];
	if (result.status != kPGResultCommandOK)
		errx(EXIT_FAILURE, "%s", result.error.description.UTF8String);


	// fetch rows

	result = [conn executeQuery:qrySelectTimes];
	if (result.status != kPGResultTuplesOK)
		errx(EXIT_FAILURE, "%s", result.error.description.UTF8String);

	gmt = [NSTimeZone timeZoneWithName:@"GMT"];

	for (row in result) {
		desc1 = [row[0] descriptionWithCalendarFormat:nil timeZone:gmt locale:nil];
		desc2 = [row[1] descriptionWithCalendarFormat:nil timeZone:gmt locale:nil];
		printf("%s\n", desc1.UTF8String);
		printf("%s\n", desc2.UTF8String);
		putchar('\n');
	}
//TestTimes:
//	2014-04-09 16:34:24 +0000
//	2014-04-09 20:34:24 +0000
//
//	2013-01-15 23:59:59 +0000
//	2013-01-16 04:59:59 +0000
//
//	2013-01-15 23:59:59 +0000
//	2013-01-15 23:59:59 +0000
//
//	2000-12-31 19:00:00 +0000
//	2001-01-01 00:00:00 +0000
//	
}

void TestArrays(PGConnection *conn)
{
	printf("%s:\n", __func__);

	PGResult *result;
	PGRow *row;
	NSData *data;
	NSArray *values;
	PGQueryParameters *params;

	data = [@"This is some data" dataUsingEncoding:NSUTF8StringEncoding];
	values = @[ NSNull.null, data ];
	result = [conn executeQuery:qryInsertData values:values];
	if (result.status != kPGResultCommandOK)
		errx(EXIT_FAILURE, "%s", result.error.description.UTF8String);

	result = [conn executeQuery:qrySelectData];
	if (result.status != kPGResultTuplesOK)
		errx(EXIT_FAILURE, "%s", result.error.description.UTF8String);

	row = result[0];
	NSCAssert([row[1] isEqual:data], @"row[1] == data");
}

void TestPreparedInts(PGConnection *conn)
{
	printf("%s:\n", __func__);

	PGResult *result;
	PGPreparedQuery *query;
	PGRow *row;
	NSArray *values;

	query = [PGPreparedQuery queryWithName:@"test" sql:qryInsertInts types:nil connection:conn];
	if (!query)
		errx(EXIT_FAILURE, "prepare: %s", conn.error.description.UTF8String);

	values = @[ @(YES), @((short)32000), @(123456789), @(12345678901234) ];

	result = [query executeWithValues:values];
	if (result.status != kPGResultCommandOK)
		errx(EXIT_FAILURE, "%s", result.error.description.UTF8String);

	result = [conn executeQuery:qrySelectInts];
	if (result.status != kPGResultTuplesOK)
		errx(EXIT_FAILURE, "%s", result.error.description.UTF8String);

	row = result[0];
	NSCAssert([row[0] isEqual:@(YES)], @"[row[0] isEqual:@(YES)]");
	NSCAssert([row[1] isEqual:@(32000)], @"[row[1] isEqual:@(32000)]");
	NSCAssert([row[2] isEqual:@(123456789)], @"[row[2] isEqual:@(123456789)]");
	NSCAssert([row[3] isEqual:@(12345678901234)], @"[row[3] isEqual:@(12345678901234)]");

	[conn executeQuery:qryDeleteInts];

	[query deallocate];
}

void CreateTable(PGConnection *conn, NSString *qry)
{
	PGResult *result;
	result = [conn executeQuery:qry];

	if (result.status != kPGResultCommandOK)
		err(EXIT_FAILURE, "%s", result.error.description.UTF8String);
}

void DropTable(PGConnection *conn, NSString *name)
{
	PGResult *result;
	NSString *qry;

	qry = [NSString stringWithFormat:@"DROP TABLE %@;", name];

	result = [conn executeQuery:qry];
	if (result.status != kPGResultCommandOK)
		warnx("drop table '%s': %s", name.UTF8String, result.error.description.UTF8String);
}

int main(int argc, char *argv[])
{

//	openlog("pgtest",  LOG_PERROR | LOG_CONS, LOG_USER);

	@autoreleasepool {
		PGResult *result;
		PGConnection *conn;
		NSDictionary *params;
		NSArray *values;
		NSData *data;

		params = @{ PGConnectionParameterDatabaseNameKey:@"test", PGConnectionParameterHostKey:@"/tmp" };
		conn = [[PGConnection alloc] initWithParameters:params];

		if (![conn connect]) {
			syslog(LOG_ERR, "connect: %s", conn.errorMessage.UTF8String);
			goto bail;
		}

		[conn beginTransaction];

		CreateTable(conn, table_ints);
		CreateTable(conn, table_floats);
		CreateTable(conn, table_times);
		CreateTable(conn, table_arrays);

//		TestInts(conn);
//		putchar('\n');
//
//		TestFloats(conn);
//		putchar('\n');
//
//		TestTimes(conn);
//		putchar('\n');
//
//		TestArrays(conn);
//		putchar('\n');
//
		TestPreparedInts(conn);
		putchar('\n');

bail:
		DropTable(conn, @"ints");
		DropTable(conn, @"floats");
		DropTable(conn, @"times");
		DropTable(conn, @"arrays");

		[conn commitTransaction];
//		[conn rollbackTransaction];
		[conn disconnect];
		[conn release];
	}

	return 0;
}
