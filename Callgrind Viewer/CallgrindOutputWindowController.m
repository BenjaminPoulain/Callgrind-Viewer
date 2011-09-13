/*
 * Copyright (C) 2011  Benjamin Poulain
 *
 * This program is free software: you can redistribute it and or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "CallgrindOutputWindowController.h"

#import "ProfileTableViewDataSource.h"

@implementation CallgrindOutputWindowController

@synthesize functionTableView = _functionTableView;

- (id)init
{
    self = [super initWithWindowNibName:@"CallgrindOutputWindow"];
    if (self)
        [self setShouldCloseDocument:YES];
    return self;
}

- (void)dealloc
{
    [_profileTableViewDataSource release];
    [super dealloc];
}

- (IBAction)filterFunctionsByName:(id)sender
{
    [_profileTableViewDataSource tableView:_functionTableView filterFunctionsByName:[sender stringValue]];
}

- (void)didPresentErrorWithRecovery:(BOOL)didRecover contextInfo:(void *)contextInfo
{
    [self close];
}
- (void)closeWithError:(NSError *) error
{
    [self presentError:error modalForWindow:[self window] delegate:self didPresentSelector:@selector(didPresentErrorWithRecovery:contextInfo:) contextInfo:0];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    assert([keyPath isEqual:@"profile"]);
    [_profileTableViewDataSource release];
    Profile *newProfile = [change objectForKey:NSKeyValueChangeNewKey];
    _profileTableViewDataSource = [[ProfileTableViewDataSource alloc] initWithProfile:newProfile];
    [_functionTableView setDataSource:_profileTableViewDataSource];
}

- (void)setDocument:(NSDocument *)document
{
    NSDocument *previousDocument = [self document];
    if (previousDocument == document)
        return;

    if (previousDocument)
        [previousDocument removeObserver:self forKeyPath:@"profile"];
    [super setDocument:document];

    [document addObserver:self
               forKeyPath:@"profile"
                  options:NSKeyValueObservingOptionNew
                  context:0];
}

- (void)windowDidLoad
{
    [_functionTableView setDataSource:_profileTableViewDataSource];
}

@end
