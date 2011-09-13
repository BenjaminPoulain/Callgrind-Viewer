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
#import "FunctionDescriptor.h"
#import "Profile.h"
#import <Parser.h>

static const size_t maxBufferSize = 4096;


static inline CallgrindParser::Parser *getParser(void *variable)
{
    return static_cast<CallgrindParser::Parser*>(variable);
}

static inline ssize_t indexOfNextNewLineChar(const char* data, size_t offset, size_t size)
{
    // FIXME: this can be made faster reading whole words at a time.
    size_t i = offset;
    while (i < size) {
        if (data[i] == '\n')
            return i;
        ++i;
    }
    return -1;
}

@implementation FileLoader

- (BOOL)processData:(const char*)data size: (size_t)size
{
    size_t workOffset = 0;
    // Process the remaining data from the previous chunk.
    if ([_pendingDataBuffer length] > 0) {
        ssize_t nextNewLine = indexOfNextNewLineChar(data, 0, size);
        if (nextNewLine >= 0) {
            assert(nextNewLine <= size);
            [_pendingDataBuffer appendBytes:data length:nextNewLine];
            if (!getParser(_parser)->parseLine(static_cast<const char *>([_pendingDataBuffer bytes]), [_pendingDataBuffer length]))
                return NO;
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

    // Process the new data in place.
    while (true) {
        ssize_t nextNewLine = indexOfNextNewLineChar(data, workOffset, size);
        if (nextNewLine >= 0) {
            assert(workOffset < size);
            assert(nextNewLine < size);
            if (!getParser(_parser)->parseLine((data + workOffset), (nextNewLine - workOffset)))
                return NO;
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
        _parser = new CallgrindParser::Parser();

        _pendingDataBuffer = [[NSMutableData alloc] initWithCapacity:0];

        assert([absoluteURL isFileURL]);
        NSString* filePath = [absoluteURL path];

        void (^cleanup_handler)(int error) = ^(int error) {
            auto_ptr<CallgrindParser::Profile> callgrindProfile = getParser(_parser)->profile();
            bool isProfileValid = callgrindProfile.get() && callgrindProfile->isValid();
            if (!error && isProfileValid) {
                Profile *profile = [[Profile alloc] initWithProfile:callgrindProfile.release()];
                successCallback(profile);
                [profile release];
                profile = nil;
            } else {
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
            delete getParser(_parser);
            _parser = 0;
            dispatch_release(_ioChannel);
            _ioChannel = 0;
        };
        _ioChannel = dispatch_io_create_with_path(/* type */ DISPATCH_IO_STREAM,
                                                  /* path */ [filePath fileSystemRepresentation],
                                                  /* oflag */ O_RDONLY,
                                                  /* mode */ 0,
                                                  /* queue */ dispatch_get_main_queue(),
                                                  /* completion callback */ cleanup_handler);
        if (_ioChannel) {
            dispatch_io_handler_t ioHandler = ^(bool done, dispatch_data_t data, int error) {
                if (error) {
                    dispatch_io_close(_ioChannel, DISPATCH_IO_STOP);
                    return;
                }
                dispatch_data_applier_t dataApplier = ^bool (dispatch_data_t region, size_t offset, const void *buffer, size_t size) {
                    return [self processData:(static_cast<const char *>(buffer) + offset) size: size];
                };
                bool success = dispatch_data_apply(data, dataApplier);
                if (!success) {
                    dispatch_io_close(_ioChannel, DISPATCH_IO_STOP);
                    return;
                }
                if (done) {
                    dispatch_io_close(_ioChannel, 0);
                    return;
                }
            };
            dispatch_io_read(/* channel */ _ioChannel,
                             /* offset */ 0,
                             /* length */ SIZE_MAX,
                             /* queue */ dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0),
                             /* handler */ ioHandler);
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
    [self cancel];
    assert(!_ioChannel);
    assert(!_parser);
    [_pendingDataBuffer release];
    [super dealloc];
}

@end
