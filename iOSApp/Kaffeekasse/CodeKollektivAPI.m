//
//  CodeKollektivAPI.m
//  Kaffeekasse
//
//  Created by Ole Begemann on 06.08.12.
//  Copyright (c) 2012 Ole Begemann. All rights reserved.
//

#import "CodeKollektivAPI.h"
#import "Config.h"

@implementation CodeKollektivAPI

- (void)loadUsers:(CodeKollektivAPICompletionHandler)completionHandler
{
    [self sendJSONRequestWithMethod:@"GET" path:@"/users" formFields:nil completionHandler:^(BOOL success, id result, NSError *error) {
        if (completionHandler) {
            if (success) {
                if (result) {
                    NSMutableArray *users = [NSMutableArray arrayWithCapacity:[result count]];
                    for (NSDictionary *jsonUser in result) {
                        CKUser *user = [CKUser userWithJSON:jsonUser];
                        [users addObject:user];
                    }
                    completionHandler(YES, users, nil);
                } else {
                    completionHandler(NO, nil, error);
                }
            } else {
                completionHandler(NO, nil, error);
            }
        }
    }];
}

- (void)loadUserWithBarcodeText:(NSString *)barcodeText completionHandler:(CodeKollektivAPICompletionHandler)completionHandler
{
    NSData *barcodeTextData = [barcodeText dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError = nil;
    NSDictionary *barcodeDict = [NSJSONSerialization JSONObjectWithData:barcodeTextData options:0 error:&jsonError];
    if (barcodeDict) {
        NSString *passTypeID = barcodeDict[@"pass_type_id"];
        NSString *serialNumber = barcodeDict[@"serial_number"];
        NSString *authenticationToken = barcodeDict[@"authentication_token"];
        NSParameterAssert(passTypeID);
        NSParameterAssert(serialNumber);
        NSParameterAssert(authenticationToken);
        
        NSString *path = [NSString stringWithFormat:@"/user_for_pass/%@/%@/%@", passTypeID, serialNumber, authenticationToken];
        [self sendJSONRequestWithMethod:@"GET" path:path formFields:nil completionHandler:^(BOOL success, id result, NSError *error) {
            if (completionHandler) {
                if (success) {
                    CKUser *user = [CKUser userWithJSON:result];
                    completionHandler(YES, user, nil);
                } else {
                    completionHandler(NO, nil, error);
                }
            }
        }];
        
    } else {
        if (completionHandler) {
            completionHandler(NO, nil, jsonError);
        }
    }
}

- (void)updateUser:(CKUser *)user completionHandler:(CodeKollektivAPISuccessHandler)completionHandler
{
    NSParameterAssert(user.userID);
    NSString *path = [NSString stringWithFormat:@"/users/%@", user.userID];
    
    NSString *name = user.name ? user.name : @"";
    NSString *email = user.email ? user.email : @"";
    NSString *accountBalance = [[NSNumber numberWithFloat:user.accountBalance] stringValue];
    NSDictionary *formFields = @{ @"user[name]" : name, @"user[email]" : email, @"user[account_balance]" : accountBalance };
    
    [self sendJSONRequestWithMethod:@"PUT" path:path formFields:formFields completionHandler:^(BOOL success, id result, NSError *error) {
        if (completionHandler) {
            completionHandler(success, error);
        }
    }];
    
}

- (void)sendJSONRequestWithMethod:(NSString *)method path:(NSString *)path formFields:(NSDictionary *)formFields completionHandler:(CodeKollektivAPICompletionHandler)completionHandler
{
    NSString *urlString = [NSString stringWithFormat:@"%@%@", CKAPIEndpoint, path];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:method];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    if (formFields) {
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        NSMutableString *bodyString = [NSMutableString string];
        [formFields enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            NSString *urlEncodedKey = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            NSString *urlEncodedValue = [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            [bodyString appendFormat:@"%@=%@&", urlEncodedKey, urlEncodedValue];
        }];
        NSData *bodyData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
        [request setHTTPBody:bodyData];
        [request setValue:[NSString stringWithFormat:@"%d", [bodyData length]] forHTTPHeaderField:@"Content-Length"];
    }
    
    NSLog(@"Sending request: %@", request);
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
     {
         if (completionHandler) {
             if (data) {
                 NSError *jsonError = nil;
                 id result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
                 completionHandler(YES, result, jsonError);
             } else {
                 completionHandler(NO, nil, error);
             }
         }
     }];
}

@end
