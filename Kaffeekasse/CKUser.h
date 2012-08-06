//
//  CKUser.h
//  Kaffeekasse
//
//  Created by Ole Begemann on 06.08.12.
//  Copyright (c) 2012 Ole Begemann. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CKUser : NSObject <NSCopying>

+ (id)userWithJSON:(NSDictionary *)jsonDictionary;
+ (id)userWithID:(NSNumber *)userID name:(NSString *)name email:(NSString *)email accountBalance:(float)accountBalance;
- (id)initWithID:(NSNumber *)userID name:(NSString *)name email:(NSString *)email accountBalance:(float)accountBalance;

@property (readonly) NSNumber *userID;
@property (copy) NSString *name;
@property (copy) NSString *email;
@property float accountBalance;

@end
