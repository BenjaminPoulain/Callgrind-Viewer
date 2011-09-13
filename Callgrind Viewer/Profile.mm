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

#include <Profile.h>
#import "FunctionDescriptor.h"

static inline CallgrindParser::Profile* getProfile(void *variable)
{
    return static_cast<CallgrindParser::Profile*>(variable);
}

@implementation Profile

- (id)initWithProfile:(void *)profile;
{
    self = [super init];
    if (self)
        _callgrindProfile = profile;
   return self;
}

- (void)dealloc
{
    delete getProfile(_callgrindProfile);
    [super dealloc];
}

- (NSString *)command
{
    CallgrindParser::Profile* profile = getProfile(_callgrindProfile);
    const string &command = profile->command();
    return [[[NSString alloc] initWithBytesNoCopy:static_cast<void *>(const_cast<char *>(command.data()))
                                           length:command.size()
                                         encoding:NSUTF8StringEncoding
                                     freeWhenDone:NO] autorelease];
}

- (NSArray *)functions
{
    CallgrindParser::Profile* profile = getProfile(_callgrindProfile);
    const size_t functionDescriptorCount = profile->functionDescriptorCount();
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:functionDescriptorCount];
    for (size_t i = 0; i < functionDescriptorCount; ++i) {
        FunctionDescriptor *functionDescriptor = [[FunctionDescriptor alloc] initWithDescriptor:profile->functionDescriptorAt(i)];
        [array addObject:functionDescriptor];
        [functionDescriptor release];
    }
    return array;
}

@end
