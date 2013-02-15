//
//  UserListViewController.h
//  Kaffeekasse
//
//  Created by Ole Begemann on 06.08.12.
//  Copyright (c) 2012 Ole Begemann. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EditUserViewController.h"
#import "CKUser.h"

@interface UserListViewController : UITableViewController <ZBarReaderDelegate, EditUserViewControllerDelegate>

@end
