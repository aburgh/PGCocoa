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


+ (id)queryParametersWithValues:(NSArray *)values
{
	return  [[[PGQueryParameters alloc] initWithValues:values] autorelease];
}

- (BOOL)_allocArraysWithCapacity:(NSUInteger)numItems
{
	if (_nparams >= numItems && _types && _values && _valueRefs && _lengths && _formats)
		return YES;

	if (_types) free(_types);
	if (_values) free(_values);
	if (_valueRefs) free(_valueRefs);
	if (_lengths) free(_lengths);
	if (_formats) free(_formats);

	_types     = calloc(numItems, sizeof(Oid));
	_values    = calloc(numItems, sizeof(pg_value_t));
	_valueRefs = calloc(numItems, sizeof(char *));
	_lengths   = calloc(numItems, sizeof(int));
	_formats   = calloc(numItems, sizeof(int));
	_nparams = numItems;

	return (_types && _values && _valueRefs && _lengths && _formats);
}

-(id)initWithValues:(NSArray *)values
{
	if (self = [super init]) {
		_params = [values mutableCopy];
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

- (void)_bindValue:(id)value atIndex:(NSUInteger)i;
{
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
		NSData *data = (NSData *)value;
		_types[i] = kPGQryParamData;  // bytea
		_valueRefs[i] = data.bytes;
		_lengths[i] = data.length;
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
		NSNumber *number = (NSNumber *)value;

		const char *objCType = [value objCType];
		switch (objCType[0]) {
			case 'c':
				_types[i] = kPGQryParamInt8;  // char
				_values[i].val8 = number.charValue;
				_lengths[i] = 1;
				_formats[i] = 1;
			case 's':
				_types[i] = kPGQryParamInt16; // int2
				_values[i].val16 = NSSwapHostShortToBig(number.shortValue);
				_lengths[i] = 2;
				break;
			case 'i':
				_types[i] = kPGQryParamInt32; // int4
				_values[i].val32 = NSSwapHostIntToBig(number.intValue);
				_lengths[i] = 4;
				break;
			case 'q':
				_types[i] = kPGQryParamInt64; // int8
				_values[i].val64 = NSSwapHostLongLongToBig(number.longLongValue);
				_lengths[i] = 8;
				break;
			case 'f':
				_types[i] = kPGQryParamFloat; // float4
				// store as float but swap as long long to prevent converting swap result to a float
				_values[i].f = number.floatValue;
				_values[i].val32 = NSSwapHostIntToBig(_values[i].val32);
				_lengths[i] = 4;
				break;
			case 'd':
				_types[i] = kPGQryParamDouble; // float8
				// store as double but swap as long long to prevent converting swap result to a double
				_values[i].d = number.doubleValue;
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

- (BOOL)_bindValues
{
	if ([self _allocArraysWithCapacity:_params.count] == NO)
		return NO;

	NSUInteger count = 0;

	for (id value in _params)
		[self _bindValue:value atIndex:count++];

	return YES;
}

- (NSInteger)getNumberOfTypes:(unsigned int **)types values:(const char ***)values lengths:(int **)lengths formats:(int **)formats
{
	if ([self _allocArraysWithCapacity:_params.count] == NO)
		return -1;

	if ([self _bindValues] == NO)
		return -1;
	
	*types = _types;
	*values = _valueRefs;
	*lengths = _lengths;
	*formats = _formats;

	return _nparams;
}

//- (void)setObject:(id)anObject atIndexedSubscript:(NSUInteger)index
//{
//	_params[index] = anObject;
//}
//
//- (id)objectAtIndexedSubscript:(NSUInteger)idx
//{
//	return _params[idx];
//}
//
//-(NSUInteger)count
//{
//	return _params.count;
//}

@end
