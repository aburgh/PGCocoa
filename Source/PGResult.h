//
//  PGResult.h
//  PGCocoa
//
//  Created by Aaron Burghardt on 8/12/08.
//  Copyright 2008 No Company. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "libpq-fe.h"


@interface PGResult : NSObject 
{
	PGresult *_result;
	NSArray *_fieldNames;
}

- (id)_initWithResult:(PGresult *)result;

- (NSUInteger)numberOfFields;
- (NSUInteger)numberOfRows;

- (id)valueAtRowIndex:(NSUInteger)rowNum fieldIndex:(NSUInteger)fieldNum;

- (ExecStatusType)status;
- (NSError *)error;

@end

NSError * NSErrorFromPGresult(PGresult *result);
