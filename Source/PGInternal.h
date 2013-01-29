/*
 *  PGInternal.h
 *  PGCocoa
 *
 *  Created by Aaron Burghardt on 8/30/08.
 *  Copyright 2008. All rights reserved.
 *
 */

#import <Foundation/Foundation.h>
#import <libpq-fe.h>

// libpq binary format for numeric types. Always sent big-endian.
typedef struct pg_numeric {
	int16_t  count;
	int16_t  exponent;
#ifdef __LITTLE_ENDIAN__
	uint16_t unknown1:6;
	uint16_t negative:1;
	uint16_t unknown2:9;
#else
	// untested
	uint16_t unknown1:14;
	uint16_t negative:1;
	uint16_t unknown2:1;
#endif
	uint16_t scale;
	uint16_t mantissa[];
} pg_numeric_t;


typedef union pg_value {
	void *   addr;
	char     bytes[16];  // same length as long double
//	char     bytes[8];
	int16_t  val16;
	int32_t  val32;
	int64_t  val64;
	char *   string;
	float    f;
	double   d;
	long double ld;
	pg_numeric_t numeric;
	unsigned int oid;	// Same as Oid
} pg_value_t;

typedef	union pg_valueref {
	char    *string;
	uint8_t *bytes;
	int16_t *val16;
	int32_t *val32;
	int64_t *val64;
	pg_numeric_t *numeric;
} pg_valueref_t;

#pragma mark - 

void NSDecimalInit(NSDecimal *dcm, uint64_t mantissa, int8_t exp, BOOL isNegative);

id NSObjectFromPGBinaryValue(char *bytes, int length, Oid oid);

NSDecimalNumber * NSDecimalNumberFromBinaryNumeric(pg_numeric_t *numeric);
