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

#import "Profile.h"

@implementation Profile

@synthesize command = _command;
@synthesize functions = _functions;

- (BOOL)isValid
{
    return !!_command;
}

- (void)addFunction:(FunctionDescriptor*)function
{
    [_functions addObject:function];
}

- (id)init
{
    self = [super init];
    if (self)
        _functions = [[NSMutableSet alloc] init];
    return self;
}

- (void)dealloc
{
    [_functions release];
}

@end
