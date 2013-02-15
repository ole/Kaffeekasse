//
//  CKUser.m
//  Kaffeekasse
//
//  Created by Ole Begemann on 06.08.12.
//  Copyright (c) 2012 Ole Begemann. All rights reserved.
//

#import "CKUser.h"

@implementation CKUser

+ (id)userWithJSON:(NSDictionary *)jsonDictionary
{
    NSNumber *userID = jsonDictionary[@"id"];
    NSString *name = jsonDictionary[@"name"];
    NSString *email = jsonDictionary[@"email"];
    float accountBalance = [jsonDictionary[@"account_balance"] floatValue];
    return [self userWithID:userID name:name email:email accountBalance:accountBalance];
}

+ (id)userWithID:(NSNumber *)userID name:(NSString *)name email:(NSString *)email accountBalance:(float)accountBalance
{
    return [[self alloc] initWithID:userID name:name email:email accountBalance:accountBalance];
}

- (id)initWithID:(NSNumber *)userID name:(NSString *)name email:(NSString *)email accountBalance:(float)accountBalance
{
    self = [super init];
    if (self) {
        _userID = userID;
        _name = [name copy];
        _email = [email copy];
        _accountBalance = accountBalance;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithID:self.userID name:self.name email:self.email accountBalance:self.accountBalance];
}

@end
