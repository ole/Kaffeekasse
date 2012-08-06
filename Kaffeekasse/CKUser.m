//
//  CKUser.m
//  Kaffeekasse
//
//  Created by Ole Begemann on 06.08.12.
//  Copyright (c) 2012 Ole Begemann. All rights reserved.
//

#import "CKUser.h"

@implementation CKUser

+ (id)userWithName:(NSString *)name email:(NSString *)email accountBalance:(float)accountBalance
{
    return [[self alloc] initWithName:name email:email accountBalance:accountBalance];
}

- (id)initWithName:(NSString *)name email:(NSString *)email accountBalance:(float)accountBalance
{
    self = [super init];
    if (self) {
        _name = [name copy];
        _email = [email copy];
        _accountBalance = accountBalance;
    }
    return self;
}

@end
