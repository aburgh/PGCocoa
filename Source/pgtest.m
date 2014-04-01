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

void simpleTest(PGConnection *conn)
{
	//	PGResult *result = [conn executeQuery:@"select * from pg_tablespace;"];
	PGResult *result = [conn executeQuery:@"SELECT * FROM person"];

	printf("%s:\n", __func__);
	printf("\tNumber of rows: %li\n", result.numberOfRows);
	printf("\tNumber of cols: %li\n", result.numberOfFields);
	
	for (int i = 0; i < [result numberOfRows]; i++) {
		for (int j = 0; j < [result numberOfFields]; j++) {
			printf("\tRow: %i col: %i value: %s\n", i, j, [[[result valueAtRowIndex:i fieldIndex:j] description] cStringUsingEncoding:NSUTF8StringEncoding]);
		}
	}
}

// ****************

static NSString * qry_test1 = @"insert into testnums values ($1, $2, $3, $4, $5);";

void test1(PGConnection *conn)
{
	NSDate *now;
	NSData *data;
	NSArray *values;
	PGResult *result;
	PGQueryParameters *params;

	printf("%s:\n", __func__);

	now = [NSDate date];
	data = [@"some bytes" dataUsingEncoding:NSUTF8StringEncoding];
	values = @[now, now, @(98.62f), @(10023445.98373), data];
	params = [PGQueryParameters queryParametersWithValues:values];
	result = [conn executeQuery:qry_test1 parameters:params];

	if (result.status != kPGResultCommandOK)
		warnx("%s: result: %s\n", __func__, result.error.description.UTF8String);
}


// ****************

static NSString *qry_test2 = @"INSERT INTO person(id, first, last) VALUES($1, $2, $3);";

void test2(PGConnection *conn)
{
	NSArray *values;
	PGQueryParameters *params;
	PGResult *result;

	printf("%s:\n", __func__);

	values = @[@(4), @"John", @"Doe"];
	params = [PGQueryParameters queryParametersWithValues:values];
	result = [conn executeQuery:qry_test2 parameters:params];

	if (result.status != kPGResultCommandOK)
		warnx("%s: result: %s\n", __func__, result.error.description.UTF8String);
}

// ****************

static NSString *qry_test3 = @"insert into testnums (f2) values ($1);";

void test3(PGConnection *conn)
{
	printf("%s:\n", __func__);

	NSArray *values = @[ @(10023445.98373) ];
	PGQueryParameters *params = [PGQueryParameters queryParametersWithValues:values];

	PGResult *result = [conn executeQuery:qry_test3 parameters:params];

	if (result.status != kPGResultCommandOK)
		warnx("%s: result: %s\n", __func__, result.error.description.UTF8String);
}

// ****************

static NSString *qry_test4 = @"insert into testnums (data) values ($1);";

void test4(PGConnection *conn)
{
	printf("%s:\n", __func__);

	NSArray *values = @[[@"Some sample data" dataUsingEncoding:NSUTF8StringEncoding]];
	PGQueryParameters *params = [PGQueryParameters queryParametersWithValues:values];

	PGResult *result = [conn executeQuery:qry_test4 parameters:params];

	if (result.status != kPGResultCommandOK)
		warnx("%s: result: %s\n", __func__, result.error.description.UTF8String);
}

// ****************

