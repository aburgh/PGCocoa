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
@class PGPreparedQuery;


@interface PGConnection : NSObject 
{
	PGconn *_connection;

	NSDictionary *_params;
}

- (id)initWithParameters:(NSDictionary *)params;

- (BOOL)connect;

- (PGResult *)executeQuery:(NSString *)query;
- (PGResult *)executeQuery:(NSString *)query parameters:(NSArray *)params;
- (PGPreparedQuery *)preparedQueryWithName:(NSString *)name query:(NSString *)sql types:(NSArray *)paramTypes;

- (NSString *)errorMessage;
- (NSError *)error;

- (BOOL)beginTransaction;
- (BOOL)commitTransaction;
- (BOOL)rollbackTransaction;
- (PGTransactionStatusType)transactionStatus;

- (PGconn *)_conn;

@end

extern NSString *const PostgreSQLErrorDomain;


// Connection Parameter Keys
extern NSString *const PGConnectionParameterHostKey;
extern NSString *const PGConnectionParameterHostAddressKey;
extern NSString *const PGConnectionParameterPortKey;
extern NSString *const PGConnectionParameterDatabaseNameKey;
extern NSString *const PGConnectionParameterUsernameKey;
extern NSString *const PGConnectionParameterPasswordKey;
extern NSString *const PGConnectionParameterConnectionTimeoutKey;
extern NSString *const PGConnectionParameterOptionsKey;
extern NSString *const PGConnectionParameterSSLModeKey;
extern NSString *const PGConnectionParameterKerberosServiceNameKey;
extern NSString *const PGConnectionParameterServiceNameKey;
