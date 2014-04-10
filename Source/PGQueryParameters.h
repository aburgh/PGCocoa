//
//  PGQueryParameters.h
//  PGCocoa
//
//  Created on 1/29/13.
//  Copyright (c) 2013. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import "PGQueryParameters_Private.h"

/** PG data types to which Cocoa objects can be mapped */
typedef enum {
	kPGQryParamBool        = 16,   ///< boolean
	kPGQryParamData        = 17,   ///< bytea
	kPGQryParamInt8        = 18,   ///< char
	kPGQryParamInt64       = 20,   ///< int8
	kPGQryParamInt16       = 21,   ///< int2
	kPGQryParamInt32       = 23,   ///< int4
	kPGQryParamText        = 25,   ///< text
	kPGQryParamFloat       = 700,  ///< float4
	kPGQryParamDouble      = 701,  ///< float8
	kPGQryParamVarChar     = 1043, ///< varchar
	kPGQryParamDate        = 1082, ///< date
	kPGQryParamTime        = 1083, ///< time
	kPGQryParamTimestamp   = 1114, ///< timestamp
	kPGQryParamTimestampTZ = 1184, ///< timestamptz
	kPGQryParamNumeric     = 1700  ///< numeric
} PGQueryParameterType;

@interface PGQueryParameters : NSObject
{
	NSMutableArray *_params;

	int _nparams;
	unsigned int *_types;		// Same type as Oid
	union pg_value *_values;
	const char **_valueRefs;
	int *_lengths;
	int *_formats;
}

//@property (nonatomic, readonly) NSMutableArray *params;
//@property (nonatomic, readonly) NSUInteger count;

/** Returns autoreleased instance of PGQueryParameters
 * @param values array of basic types to bind (NSString, NSNull, NSDate, NSNumber, NSDecimalNumber, NSData)
 * @return allocated and initialized instance
 */
+ (id)queryParametersWithValues:(NSArray *)values;

/** Initializes an instance of PGQueryParameters
 * @param values array of basic types to bind (NSString, NSNull, NSDate, NSNumber, NSDecimalNumber, NSData)
 * @return the initialized instance
 */
-(id)initWithValues:(NSArray *)values;

/** Return PG query parameter arrays by reference
 @param types array of Oid types
 @param values array of value pointers
 @param lengths array of value lengths
 @param formats array of value formats (0 for string, 1 for binary)
 @return the count of elements in arrays, -1 on error
 */
- (NSInteger)getNumberOfTypes:(unsigned int **)types values:(const char ***)values lengths:(int **)lengths formats:(int **)formats;

//- (void)setObject:(id)anObject atIndexedSubscript:(NSUInteger)index;
//- (id)objectAtIndexedSubscript:(NSUInteger)idx;

@end
