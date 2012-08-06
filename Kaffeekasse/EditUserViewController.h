//
//  EditUserViewController.h
//  Kaffeekasse
//
//  Created by Ole Begemann on 06.08.12.
//  Copyright (c) 2012 Ole Begemann. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CKUser.h"

@protocol EditUserViewControllerDelegate;

@interface EditUserViewController : UIViewController <UITextFieldDelegate>

@property (weak) id<EditUserViewControllerDelegate> delegate;
@property CKUser *user;

@end


@protocol EditUserViewControllerDelegate <NSObject>

@optional
- (void)editUserViewController:(EditUserViewController *)controller didUpdateUser:(CKUser *)user;

@end