void test5(PGConnection *conn)
{
	printf("%s:\n", __func__);

	PGQueryParameterType types[] = { kPGQryParamTimestampTZ, kPGQryParamTimestampTZ, kPGQryParamFloat, kPGQryParamDouble, kPGQryParamData };

	PGPreparedQuery *query;
	query = [PGPreparedQuery queryWithName:@"test5"
											 sql:@"insert into testnums values ($1, $2, $3, $4, $5);"
											 types:types
											 count:5
										connection:conn];

	if (!query) {
		syslog(LOG_DEBUG, "%s: error preparing query: %s", __func__, conn.errorMessage.UTF8String);
		return;
	}


	if ([conn beginTransaction] == NO) {
		syslog(LOG_DEBUG, "%s: begin transaction: %s", __func__, conn.errorMessage.UTF8String);
		[query deallocate];
		return;
	};

	// execute query

	NSArray *values = @[NSDate.date, NSDate.date, [NSNumber numberWithFloat:98.62], [NSNumber numberWithDouble:10023445.98373], [@"some bytes" dataUsingEncoding:NSUTF8StringEncoding]];

	PGQueryParameters *params = [PGQueryParameters queryParametersWithValues:values];

	PGResult *result = [query executeWithParameters:params];
	if (result.status != kPGResultCommandOK)
		warnx("%s: result: %s\n", __func__, result.error.description.UTF8String);

	params[1] = [NSDate date];
	params[3] = @(0.0);
	result = [query executeWithParameters:params];
	if (result.status != kPGResultCommandOK)
		warnx("%s: result: %s\n", __func__, result.error.description.UTF8String);
	sleep(1);

	params[1] = [NSDate date];
	params[3] = @(1.0);
	result = [query executeWithParameters:params];
	if (result.status != kPGResultCommandOK)
		warnx("%s: result: %s\n", __func__, result.error.description.UTF8String);
	sleep(2);

	params[1] = [NSDate date];
	params[3] =@(2.0);
	result = [query executeWithParameters:params];
	if (result.status != kPGResultCommandOK)
		warnx("%s: result: %s\n", __func__, result.error.description.UTF8String);

	if ([conn commitTransaction] == NO) {
		syslog(LOG_DEBUG, "commit transaction: %s", conn.errorMessage.UTF8String);
		[query deallocate];
		return;
	};

	if (result.status != kPGResultCommandOK)
		warnx("%s: result: %s\n", __func__, result.error.description.UTF8String);
}

void test6(PGConnection *conn)
{
	printf("%s:\n", __func__);

	PGResult *result = [conn executeQuery:@"SELECT * FROM testnums;"];
	printf("\tHeaders: %s\n", [[result.fieldNames componentsJoinedByString:@", "] UTF8String]);
	printf("\tResult:  %s\n", result.error.description.UTF8String);
}

void test7(PGConnection *conn)
{
	PGResult *result = [conn executeQuery:@"SELECT * FROM testnums;" parameters:nil];

	printf("%s:\n", __func__);
	printf("\t%s\n", [[result.fieldNames componentsJoinedByString:@"\t"] UTF8String]);
	
	for (int i = 0; i < result.numberOfRows; i++) {
		putchar('\t');
		for (int j = 0; j < result.numberOfFields; j++)
			printf("%s\t", [[[result valueAtRowIndex:i fieldIndex:j] description] UTF8String]);
		putchar('\n');
	}
}

void test8(PGConnection *conn)
{
	PGResult *result = [conn executeQuery:@"SELECT * FROM testnums;" parameters:nil];
	PGRow *row;
	NSObject *field;

	printf("%s:\n", __func__);
	printf("\t%s\n", [[result.fieldNames componentsJoinedByString:@"\t"] UTF8String]);

//	for (int i = 0; i < result.numberOfRows; i++) {
//		row = result[i];
//		for (int j = 0; j < result.numberOfFields; j++)
//			printf("%s\t", [[row[j] description] UTF8String]);
//		printf("\n");
//	}
	for (row in result) {
		for (field in row)
			printf("\t%s\t", field.description.UTF8String);
		printf("\n");
	}
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

static NSString *table_testnums = @"CREATE TABLE testnums (d1 TIMESTAMP, d2 TIMESTAMPTZ, f1 FLOAT, f2 DOUBLE PRECISION, data BYTEA);";
static NSString *table_person = @"CREATE TABLE person (id SERIAL PRIMARY KEY, first TEXT, last TEXT);";

int main(int argc, char *argv[]) 
{
	openlog("pgtest",  LOG_PERROR | LOG_CONS, LOG_USER);

	@autoreleasepool {
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
//		values = @[[NSDate date], [NSDate date], @(98.62f), @(10023445.98373), [@"some bytes" dataUsingEncoding:NSUTF8StringEncoding]];

		PGResult *result;
		result = [conn executeQuery:table_testnums];
		result = [conn executeQuery:table_person];

		simpleTest(conn);
		putchar('\n');

		test1(conn);
		putchar('\n');

		test2(conn);
		putchar('\n');

		test3(conn);
		putchar('\n');

		test4(conn);
		putchar('\n');

		test5(conn);
		putchar('\n');

		test6(conn);
		putchar('\n');

		test7(conn);
		putchar('\n');

		test8(conn);
		putchar('\n');
bail:
		DropTable(conn, @"testnums");
		DropTable(conn, @"person");
		[conn rollbackTransaction];
		[conn disconnect];
		[conn release];
	}

	return 0;
}
