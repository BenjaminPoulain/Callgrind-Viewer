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

#import "FileLoader.h"

#import "Foundation/NSData.h"
#import "Profile.h"

static const size_t maxBufferSize = 4096;

@implementation FileLoader

static inline ssize_t indexOfNextNewLineChar(const char* data, size_t offset, size_t size)
{
    size_t i = offset;
    while (i < size) {
        if (data[i] == '\n')
            return i;
        ++i;
    }
    return -1;
}

- (BOOL)processBodyLine:(NSString *)string
{
    return YES;
}

- (BOOL)processHeaderLine:(NSString *)string
{
    if (![string length])
        return YES;
    if ([string hasPrefix:@"#"])
        return YES;

    { // Command parsing.
        NSError *error = 0;
        NSRegularExpression *commandRegex = [NSRegularExpression regularExpressionWithPattern:@"^cmd:[ \t]*(.*)$"
                                                                                      options:0
                                                                                        error:&error];
        NSTextCheckingResult *match = [commandRegex firstMatchInString: string options: 0 range:NSMakeRange(0, [string length])];
        if (match) {
            NSRange commandRange = [match rangeAtIndex: 1];
            NSString *commandName = [string substringWithRange: commandRange];
            _profile.command = commandName;
            return YES;
        }
    }

    // FIXME: parse the remaining headers.
    return YES;
}

- (BOOL)processCreatorLine:(NSString *)string
{
    NSError *error = 0;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^creator:.*$"
                                                                           options:0
                                                                             error:&error];
    assert(!error);
    NSUInteger matches = [regex numberOfMatchesInString:string options:0 range:NSMakeRange(0, [string length])];

    assert(matches == 0 || matches == 1);
    _readingStage = Header;
    if (matches)
        return YES;
    else {
        // The creator line is optional, process next stage.
        return [self processHeaderLine:string];
    }
}

- (BOOL)processFormatVersionLine:(NSString *)string
{
    NSError *error = 0;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^version:[ \t]*(?:0x[a-fA-F0-9]+|\\d+)$"
                                                                           options:0
                                                                             error:&error];
    assert(!error);
    NSUInteger matches = [regex numberOfMatchesInString:string options:0 range:NSMakeRange(0, [string length])];

    assert(matches == 0 || matches == 1);
    _readingStage = Creator;
    if (matches)
        return YES;
    else {
        // The version line is optional, process next stage.
        return [self processCreatorLine:string];
    }
}

- (BOOL)processLine:(const char *)data size: (size_t) size
{
    NSString *string = [[[NSString alloc] initWithBytesNoCopy:(void *)data length:size encoding:NSASCIIStringEncoding freeWhenDone:NO] autorelease];
    switch (_readingStage) {
        case FormatVersion:
            return [self processFormatVersionLine:string];
        case Creator:
            return [self processCreatorLine:string];
        case Header:
            return [self processHeaderLine:string];
        case Body:
            return [self processBodyLine:string];
    }
    return YES;
}

// Process the data and return YES if we should continue reading the file.
- (BOOL)processData:(const char*)data size: (size_t)size
{
    size_t workOffset = 0;
    if ([_pendingDataBuffer length] > 0) {
        ssize_t nextNewLine = indexOfNextNewLineChar(data, 0, size);
        if (nextNewLine >= 0) {
            assert(nextNewLine <= size);
            [_pendingDataBuffer appendBytes:data length:nextNewLine];
            [self processLine:(const char*)[_pendingDataBuffer bytes] size:[_pendingDataBuffer length]];
            workOffset = nextNewLine + 1;
            [_pendingDataBuffer setLength:0];
        } else {
            if ([_pendingDataBuffer length] + size > maxBufferSize) {
                [_pendingDataBuffer setLength:0];
                return NO;
            }
            [_pendingDataBuffer appendBytes:data length:size];
            return YES;
        }
    }

    while (true) {
        ssize_t nextNewLine = indexOfNextNewLineChar(data, workOffset, size);
        if (nextNewLine >= 0) {
            assert(workOffset < size);
            assert(nextNewLine < size);
            [self processLine: (data + workOffset) size:(nextNewLine - workOffset)];
            workOffset = nextNewLine + 1;
        } else {
            assert(workOffset <= size);
            size_t bytesLeft = size - workOffset;
            if (!bytesLeft)
                return YES;
            if (bytesLeft > maxBufferSize)
                return NO;
            assert([_pendingDataBuffer length] == 0);
            assert((workOffset + bytesLeft) == size);
            [_pendingDataBuffer appendBytes:(data + workOffset) length:bytesLeft];
            return YES;
        }
    }
}

- (id)initWithURL:(NSURL *)absoluteURL fileReadCallback:(SuccessCallback)successCallback errorCallback:(ErrorCallback)errorCallback
{
    self = [super init];
    if (self) {
        _profile = [[Profile alloc] init];

        _pendingDataBuffer = [[NSMutableData alloc] initWithCapacity:0];
        _readingStage = FormatVersion;

        assert([absoluteURL isFileURL]);
        NSString* filePath = [absoluteURL path];
        _ioChannel = dispatch_io_create_with_path(/* type */ DISPATCH_IO_STREAM,
                                                  /* path */ [filePath fileSystemRepresentation],
                                                  /* oflag */ O_RDONLY,
                                                  /* mode */ 0,
                                                  /* queue */ dispatch_get_main_queue(),
                                                  /* completion callback */ ^(int error) {
                                                      BOOL isProfileValid = [_profile isValid];
                                                      if (!error && isProfileValid)
                                                          successCallback(_profile);
                                                      else {
                                                          NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                                    @"The profile cannot be loaded from the file.", NSLocalizedDescriptionKey,
                                                                                    filePath, NSFilePathErrorKey,
                                                                                    absoluteURL, NSURLErrorKey,
                                                                                    nil];
                                                          NSError *nsError = [NSError errorWithDomain:@"InvalidFile"
                                                                                                 code:1
                                                                                             userInfo:userInfo];
                                                          errorCallback(nsError);
                                                      }
                                                      [_profile release];
                                                      _profile = nil;

                                                      dispatch_release(_ioChannel);
                                                      _ioChannel = 0;
                                                  });
        if (_ioChannel) {
            dispatch_io_read(/* channel */ _ioChannel,
                             /* offset */ 0,
                             /* length */ SIZE_MAX,
                             /* queue */ dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0),
                             /* handler */ ^(bool done, dispatch_data_t data, int error) {
                                 if (error) {
                                     dispatch_io_close(_ioChannel, DISPATCH_IO_STOP);
                                     return;
                                 }
                                 bool success = dispatch_data_apply(data,
                                                                    (dispatch_data_applier_t)^(dispatch_data_t region, size_t offset, const void *buffer, size_t size) {
                                                                        return [self processData:(const char *)(buffer + offset) size: size];
                                                                    });
                                 if (!success) {
                                     dispatch_io_close(_ioChannel, DISPATCH_IO_STOP);
                                     return;
                                 }
                                 if (done) {
                                     dispatch_io_close(_ioChannel, 0);
                                     return;
                                 }
                             });
        }
    }
    return self;
}

- (void)cancel
{
    // FIXME: this does not seem to always lead to early termination of the read.
    if (_ioChannel)
        dispatch_io_close(_ioChannel, DISPATCH_IO_STOP);
}

- (void)dealloc
{
    assert(!_ioChannel);
    assert(!_profile);
    [_pendingDataBuffer release];
    [super dealloc];
}

@end
