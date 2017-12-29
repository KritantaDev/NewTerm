//
//  HBNTTerminalTextView.m
//  NewTerm
//
//  Created by Adam D on 26/01/2015.
//  Copyright (c) 2015 HASHBANG Productions. All rights reserved.
//

#import "HBNTTerminalTextView.h"
#import "HBNTKeyboardButton.h"
#import "HBNTKeyboardToolbar.h"

@implementation HBNTTerminalTextView {
	HBNTTerminalModifierKey _currentModifierKey;

	BOOL _ctrlDown;
	BOOL _metaDown;
}

- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)textContainer {
	self = [super initWithFrame:frame textContainer:textContainer];

	if (self) {
		self.showsHorizontalScrollIndicator = NO;
		self.dataDetectorTypes = UIDataDetectorTypeLink;
		self.linkTextAttributes = @{
			NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
		};
		self.textContainerInset = UIEdgeInsetsZero;
		self.textContainer.lineFragmentPadding = 0;

		self.autocapitalizationType = UITextAutocapitalizationTypeNone;
		self.autocorrectionType = UITextAutocorrectionTypeNo;
		self.spellCheckingType = UITextSpellCheckingTypeNo;

		if (@available(iOS 11.0, *)) {
			self.smartQuotesType = UITextSmartQuotesTypeNo;
			self.smartDashesType = UITextSmartDashesTypeNo;
			self.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
		}

		// TODO: this should be themable
		self.keyboardAppearance = UIKeyboardAppearanceDark;

		if (IS_IPAD && [self respondsToSelector:@selector(inputAssistantItem)]) {
			self.inputAssistantItem.allowsHidingShortcuts = NO;
			self.inputAssistantItem.leadingBarButtonGroups = [self.inputAssistantItem.leadingBarButtonGroups arrayByAddingObject:
				[[UIBarButtonItemGroup alloc] initWithBarButtonItems:@[
					[[UIBarButtonItem alloc] initWithCustomView:[HBNTKeyboardButton buttonWithTitle:@"Ctrl" target:self action:@selector(ctrlKeyPressed:)]],
					[[UIBarButtonItem alloc] initWithCustomView:[HBNTKeyboardButton buttonWithTitle:@"Esc" target:self action:@selector(metaKeyPressed:)]],
					[[UIBarButtonItem alloc] initWithCustomView:[HBNTKeyboardButton buttonWithTitle:@"Tab" target:self action:@selector(tabKeyPressed:)]]
				] representativeItem:nil]];
		} else {
			HBNTKeyboardToolbar *toolbar = [[HBNTKeyboardToolbar alloc] init];
			toolbar.translatesAutoresizingMaskIntoConstraints = NO;
			[toolbar.ctrlKey addTarget:self action:@selector(ctrlKeyPressed:) forControlEvents:UIControlEventTouchUpInside];
			[toolbar.metaKey addTarget:self action:@selector(metaKeyPressed:) forControlEvents:UIControlEventTouchUpInside];
			[toolbar.tabKey addTarget:self action:@selector(tabKeyPressed:) forControlEvents:UIControlEventTouchUpInside];
			self.inputAccessoryView = toolbar;
		}
	}

	return self;
}

- (void)ctrlKeyPressed:(UIButton *)button {
	_ctrlDown = !_ctrlDown;
	button.selected = _ctrlDown;
}

- (void)metaKeyPressed:(UIButton *)button {
	_metaDown = !_metaDown;
	button.selected = _metaDown;
}

- (void)tabKeyPressed:(UIButton *)button {
	static dispatch_once_t onceToken;
	static NSData *TabData;
	dispatch_once(&onceToken, ^{
		TabData = [NSData dataWithBytes:"\t" length:1];
	});

	[self.terminalInputDelegate receiveKeyboardInput:TabData];
}

#pragma mark - UITextInput

- (BOOL)hasText {
	return YES;
}

- (void)insertText:(NSString *)input {
	NSMutableData *data = [NSMutableData data];

	unichar characters[input.length];
	[input getCharacters:characters range:NSMakeRange(0, input.length)];

	for (int i = 0; i < input.length; i++) {
		unichar character = characters[i];

		switch (_currentModifierKey) {
			case HBNTTerminalModifierKeyNone:
				if (character == 0x0a) {
					// Convert newline to a carraige return
					character = 0x0d;
				}
				break;
			
			case HBNTTerminalModifierKeyCtrl:
				// Convert the character to a control key with the same ascii name (or
				// just use the original character if not in the acsii range)
				if (character < 0x60 && character > 0x40) {
					// Uppercase (and a few characters nearby, such as escape)
					character -= 0x40;
				} else if (character < 0x7B && character > 0x60) {
					// Lowercase
					character -= 0x60;
				}
				// falls through!

			case HBNTTerminalModifierKeyMeta:
			case HBNTTerminalModifierKeyEsc:
				[_terminalInputDelegate modifierKeyPressed:_currentModifierKey];
				_currentModifierKey = HBNTTerminalModifierKeyNone;
				break;
		}

		// Re-encode as UTF8
		[data appendBytes:&character length:1];
	}

	[_terminalInputDelegate receiveKeyboardInput:data];
}

- (void)_deleteBackwardAndNotify:(BOOL)notify {
	static NSData *BackspaceData;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		BackspaceData = [[NSData alloc] initWithBytes:"\x7F" length:1];
	});

	[_terminalInputDelegate receiveKeyboardInput:BackspaceData];
}

- (CGRect)caretRectForPosition:(UITextPosition *)position {
	// TODO: should we take advantage of this?
	return CGRectZero;
}

#pragma mark - UIResponder

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
	if (action == @selector(paste:)) {
		// Only paste if the board contains plain text
		return [[UIPasteboard generalPasteboard] containsPasteboardTypes:UIPasteboardTypeListString];
	} else if (action == @selector(cut:)) {
		// ensure cut is never allowed
		return NO;
	}

	return [super canPerformAction:action withSender:sender];
}

- (void)paste:(id)sender {
	UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];

	if (![pasteboard containsPasteboardTypes:UIPasteboardTypeListString]) {
		return;
	}

	[_terminalInputDelegate receiveKeyboardInput:[pasteboard.string dataUsingEncoding:NSUTF8StringEncoding]];
}

@end
