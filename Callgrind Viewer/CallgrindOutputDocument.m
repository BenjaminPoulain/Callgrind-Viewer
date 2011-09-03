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
#import "Profile.h"

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
    [_fileLoader release];
    [_profile release];
    [_windowController release];
    [super dealloc];
}

- (void)close
{
    [_fileLoader cancel];
    [super close];
}

- (void)profileLoaded:(Profile *)profile
{
    [_fileLoader release];
    _fileLoader = nil;

    assert(!_profile);
    [profile retain];
    _profile = profile;

    [_windowController synchronizeWindowTitleWithDocumentName];
}

- (NSString *)displayName
{
    if (_profile)
        return [NSString stringWithFormat:@"%@ - %@", [super displayName], _profile.command];
    return [super displayName];
}

- (void)errorLoadingFile:(NSError *)error
{
    [_fileLoader release];
    _fileLoader = nil;

    // FIXME: present a window modal panel if the window is already on screen.
    [_windowController closeWithError:error];
}

- (void)makeWindowControllers
{
    _windowController = [[CallgrindOutputWindowController alloc] init];
    [self addWindowController:_windowController];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    assert(!_fileLoader);
    _fileLoader = [[FileLoader alloc] initWithURL:absoluteURL
                                 fileReadCallback:^(Profile *profile) { [self profileLoaded:profile]; }
                                    errorCallback:^(NSError *error) { [self errorLoadingFile:error]; }];
    return YES;
}

@end
