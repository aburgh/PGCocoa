//
//  PGResult.h
//  PGCocoa
//
//  Created by Aaron Burghardt on 8/12/08.
//  Copyright 2008 No Company. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "libpq-fe.h"


@interface PGResult : NSObject <NSFastEnumeration>
{
	PGresult *_result;
	NSArray *_fieldNames;
}

@property (readonly) NSArray *fieldNames;
@property (readonly) NSUInteger numberOfFields;
@property (readonly) NSUInteger numberOfRows;
@property (readonly) NSArray *rows;
@property (readonly) ExecStatusType status;
@property (readonly) NSError *error;

- (id)_initWithResult:(PGresult *)result;

- (id)valueAtRowIndex:(NSUInteger)rowNum fieldIndex:(NSUInteger)fieldNum;
- (NSUInteger)indexForFieldName:(NSString *)name;

@end

NSString * NSStringFromPGresultStatus(ExecStatusType status);
NSError * NSErrorFromPGresult(PGresult *result);
