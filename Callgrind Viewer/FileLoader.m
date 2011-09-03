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

- (NSString *)parseFunction:(NSString *)string regex:(NSRegularExpression *)regex
{
    NSTextCheckingResult *result = [regex firstMatchInString: string options: 0 range:NSMakeRange(0, [string length])];
    if (result) {
        NSString *functionName = nil;
        NSRange functionRange = [result rangeAtIndex: 2];
        if (!NSEqualRanges(functionRange, NSMakeRange(NSNotFound, 0)))
            functionName = [string substringWithRange:functionRange];

        NSRange functionIdRange = [result rangeAtIndex: 1];
        if (!NSEqualRanges(functionIdRange, NSMakeRange(NSNotFound, 0))) {
            NSString *functionIdSring = [string substringWithRange:functionIdRange];

            if (functionName)
                [_functionCompressedNames setObject:functionName forKey:functionIdSring];
            else
                functionName = [_functionCompressedNames objectForKey:functionIdSring];
        }
        assert(functionName);
        return functionName;
    }
    return nil;
}

- (BOOL)processBodyLine:(NSString *)string
{
    if ([self parseFunction:string regex:_functionRegex])
        return YES;
    if ([self parseFunction:string regex:_calledFunctionRegex])
        return YES;
    // FIXME: fully implement body parsing.
    return YES;
}

static bool regexMatchesString(NSString *regexpString, NSString *string)
{
    NSError *error = 0;
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:regexpString
                                                                      options:0
                                                                        error:&error];
    assert(!error);
    NSUInteger matches = [regex numberOfMatchesInString:string options:0 range:NSMakeRange(0, [string length])];
    [regex release];
    regex = nil;

    assert(matches == 0 || matches == 1);
    return !!matches;
}

static NSTextCheckingResult *getFirstRegexpMatch(NSString *regexpString, NSString *string)
{
    NSError *error = 0;
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:regexpString
                                                                      options:0
                                                                        error:&error];
    assert(!error);
    NSTextCheckingResult *match = [regex firstMatchInString: string options: 0 range:NSMakeRange(0, [string length])];
    [regex release];
    regex = nil;
    return match;
}

static NSString *getFirstSubgroupInRegexpMatch(NSString *regexpString, NSString *string)
{
    NSTextCheckingResult *match = getFirstRegexpMatch(regexpString, string);
    if (match) {
        NSRange range = [match rangeAtIndex: 1];
        return [string substringWithRange: range];
    }
    return nil;
}

- (BOOL)processHeaderLine:(NSString *)string
{
    if (![string length])
        return YES;
    if ([string hasPrefix:@"#"])
        return YES;

    // Command parsing.
    NSString *commandName = getFirstSubgroupInRegexpMatch(@"^cmd:[ \t]*(.*)$", string);
    if (commandName) {
        _profile.command = commandName;
        return YES;
    }

    // TargetID (pid, thread or part)
    if (regexMatchesString(@"^(?:pid|thread|part):[ \t]*(?:0x[a-fA-F0-9]+|\\d+)$", string))
        return YES;

    // Description
    if (regexMatchesString(@"^desc:[ \t]*(?:[a-zA-Z][A-Za-z0-9 ]*)[ \t]*:.*$", string))
        return YES;

    { // CostLineDef::events
        NSString *eventsName = getFirstSubgroupInRegexpMatch(@"^events:[ \t]*((?:[a-zA-Z][a-zA-Z0-9]*)(?:[ \t]+(?:[a-zA-Z][a-zA-Z0-9]*))*)$", string);
        if (eventsName) {
            NSArray *events = [eventsName componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
            _positionOfInstructionCost = [events indexOfObject:@"Ir"];
            return YES;
        }
    }

    { // CostLineDef::positions
        NSTextCheckingResult *match = getFirstRegexpMatch(@"^positions:[\t ]*(instr)?([\t ]+line)?$", string);
        if (match) {
            // FIME: Store to values to parse the file.
            return YES;
        }
    }

    // Summary (not in grammar but appear in practice)
    if (regexMatchesString(@"^summary:[\t ]*(?:0x[a-fA-F0-9]+|\\d+)([\t ]+(?:0x[a-fA-F0-9]+|\\d+))*$", string))
        return YES;

    if (_positionOfInstructionCost != NSNotFound) {
        _readingStage = Body;
        return [self processBodyLine:string];
    }
    return NO;
}

- (BOOL)processCreatorLine:(NSString *)string
{
    if (regexMatchesString(@"^creator:.*$", string))
        return YES;
    else {
        // The creator line is optional, process next stage.
        return [self processHeaderLine:string];
    }
}

- (BOOL)processFormatVersionLine:(NSString *)string
{
    if (regexMatchesString(@"^version:[ \t]*(?:0x[a-fA-F0-9]+|\\d+)$", string))
        return YES;
    else {
        // The version line is optional, process next stage.
        return [self processCreatorLine:string];
    }
}

- (BOOL)processLine:(const void *)data size: (size_t) size
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

- (BOOL)processData:(const void*)data size: (size_t)size
{
    size_t workOffset = 0;
    // Process the remaining data from the previous chunk.
    if ([_pendingDataBuffer length] > 0) {
        ssize_t nextNewLine = indexOfNextNewLineChar(data, 0, size);
        if (nextNewLine >= 0) {
            assert(nextNewLine <= size);
            [_pendingDataBuffer appendBytes:data length:nextNewLine];
            if (![self processLine:[_pendingDataBuffer bytes] size:[_pendingDataBuffer length]])
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
            if (![self processLine: (data + workOffset) size:(nextNewLine - workOffset)])
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
        _profile = [[Profile alloc] init];

        _pendingDataBuffer = [[NSMutableData alloc] initWithCapacity:0];
        _readingStage = FormatVersion;

        _positionOfInstructionCost = NSNotFound;
        _functionCompressedNames = [[NSMutableDictionary alloc] init];
        NSError *error = 0;
        _functionRegex = [[NSRegularExpression alloc] initWithPattern:@"^fn=\\((\\d+)\\)?(?: (.*))?$"
                                                               options:0
                                                                 error:&error];
        assert(!error);
        _calledFunctionRegex = [[NSRegularExpression alloc] initWithPattern:@"^cfn=\\((\\d+)\\)?(?: (.*))?$"
                                                                     options:0
                                                                       error:&error];
        assert(!error);

        assert([absoluteURL isFileURL]);
        NSString* filePath = [absoluteURL path];

        void (^cleanup_handler)(int error) = ^(int error) {
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
                    return [self processData:(buffer + offset) size: size];
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
    assert(!_ioChannel);
    assert(!_profile);
    [_pendingDataBuffer release];
    [_functionCompressedNames release];
    [_functionRegex release];
    [_calledFunctionRegex release];
    [super dealloc];
}

@end
