//
//  pgtest.m
//  PGCocoa
//
//  Created by Aaron Burghardt on 8/12/08.
//  Copyright 2008 No Company. All rights reserved.
//


#import <PGCocoa/PGConnection.h>
#import <PGCocoa/PGResult.h>


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


void test2(PGConnection *conn)
{
	NSArray *params = [NSArray arrayWithObjects:[NSNumber numberWithInt:4], @"Veryl", @"Burghardt", nil];
	PGResult *result = [conn executeQuery:@"insert into abperson(rowid, first, last) values( $1, $2, $3);" parameters:params];
	printf("Result: %s\n", [[[result error] description] UTF8String]);
}

int main(int argc, char *argv[]) 
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:@"test", @"dbname", nil];
	PGConnection *conn = [[PGConnection alloc] initWithParameters:params];
	
	if (![conn connect]) goto bail;

//	simpleTest(conn);
	test2(conn);
	
//	[conn close];
//	[conn release];
	
bail:
	[pool release];

	return 0;
}
