//
//  PGQueryParameters.m
//  PGCocoa
//
//  Created on 1/29/13.
//  Copyright (c) 2013. All rights reserved.
//

#import "PGQueryParameters.h"
#import "PGQueryParameters_Private.h"
#import "PGInternal.h"

@implementation PGQueryParameters

+ (id)queryParametersWithCapacity:(NSUInteger)numItems
{
	return [[[PGQueryParameters alloc] initWithCapacity:numItems] autorelease];
}

+ (id)queryParametersWithValues:(NSArray *)values
{
	PGQueryParameters *params = [PGQueryParameters queryParametersWithCapacity:values.count];
	[params bindValues:values];

	return params;
}

-(id)initWithCapacity:(NSUInteger)numItems
{
	if (self = [super init]) {

		_params = [[NSMutableArray alloc] initWithCapacity:numItems];
		for (int i = 0; i < numItems; i++)
			[_params addObject:[NSNull null]];
		
		_types     = calloc(numItems, sizeof(Oid));
		_values    = calloc(numItems, sizeof(pg_value_t));
		_valueRefs = calloc(numItems, sizeof(char *));
		_lengths   = calloc(numItems, sizeof(int));
		_formats   = calloc(numItems, sizeof(int));
	}

	return self;
}

- (void)dealloc
{
	[_params release];
	free(_types);
	free(_values);
	free(_valueRefs);
	free(_lengths);
	free(_formats);
	[super dealloc];
}

- (void)bindValue:(id)value atIndex:(NSUInteger)i;
{
	// This implementation copied from PGPreparedQuery

	[_params replaceObjectAtIndex:i withObject:value];

	// The default storage for timestamps in PostgreSQL 8.4 is int64 in microseconds. Prior to
	// 8.4, the default was a double, and is still a compile-time option. Supporting floats
	// is an exercise for the reader. Hint: the integer_datetimes connection parameter reflects
	// the server's setting.

	// Prefer isKindOfClass: over isMemberOfClass: to allow class clusters,
	// but check subclasses first (i.e., NSDecimalNumber before NSNumber).

	if ([value isKindOfClass:NSString.class]) {
		_types[i] = kPGQryParamText;	// text
		_valueRefs[i] = (char *)[value UTF8String];
		_lengths[i] = 0;  // ignored
		_formats[i] = 0;
	}
	else if ([value isKindOfClass:NSDate.class]) {
		_types[i] = kPGQryParamTimestampTZ; // timestamp == 1114, timestamptz == 1184

		long double interval = [value timeIntervalSinceReferenceDate]; // upcast to preserve precision
		interval += 31622400.0; // timestamp(tz) ref date == 2000-01-01 midnight
		interval *= 1000000.0;
		_values[i].val64 = interval;
		_values[i].val64 = NSSwapHostLongLongToBig(_values[i].val64);
		_valueRefs[i] = _values[i].bytes;
		_lengths[i] = 8;
		_formats[i] = 1;
	}
	else if ([value isKindOfClass:NSData.class]) {
		_types[i] = kPGQryParamData;  // bytea
		_valueRefs[i] = (char *)[value bytes];
		_lengths[i] = (int)[value length];
		_formats[i] = 1;
	}
	else if ([value class] == NSClassFromString(@"__NSCFBoolean")) {
		_types[i] = kPGQryParamBool;  // boolean
		_values[i].val8 = [value boolValue];
		_valueRefs[i] = _values[i].bytes;
		_lengths[i] = 1;
		_formats[i] = 1;
	}
	else if ([value isKindOfClass:[NSDecimalNumber class]]) {
		NSString *valString = [value description];
		[_params replaceObjectAtIndex:i withObject:valString];
		_types[i] = kPGQryParamNumeric;
		_valueRefs[i] = valString.UTF8String;
		_lengths[i] = 0;  // ignored
		_formats[i] = 0;

//		pg_numeric_t *numeric = NumericFromNSDecimalNumber(value);
//		_types[i] = kPGQryParamNumeric;
//		_values[i].numeric = *numeric;
//		_valueRefs[i] = _values[i].bytes;
//		_lengths[i] = sizeof(numeric);
//		_formats[i] = 1;
	}
	else if ([value isKindOfClass:NSNumber.class]) {

		const char *objCType = [value objCType];
		switch (objCType[0]) {
			case 'c':
				_types[i] = kPGQryParamInt8;  // char
				_values[i].val8 = [value charValue];
				_lengths[i] = 1;
				_formats[i] = 1;
			case 's':
				_types[i] = kPGQryParamInt16; // int2
				_values[i].val16 = NSSwapHostShortToBig([value shortValue]);
				_lengths[i] = 2;
				break;
			case 'i':
				_types[i] = kPGQryParamInt32; // int4
				_values[i].val32 = NSSwapHostIntToBig([value intValue]);
				_lengths[i] = 4;
				break;
			case 'q':
				_types[i] = kPGQryParamInt64; // int8
				_values[i].val64 = NSSwapHostLongLongToBig([value longLongValue]);
				_lengths[i] = 8;
				break;
			case 'f':
				_types[i] = kPGQryParamFloat; // float4
				// store as float but swap as long long to prevent converting swap result to a float
				_values[i].f = [value floatValue];
				_values[i].val32 = NSSwapHostIntToBig(_values[i].val32);
				_lengths[i] = 4;
				break;
			case 'd':
				_types[i] = kPGQryParamDouble; // float8
				// store as double but swap as long long to prevent converting swap result to a double
				_values[i].d = [value doubleValue];
				_values[i].val64 = NSSwapHostLongLongToBig(_values[i].val64);
				_lengths[i] = 8;
				break;
			default:
				[NSException raise:NSInvalidArgumentException format:@"Unsupported NSNumber objCType"];
				break;
		}

		_valueRefs[i] = _values[i].bytes;
		_formats[i] = 1;
	}
	else if (value == NSNull.null) {
		_valueRefs[i] = NULL;
		_lengths[i] = 0;  // ignored
		_formats[i] = 0;
	}
}

- (void)bindValues:(NSArray *)values;
{
	// This implementation copied from PGPreparedQuery

	NSUInteger count = values.count;

	NSAssert(_params.count == count, @"Number of values doesn't match the number of query parameters.");

	for (int i = 0; i < count; i++)
		[self bindValue:values[i] atIndex:i];
}

- (void)setObject:(id)anObject atIndexedSubscript:(NSUInteger)index
{
	[self bindValue:anObject atIndex:index];
}

- (id)objectAtIndexedSubscript:(NSUInteger)idx
{
	return _params[idx];
}

-(NSUInteger)count
{
	return _params.count;
}

@end
