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
			value = [NSNumber numberWithBool:pgval.bytes[0]];
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
			value = NSDecimalNumberFromNumeric(pgval.numeric);
			break;
		default:
			value = [NSData dataWithBytes:pgval.bytes length:length];
			break;
	}

	return value;
}

NSDecimalNumber * NSDecimalNumberFromNumeric(pg_numeric_t *pgval)
{
	NSDecimal decimal;
	pg_numeric_t numeric;
	__uint128_t mantissa;

	numeric.ndigits  = NSSwapBigShortToHost(pgval->ndigits);
	numeric.nweight  = NSSwapBigShortToHost(pgval->nweight);
	numeric.negative = NSSwapBigShortToHost(pgval->negative);
	numeric.dscale   = NSSwapBigShortToHost(pgval->dscale);
	for (int i = 0; i < numeric.ndigits; i++)
		numeric.digits[i] = NSSwapBigShortToHost(pgval->digits[i]);

	if (numeric.nweight > 31)
		[NSException raise:NSDecimalNumberExactnessException format:@"Exponent of value from database out of bounds"];
	if (numeric.ndigits > 9)
		[NSException raise:NSDecimalNumberExactnessException format:@"Value from database exceeds 36 digits of precision"];

	memset(&decimal, 0, sizeof(decimal));

	if (numeric.negative == NUMERIC_NULL) {
		return (id) NSNull.null;
	}
	else if (numeric.negative == NUMERIC_NAN) {
		decimal._length = 0;
		decimal._isNegative = YES;
	}
	else {
		decimal._length = 8;
		decimal._isNegative = (numeric.negative == NUMERIC_NEG);
		decimal._exponent = (numeric.nweight - (numeric.ndigits - 1)) * 4;

		mantissa = 0;
		for (int i = 0; i < numeric.ndigits; i++) {
			mantissa *= NBASE;
			mantissa += numeric.digits[i];
		}
		*(__int128_t *) &decimal._mantissa = mantissa;
	}

	return [NSDecimalNumber decimalNumberWithDecimal:decimal];
}


//#define NSDecimalMaxSize (8)
//// Give a precision of at least 38 decimal digits, 128 binary positions.
//
//#define NSDecimalNoScale SHRT_MAX
//
//typedef struct {
//    signed   int _exponent:8;
//    unsigned int _length:4;     // length == 0 && isNegative -> NaN
//    unsigned int _isNegative:1;
//    unsigned int _isCompact:1;
//    unsigned int _reserved:18;
//    unsigned short _mantissa[NSDecimalMaxSize];
//} NSDecimal;


//#if 0
//#define NBASE		10000
//#define HALF_NBASE	5000
//#define DEC_DIGITS	4			/* decimal digits per NBASE digit */
//#define MUL_GUARD_DIGITS	2	/* these are measured in NBASE digits */
//#define DIV_GUARD_DIGITS	4
//
//typedef int16_t NumericDigit;
//
//static const char *
//set_var_from_str(const char *str, const char *cp, pg_numeric_t *dest)
//{
//	bool		have_dp = FALSE;
//	int			i;
//	unsigned char *decdigits;
//	int			sign = NUMERIC_POS;
//	int			dweight = -1;
//	int			ddigits;
//	int			dscale = 0;
//	int			weight;
//	int			ndigits;
//	int			offset;
//	NumericDigit *digits;
//
//	/*
//	 * We first parse the string to extract decimal digits and determine the
//	 * correct decimal weight.	Then convert to NBASE representation.
//	 */
//	switch (*cp)
//	{
//		case '+':
//			sign = NUMERIC_POS;
//			cp++;
//			break;
//
//		case '-':
//			sign = NUMERIC_NEG;
//			cp++;
//			break;
//	}
//
//	if (*cp == '.')
//	{
//		have_dp = TRUE;
//		cp++;
//	}
//
//	if (!isdigit((unsigned char) *cp))
//		[NSException raise:NSInvalidArgumentException format:@"invalid input syntax for type numeric: \"%s\"", str];
//
//	decdigits = (unsigned char *) malloc(strlen(cp) + DEC_DIGITS * 2);
//
//	/* leading padding for digit alignment later */
//	memset(decdigits, 0, DEC_DIGITS);
//	i = DEC_DIGITS;
//
//	while (*cp)
//	{
//		if (isdigit((unsigned char) *cp))
//		{
//			decdigits[i++] = *cp++ - '0';
//			if (!have_dp)
//				dweight++;
//			else
//				dscale++;
//		}
//		else if (*cp == '.')
//		{
//			if (have_dp)
//				[NSException raise:NSInvalidArgumentException format:@"invalid input syntax for type numeric: \"%s\"", str];
//			have_dp = TRUE;
//			cp++;
//		}
//		else
//			break;
//	}
//
//	ddigits = i - DEC_DIGITS;
//	/* trailing padding for digit alignment later */
//	memset(decdigits + i, 0, DEC_DIGITS - 1);
//
//	/* Handle exponent, if any */
//	if (*cp == 'e' || *cp == 'E')
//	{
//		long		exponent;
//		char	   *endptr;
//
//		cp++;
//		exponent = strtol(cp, &endptr, 10);
//		if (endptr == cp)
//			[NSException raise:NSInvalidArgumentException format:@"invalid input syntax for type numeric: \"%s\"", str];
//		cp = endptr;
//		if (exponent > 127 ||
//			exponent < -127)
//			[NSException raise:NSInvalidArgumentException format:@"invalid input syntax for type numeric: \"%s\"", str];
//		dweight += (int) exponent;
//		dscale -= (int) exponent;
//		if (dscale < 0)
//			dscale = 0;
//	}
//
//	/*
//	 * Okay, convert pure-decimal representation to base NBASE.  First we need
//	 * to determine the converted weight and ndigits.  offset is the number of
//	 * decimal zeroes to insert before the first given digit to have a
//	 * correctly aligned first NBASE digit.
//	 */
//	if (dweight >= 0)
//		weight = (dweight + 1 + DEC_DIGITS - 1) / DEC_DIGITS - 1;
//	else
//		weight = -((-dweight - 1) / DEC_DIGITS + 1);
//	offset = (weight + 1) * DEC_DIGITS - (dweight + 1);
//	ndigits = (ddigits + offset + DEC_DIGITS - 1) / DEC_DIGITS;
//
////	alloc_var(dest, ndigits);
//	dest->ndigits = ndigits;
//	dest->negative = sign;
//	dest->nweight = weight;
//	dest->dscale = dscale;
//
//	i = DEC_DIGITS - offset;
//	digits = (NumericDigit *) dest->digits;
//
//	while (ndigits-- > 0)
//	{
//#if DEC_DIGITS == 4
//		*digits++ = ((decdigits[i] * 10 + decdigits[i + 1]) * 10 +
//					 decdigits[i + 2]) * 10 + decdigits[i + 3];
//#elif DEC_DIGITS == 2
//		*digits++ = decdigits[i] * 10 + decdigits[i + 1];
//#elif DEC_DIGITS == 1
//		*digits++ = decdigits[i];
//#else
//#error unsupported NBASE
//#endif
//		i += DEC_DIGITS;
//	}
//
//	free(decdigits);
//
//	/* Strip any leading/trailing zeroes, and normalize weight if zero */
////	strip_var(dest);
//
//	/* Return end+1 position for caller */
//	return cp;
//}
//
//#endif
//

