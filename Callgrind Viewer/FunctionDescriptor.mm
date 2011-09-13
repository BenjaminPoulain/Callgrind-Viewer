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

#import "FunctionDescriptor.h"

#include <FunctionDescriptor.h>

static inline CallgrindParser::FunctionDescriptor *getFunctionDescriptor(void *variable)
{
    return static_cast<CallgrindParser::FunctionDescriptor*>(variable);
}

@implementation FunctionDescriptor

- (id)initWithDescriptor:(void *)descriptor;
{
    assert(descriptor);

    self = [super init];
    if (self)
        _descriptor = descriptor;

    return self;
}

- (NSString *)name
{
    CallgrindParser::FunctionDescriptor* functionDescriptor = getFunctionDescriptor(_descriptor);
    const string &name = functionDescriptor->name();
    return [[[NSString alloc] initWithBytesNoCopy:static_cast<void *>(const_cast<char *>(name.data()))
                                           length:name.size()
                                         encoding:NSUTF8StringEncoding
                                     freeWhenDone:NO] autorelease];
}

- (NSString *)object
{
    CallgrindParser::FunctionDescriptor* functionDescriptor = getFunctionDescriptor(_descriptor);
    const string &object = functionDescriptor->object();
    return [[[NSString alloc] initWithBytesNoCopy:static_cast<void *>(const_cast<char *>(object.data()))
                                           length:object.size()
                                         encoding:NSUTF8StringEncoding
                                     freeWhenDone:NO] autorelease];
}

- (NSString *)file
{
    CallgrindParser::FunctionDescriptor* functionDescriptor = getFunctionDescriptor(_descriptor);
    const string &file = functionDescriptor->file();
    return [[[NSString alloc] initWithBytesNoCopy:static_cast<void *>(const_cast<char *>(file.data()))
                                           length:file.size()
                                         encoding:NSUTF8StringEncoding
                                     freeWhenDone:NO] autorelease];
}
@end
