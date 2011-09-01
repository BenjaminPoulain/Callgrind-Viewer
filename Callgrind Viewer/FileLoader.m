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

- (BOOL)processLine:(const char*)data size: (size_t) size
{
    // FIXME: on invalid file format: return NO;
    // FIXME: parse the line.
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

- (id)initWithURL:(NSURL *)absoluteURL
{
    self = [super init];
    if (self) {
        _pendingDataBuffer = [[NSMutableData alloc] initWithCapacity:0];

        assert([absoluteURL isFileURL]);
        NSString* filePath = [absoluteURL path];
        _ioChannel = dispatch_io_create_with_path(/* type */ DISPATCH_IO_STREAM,
                                                  /* path */ [filePath fileSystemRepresentation],
                                                  /* oflag */ O_RDONLY,
                                                  /* mode */ 0,
                                                  /* queue */ dispatch_get_main_queue(),
                                                  /* completion callback */ ^(int error) {
                                                      if (error != 0) {
                                                          // FIXME: error callback to the clients of the class.
                                                          NSLog(@"Error while reading the file or reading interrupted.");
                                                      }
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
    if (_ioChannel)
        dispatch_io_close(_ioChannel, DISPATCH_IO_STOP);
}

- (void)dealloc
{
    assert(!_ioChannel);
    [_pendingDataBuffer release];
    [super dealloc];
}

@end
