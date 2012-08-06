//
//  UserListViewController.m
//  Kaffeekasse
//
//  Created by Ole Begemann on 06.08.12.
//  Copyright (c) 2012 Ole Begemann. All rights reserved.
//

#import "UserListViewController.h"
#import "CodeKollektivAPI.h"

@interface UserListViewController ()

@property NSMutableArray *users;

@end


@implementation UserListViewController

- (void)awakeFromNib
{
    self.users = [NSMutableArray array];
    
    CodeKollektivAPI *api = [[CodeKollektivAPI alloc] init];
    [api loadUsers:^(BOOL success, id result, NSError *error) {
        if (success) {
            NSLog(@"%@", result);
            [self.users removeAllObjects];
            [self.users addObjectsFromArray:result];
            [self.tableView reloadData];
        } else {
            NSLog(@"Error loading users: %@", error);
        }
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"EditUser"])
    {
        EditUserViewController *editUserViewController = segue.destinationViewController;
        editUserViewController.delegate = self;
        
        CKUser *user = nil;
        if ([sender isKindOfClass:[CKUser class]]) {
            user = sender;
        } else if ([sender isKindOfClass:[UITableViewCell class]]) {
            NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
            user = self.users[indexPath.row];
        } else {
            user = [CKUser userWithID:nil name:@"" email:@"" accountBalance:10.0f];
        }
        editUserViewController.user = [user copy];
    }
}

#pragma mark - Barcode scanner

- (void)presentBarcodeScanner
{
    ZBarReaderViewController *reader = [[ZBarReaderViewController alloc] init];
    reader.readerDelegate = self;
    reader.supportedOrientationsMask = ZBarOrientationMask(UIInterfaceOrientationPortrait);
    
    ZBarImageScanner *scanner = reader.scanner;
    [scanner setSymbology:ZBAR_I25 config:ZBAR_CFG_ENABLE to:0];
    
    [self presentViewController:reader animated:YES completion:nil];
}


#pragma mark - ZBarReaderDelegate

- (void)imagePickerController:(UIImagePickerController*)reader didFinishPickingMediaWithInfo:(NSDictionary*)info
{
    [reader dismissViewControllerAnimated:YES completion:nil];

    id<NSFastEnumeration> results = [info objectForKey:ZBarReaderControllerResults];
    ZBarSymbol *symbol = nil;
    for (ZBarSymbol *result in results) {
        symbol = result;
        break;
    }

    NSLog(@"Barcode text: %@", symbol.data);
    CodeKollektivAPI *api = [[CodeKollektivAPI alloc] init];
    [api loadUserWithBarcodeText:symbol.data completionHandler:^(BOOL success, id result, NSError *error) {
        if (success) {
            CKUser *user = result;
            NSLog(@"Identified user: %@", user);
            [self performSegueWithIdentifier:@"EditUser" sender:user];
        } else {
            NSLog(@"Error reading barcode: %@", error);
        }
    }];
}


#pragma mark - EditUserViewControllerDelegate

- (void)editUserViewController:(EditUserViewController *)controller didUpdateUser:(CKUser *)user
{
    CodeKollektivAPI *api = [[CodeKollektivAPI alloc] init];
    [api updateUser:user completionHandler:^(BOOL success, NSError *error) {
        if (success) {
            NSLog(@"Updated user");
        } else {
            NSLog(@"Updating user failed: %@", error);
        }
    }];
}


#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) return 1;
    else return [self.users count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ScanBarcodeCell"];
        return cell;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UserCell"];
    CKUser *user = self.users[indexPath.row];
    cell.textLabel.text = user.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2f €", user.accountBalance];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        [self presentBarcodeScanner];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
