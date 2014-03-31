//
//  PGInternal.m
//  PGCocoa
//
//  Created by Aaron Burghardt on 1/29/13.
//  Copyright 2013. All rights reserved.
//

#import "PGInternal.h"


void NSDecimalInit(NSDecimal *dcm, uint64_t mantissa, int8_t exp, BOOL isNegative)
{
	NSDecimalNumber *object;

	object = [[NSDecimalNumber alloc] initWithMantissa:mantissa exponent:exp isNegative:isNegative];
	*dcm = object.decimalValue;
	[object release];
}

void SwapBigBinaryNumericToHost(pg_numeric_t *pgdata)
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

id NSObjectFromPGBinaryValue(char *bytes, int length, Oid oid)
{
	id value;
	pg_valueref_t pgval;
	long double interval;
	int32_t tmp32;
	int64_t tmp64;

	pgval.string = bytes;

	switch (oid) {
		case 16: // bool
			value = [NSNumber numberWithBool:(pgval.bytes[0] == 't')  ?  YES : NO];
			break;
		case 17:  // bytea
			value = [NSData dataWithBytes:pgval.bytes length:length];
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
			tmp32 = NSSwapBigIntToHost(*pgval.val32);
			value = [NSNumber numberWithFloat: *(float *) &tmp32];
			break;
		case 701:  // float8
			tmp64 = NSSwapBigLongLongToHost(*pgval.val64);
			value = [NSNumber numberWithDouble: *(double *) &tmp64];
			break;
		case 1114:  // timestamp
		case 1184:  // timestamptz
			// The default storage for timestamps in PostgreSQL 8.4 is int64 in microseconds. Prior to
			// 8.4, the default was a double, and is still a compile-time option. Supporting floats
			// is an exercise for the reader. Hint: the integer_datetimes connection parameter reflects
			// the server's setting.

			tmp64 = NSSwapBigLongLongToHost(*pgval.val64);
			interval = tmp64;
			interval /= 1000000.0;
			interval -= 31622400.0; // adjust for Postgres' reference date of 1/1/2000
			value = [NSDate dateWithTimeIntervalSinceReferenceDate:interval];
			break;
		case 1700:  // numeric
			value = NSDecimalNumberFromBinaryNumeric(pgval.numeric);
			break;
		default:
			value = [NSData dataWithBytes:pgval.bytes length:length];
			break;
	}

	return value;
}

NSDecimalNumber * NSDecimalNumberFromBinaryNumeric(pg_numeric_t *pgval)
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
