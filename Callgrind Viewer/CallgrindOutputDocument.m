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

#import "CallgrindOutputDocument.h"

#import "CallgrindOutputWindowController.h"
#import "FileLoader.h"

@implementation CallgrindOutputDocument

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
    }
    return self;
}

- (void)dealloc
{
    [_fileLoader cancel];
    [_fileLoader release];
    [super dealloc];
}

- (void)makeWindowControllers
{
    CallgrindOutputWindowController *windowController = [[[CallgrindOutputWindowController alloc] init] autorelease];
    [self addWindowController:windowController];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    assert(!_fileLoader);
    _fileLoader = [[FileLoader alloc] initWithURL:absoluteURL];
    return YES;
}

@end
