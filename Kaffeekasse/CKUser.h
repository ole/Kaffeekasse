//
//  CKUser.h
//  Kaffeekasse
//
//  Created by Ole Begemann on 06.08.12.
//  Copyright (c) 2012 Ole Begemann. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CKUser : NSObject

+ (id)userWithName:(NSString *)name email:(NSString *)email accountBalance:(float)accountBalance;
- (id)initWithName:(NSString *)name email:(NSString *)email accountBalance:(float)accountBalance;

@property (copy) NSString *name;
@property (copy) NSString *email;
@property float accountBalance;

@end
