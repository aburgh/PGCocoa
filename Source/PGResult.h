//
//  PGResult.h
//  PGCocoa
//
//  Created by Aaron Burghardt on 8/12/08.
//  Copyright 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PGRow;
struct pg_result;

/** Mapped directly to ExecStatusType */
typedef enum {
	kPGResultEmptyQuery = 0,	/**< empty query string was executed */
	kPGResultCommandOK,			/**< a query command that doesn't return
								 * anything was executed properly by the
								 * backend */
	kPGResultTuplesOK,			/**< a query command that returns tuples was
								 * executed properly by the backend, PGresult
								 * contains the result tuples */
	kPGResultCopyOut,			/**< Copy Out data transfer in progress */
	kPGResultCopyIn,			/**< Copy In data transfer in progress */
	kPGResultBadResponse,		/**< an unexpected response was recv'd from the
								 * backend */
	kPGResultNonFatalError,		/**< notice or warning message */
	kPGResultFatalError,		/**< query failed */
	kPGResultCopyBoth			/**< Copy In/Out data transfer in progress */
} PGExecStatusType;

@interface PGResult : NSObject <NSFastEnumeration>
{
	struct pg_result *_result;
	NSArray *_fieldNames;
}

@property (readonly) NSArray *fieldNames;
@property (readonly) NSUInteger numberOfFields;
@property (readonly) NSUInteger numberOfRows;
@property (readonly) NSArray *rows;
@property (readonly) PGExecStatusType status;
@property (readonly) NSError *error;

- (id)_initWithResult:(struct pg_result *)result;

- (PGRow *)rowAtIndex:(NSUInteger)index;
- (PGRow *)objectAtIndexedSubscript:(NSUInteger)idx;

- (id)valueAtRowIndex:(NSUInteger)rowNum fieldIndex:(NSUInteger)fieldNum;
- (NSUInteger)indexForFieldName:(NSString *)name;

@end
