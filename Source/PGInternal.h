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

#define NBASE 10000

#define NUMERIC_POS    0X0000
#define NUMERIC_NEG    0x4000
#define NUMERIC_NAN    0xC000
#define NUMERIC_NULL   0xF000

// libpq binary format for numeric types. Always sent big-endian.
typedef struct pg_numeric {
	int16_t  ndigits;
	int16_t  nweight;
	uint16_t negative;
	uint16_t dscale;
	uint16_t digits[10]; // Limited by NSDecimal's use of uint128_t for mantissa
} pg_numeric_t;


typedef union pg_value {
	void *   addr;
	char     bytes[16];  // same length as long double
//	char     bytes[8];
	int8_t   val8;
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

NSDecimalNumber * NSDecimalNumberFromNumeric(pg_numeric_t *numeric);

pg_numeric_t * NumericFromNSDecimalNumber(NSDecimalNumber *value);