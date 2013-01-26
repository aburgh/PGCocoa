//
//  PGRow.m
//  PGCocoa
//
//  Created by Aaron Burghardt on 9/16/09.
//  Copyright 2009. All rights reserved.
//

#import "PGRow.h"
#import "PGResult.h"


@implementation PGRow

@synthesize result;
@synthesize rowNumber;

- (id)_initWithResult:(PGResult *)parent rowNumber:(NSInteger)index
{
	if (self = [super init]) {
		_result = [parent retain];
		_rowNumber = index;
	}
	return self;
}

- (void)dealloc
{
	[_result release];
	[super dealloc];
}

- (id)valueAtFieldIndex:(NSInteger)index
{
	return [_result valueAtRowIndex:rowNumber fieldIndex:index];
}

- (id)valueForKey:(NSString *)key
{
	NSInteger index = [_result indexForFieldName:key];
	
	if (index == -1)
		return [super valueForKey:key];
	
	return [_result valueAtRowIndex:rowNumber fieldIndex:index];
}

@end
