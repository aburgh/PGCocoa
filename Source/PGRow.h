//
//  PGRow.h
//  PGCocoa
//
//  Created by Aaron Burghardt on 9/16/09.
//  Copyright 2009. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PGResult;

@interface PGRow : NSObject 
{
	PGResult *result;
	NSInteger rowNumber;
}

@property (retain, readonly) PGResult *result;
@property (readonly) NSInteger rowNumber;

- (id)valueAtFieldIndex:(NSInteger)index;
- (id)valueForKey:(NSString *)key;

@end
