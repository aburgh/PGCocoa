//
//  pgtest.m
//  PGCocoa
//
//  Created by Aaron Burghardt on 8/12/08.
//  Copyright 2008 No Company. All rights reserved.
//


#import <PGCocoa/PGConnection.h>
#import <PGCocoa/PGResult.h>
#import <PGCocoa/PGPreparedQuery.h>


void simpleTest(PGConnection *conn)
{
	//	PGResult *result = [conn executeQuery:@"select * from pg_tablespace;"];
	PGResult *result = [conn executeQuery:@"select * from abperson"];
	
	printf("Number of rows: %i\n", [result numberOfRows]);
	printf("Number of cols: %i\n", [result numberOfFields]);
	
	for (int i = 0; i < [result numberOfRows]; i++) {
		for (int j = 0; j < [result numberOfFields]; j++) {
			printf("Row: %i col: %i value: %s\n", i, j, [[[result valueAtRowIndex:i fieldIndex:j] description] cStringUsingEncoding:NSUTF8StringEncoding]);
		}
	}
}

void test1(PGConnection *conn)
{
	NSArray *params = [NSArray arrayWithObjects:[NSDate date], [NSDate date], [NSNumber numberWithFloat:98.62], [NSNumber numberWithDouble:10023445.98373], [@"some bytes" dataUsingEncoding:NSUTF8StringEncoding], nil];
	PGResult *result = [conn executeQuery:@"insert into testnums values ($1, $2, $3, $4, $5);" parameters:params];
	printf("Result: %s\n", [[[result error] description] UTF8String]);
}

void test2(PGConnection *conn)
{
	NSArray *params = [NSArray arrayWithObjects:[NSNumber numberWithInt:4], @"Veryl", @"Burghardt", nil];
	PGResult *result = [conn executeQuery:@"insert into abperson(rowid, first, last) values( $1, $2, $3);" parameters:params];
	printf("Result: %s\n", [[[result error] description] UTF8String]);
}

void test3(PGConnection *conn)
{
	NSArray *params = [NSArray arrayWithObjects:[NSNumber numberWithDouble:10023445.98373], nil];
	PGResult *result = [conn executeQuery:@"insert into testnums (f2) values ($1);" parameters:params];
	printf("Result: %s\n", [[[result error] description] UTF8String]);
}

void test4(PGConnection *conn)
{
	NSArray *params = [NSArray arrayWithObjects:[@"Some sample data" dataUsingEncoding:NSUTF8StringEncoding], nil];
//	NSArray *params = [NSArray arrayWithObjects:[NSData data], nil];
	PGResult *result = [conn executeQuery:@"insert into testnums (data) values ($1);" parameters:params];
	printf("Result: %s\n", [[[result error] description] UTF8String]);
}

void test5(PGConnection *conn)
{
	NSArray *params = [NSArray arrayWithObjects:[NSDate date], [NSDate date], [NSNumber numberWithFloat:98.62], [NSNumber numberWithDouble:10023445.98373], [@"some bytes" dataUsingEncoding:NSUTF8StringEncoding], nil];
//	NSArray *params = [NSArray arrayWithObjects:[NSDate date], [NSDate date], [NSNumber numberWithFloat:98.62], [NSNumber numberWithInt:1], [@"some bytes" dataUsingEncoding:NSUTF8StringEncoding], nil];
	PGPreparedQuery *query = [conn preparedQueryWithName:@"mytest"
												   query:@"insert into testnums values ($1, $2, $3, $4, $5);" 
												   types:params];
	
	[conn beginTransaction];
	
	[query bindValues:params];
	PGResult *result = [query execute];
	printf("Result: %s\n", [[[result error] description] UTF8String]);
	
	[query bindValue:[NSDate date] atIndex:1];
	[query bindValue:[NSNumber numberWithDouble:0.0] atIndex:3];
	result = [query execute];
	
	[query bindValue:[NSDate date] atIndex:1];
	[query bindValue:[NSNumber numberWithDouble:1.0] atIndex:3];
	result = [query execute];

	[conn commitTransaction];
	
	printf("Result: %s\n", [[[result error] description] UTF8String]);
}

void test6(PGConnection *conn)
{
	PGResult *result = [conn executeQuery:@"SELECT * FROM testnums;"];
	NSLog(@"Headers: %@", [[result fieldNames] componentsJoinedByString:@", "]);
}


int main(int argc, char *argv[]) 
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:@"test", PGConnectionParameterDatabaseNameKey, nil];
	PGConnection *conn = [[PGConnection alloc] initWithParameters:params];
	
	if (![conn connect]) goto bail;

//	simpleTest(conn);
//	test1(conn);
//	test2(conn);
//	test3(conn);
//	test4(conn);
//	test5(conn);
	test6(conn);
	
//	[conn close];
//	[conn release];
	
bail:
	[pool release];

	return 0;
}
