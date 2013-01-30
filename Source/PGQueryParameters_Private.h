//
//  PGQueryParameters_Private.h
//  PGCocoa
//
//  Created by Aaron Burghardt on 1/29/13.
//
//

#import "PGQueryParameters.h"
#import "PGInternal.h"

@interface PGQueryParameters ()

@property (nonatomic, readonly) NSMutableArray *params;
@property (nonatomic, readonly) unsigned int *types;
@property (nonatomic, readonly) pg_value_t *values;
@property (nonatomic, readonly) const char **valueRefs;
@property (nonatomic, readonly) int *lengths;
@property (nonatomic, readonly) int *formats;

@end


