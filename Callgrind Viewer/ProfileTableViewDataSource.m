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

#import "ProfileTableViewDataSource.h"

#import "Profile.h"
#import "FunctionDescriptor.h"

@implementation ProfileTableViewDataSource

static inline NSArray *getFunctionsArray(Profile *profile)
{
    return [profile functions];
}

- (id)initWithProfile:(Profile *)profile
{
    self = [super init];
    if (self) {
        _profile = profile;
        [_profile retain];

        _functions = getFunctionsArray(_profile);
        [_functions retain];

        _activeFilterString = [[NSString alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_profile release];
    [_functions release];
    [_activeFilterString release];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [_functions count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    FunctionDescriptor *function = [_functions objectAtIndex:rowIndex];
    return [function valueForKey:[aTableColumn identifier]];
}

- (void)tableView:(NSTableView *)aTableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
    NSArray *sortDescriptors = [aTableView sortDescriptors];
    NSArray *newFunctionArray = [_functions sortedArrayUsingDescriptors:sortDescriptors];
    [newFunctionArray retain];
    [_functions release];
    _functions = newFunctionArray;
    [aTableView reloadData];
}

static inline bool stringContainsOtherString(NSString *stringContaining, NSString *stringContained)
{
    return !NSEqualRanges([stringContaining rangeOfString:stringContained], NSMakeRange(NSNotFound, 0));
}

static inline bool stringContainsOtherStringCaseInsensitive(NSString *stringContaining, NSString *stringContained)
{
    return !NSEqualRanges([stringContaining rangeOfString:stringContained options:NSCaseInsensitiveSearch],
                          NSMakeRange(NSNotFound, 0));
}


- (void)tableView:(NSTableView*)tableView filterFunctionsByName:(NSString *)name
{
    if (![name length]) {
        // Special case: no filtering.
        [_functions release];
        _functions = getFunctionsArray(_profile);
        [_functions retain];

        [_activeFilterString release];
        _activeFilterString = [[NSString alloc] init];

        [self tableView:tableView sortDescriptorsDidChange:nil];
        return;
    }

    // Find the smallest array worth filtering.
    NSString *lowerCaseName = [name lowercaseString];
    NSArray *arrayToFilter;
    if (stringContainsOtherString(lowerCaseName, _activeFilterString))
        arrayToFilter = _functions;
    else
        arrayToFilter = getFunctionsArray(_profile);

    // Reset the active filter attribute.
    [_activeFilterString release];
    [lowerCaseName retain];
    _activeFilterString = lowerCaseName;

    // Filter the array and keep it as new active function array.
    NSPredicate *filteringPredicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return stringContainsOtherStringCaseInsensitive([evaluatedObject name], lowerCaseName);
    }];

    NSArray *filteredArray = [arrayToFilter filteredArrayUsingPredicate:filteringPredicate];
    [filteredArray retain];
    [_functions release];
    _functions = filteredArray;

    [self tableView:tableView sortDescriptorsDidChange:nil];
}

@end
