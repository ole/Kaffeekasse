//
//  CKAPI.h
//  Kaffeekasse
//
//  Created by Ole Begemann on 06.08.12.
//  Copyright (c) 2012 Ole Begemann. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CKUser.h"

typedef void (^CodeKollektivAPICompletionHandler)(BOOL success, id result, NSError *error);
typedef void (^CodeKollektivAPISuccessHandler)(BOOL success, NSError *error);

@interface CKAPI : NSObject

- (void)loadUsers:(CodeKollektivAPICompletionHandler)completionHandler;
- (void)loadUserWithBarcodeText:(NSString *)barcodeText completionHandler:(CodeKollektivAPICompletionHandler)completionHandler;
- (void)updateUser:(CKUser *)user completionHandler:(CodeKollektivAPISuccessHandler)completionHandler;

@end
