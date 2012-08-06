//
//  EditUserViewController.m
//  Kaffeekasse
//
//  Created by Ole Begemann on 06.08.12.
//  Copyright (c) 2012 Ole Begemann. All rights reserved.
//

#import "EditUserViewController.h"

@interface EditUserViewController ()

@property (weak, nonatomic) IBOutlet UITextField *userNameTextField;
@property (weak, nonatomic) IBOutlet UITextField *userEmailTextField;
@property (weak, nonatomic) IBOutlet UITextField *userAccountBalanceTextField;
@property (weak, nonatomic) IBOutlet UIStepper *accountBalanceStepper;

- (IBAction)handleAccountBalanceStepperChanged:(id)sender;
- (IBAction)handleSaveButton:(id)sender;
- (IBAction)handleTextFieldChanged:(UITextField *)sender;

@end


@implementation EditUserViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self updateUI];
}

- (void)updateUI
{
    self.userNameTextField.text = self.user.name;
    self.userEmailTextField.text = self.user.email;
    self.userAccountBalanceTextField.text = [NSString stringWithFormat:@"%.2f", self.user.accountBalance];
    self.accountBalanceStepper.value = self.user.accountBalance;
}

#pragma mark - Actions

- (IBAction)handleAccountBalanceStepperChanged:(id)sender
{
    self.user.accountBalance = self.accountBalanceStepper.value;
    [self updateUI];
}

- (IBAction)handleSaveButton:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(editUserViewController:didUpdateUser:)]) {
        [self.delegate editUserViewController:self didUpdateUser:self.user];
    }
}

- (IBAction)handleTextFieldChanged:(UITextField *)sender
{
    self.user.name = self.userNameTextField.text;
    self.user.email = self.userEmailTextField.text;
    self.user.accountBalance = [self.userAccountBalanceTextField.text floatValue];
    self.accountBalanceStepper.value = self.user.accountBalance;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.userNameTextField) [self.userEmailTextField becomeFirstResponder];
    if (textField == self.userEmailTextField) [self.userAccountBalanceTextField becomeFirstResponder];
    if (textField == self.userAccountBalanceTextField) [self.userNameTextField becomeFirstResponder];
    return NO;
}

@end
