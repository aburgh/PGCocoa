//
//  PGConnection.h
//  PGCocoa
//
//  Created by Aaron Burghardt on 7/14/08.
//  Copyright 2008 No Company. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "libpq-fe.h"

@class PGResult;

@interface PGConnection : NSObject 
{
	PGconn *_connection;

	NSDictionary *_params;
}

- (id)initWithParameters:(NSDictionary *)params;

- (BOOL)connect;

- (PGResult *)executeQuery:(NSString *)query;
- (PGResult *)executeQuery:(NSString *)query parameters:(NSArray *)params;

- (NSString *)errorMessage;
- (NSError *)error;

- (PGTransactionStatusType)transactionStatus;

@end

extern NSString *PostgreSQLErrorDomain;