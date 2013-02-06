//
//  PGQueryParameters.h
//  PGCocoa
//
//  Created on 1/29/13.
//  Copyright (c) 2013. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
	kPGQryParamBool        = 16,   // boolean
	kPGQryParamData        = 17,   // bytea
	kPGQryParamInt8        = 18,   // char
	kPGQryParamInt64       = 20,   // int8
	kPGQryParamInt16       = 21,   // int2
	kPGQryParamInt32       = 23,   // int4
	kPGQryParamText        = 25,   // text
	kPGQryParamFloat       = 700,  // float4 = 700
	kPGQryParamDouble      = 701,  // float8 = 701
	kPGQryParamVarChar     = 1043, // varchar
	kPGQryParamDate        = 1082, // date
	kPGQryParamTime        = 1083, // time
	kPGQryParamTimestamp   = 1114, // timestamp   == 1114
	kPGQryParamTimestampTZ = 1184, // timestamptz == 1184
	kPGQryParamNumeric     = 1700  // numeric
} PGQueryParameterType;

@interface PGQueryParameters : NSObject
{
	NSMutableArray *_params;

	unsigned int *_types;		// Same type as Oid
	union pg_value *_values;
	const char **_valueRefs;
	int *_lengths;
	int *_formats;
}

@property (nonatomic, readonly) NSUInteger count;

+ (id)queryParametersWithCapacity:(NSUInteger)count;

+ (id)queryParametersWithValues:(NSArray *)values;

- (void)bindValue:(id)value atIndex:(NSUInteger)paramIndex;

- (void)bindValues:(NSArray *)values;

@end