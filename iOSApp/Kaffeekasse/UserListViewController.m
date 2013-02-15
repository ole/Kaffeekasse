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

- (IBAction)handlePullToRefresh:(UIRefreshControl *)sender;

@end


@implementation UserListViewController

- (void)awakeFromNib
{
    self.users = [NSMutableArray array];
    [self loadUsersWithCompletionHandler:^(BOOL success) {
        [self.tableView reloadData];
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.refreshControl addTarget:self action:@selector(handlePullToRefresh:) forControlEvents:UIControlEventValueChanged];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"EditUser"])
    {
        CKUser *user = nil;
        if ([sender isKindOfClass:[CKUser class]]) {
            user = sender;
        } else if ([sender isKindOfClass:[UITableViewCell class]]) {
            NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
            user = self.users[indexPath.row];
        } else {
            user = [CKUser userWithID:nil name:@"" email:@"" accountBalance:0.0f];
        }

        EditUserViewController *editUserViewController = segue.destinationViewController;
        editUserViewController.delegate = self;
        editUserViewController.user = [user copy];
    }
}

- (void)loadUsersWithCompletionHandler:(void (^)(BOOL success))completionHandler
{
    CodeKollektivAPI *api = [[CodeKollektivAPI alloc] init];
    [api loadUsers:^(BOOL success, id result, NSError *error) {
        if (success) {
            NSLog(@"%@", result);
            [self.users removeAllObjects];
            [self.users addObjectsFromArray:result];
        } else {
            NSLog(@"Error loading users: %@", error);
        }
        if (completionHandler) {
            completionHandler(success);
        }
    }];
}

- (IBAction)handlePullToRefresh:(UIRefreshControl *)sender
{
    [self loadUsersWithCompletionHandler:^(BOOL success) {
        [self.tableView reloadData];
        [sender endRefreshing];
    }];
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

- (void)editUserViewController:(EditUserViewController *)controller didUpdateUser:(CKUser *)updatedUser
{
    CodeKollektivAPI *api = [[CodeKollektivAPI alloc] init];
    [api updateUser:updatedUser completionHandler:^(BOOL success, NSError *error) {
        if (success) {
            NSLog(@"Updated user");
            [self.navigationController popViewControllerAnimated:YES];
            NSUInteger indexOfUpdatedUser = [self.users indexOfObjectPassingTest:^BOOL(id user, NSUInteger idx, BOOL *stop) {
                if ([updatedUser.userID isEqualToNumber:[user userID]]) {
                    return YES;
                }
                return NO;
            }];
            if (indexOfUpdatedUser != NSNotFound) {
                [self.users replaceObjectAtIndex:indexOfUpdatedUser withObject:updatedUser];
                [self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:indexOfUpdatedUser inSection:1] ] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
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
}

@end
