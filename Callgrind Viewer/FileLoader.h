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

#import <Foundation/Foundation.h>

@class NSError;
@class NSMutableData;
@class Profile;

typedef void (^SuccessCallback)(Profile *);
typedef void (^ErrorCallback)(NSError *);

@interface FileLoader : NSObject {
@private
    __block Profile *_profile;
    NSUInteger _positionOfInstructionCost;
    NSMutableDictionary *_functionCompressedNames;
    NSRegularExpression *_functionRegex;
    NSRegularExpression *_calledFunctionRegex;

    __block dispatch_io_t _ioChannel;

    NSMutableData *_pendingDataBuffer;
    enum {
        FormatVersion,
        Creator,
        Header,
        Body,
    } _readingStage;
}

- (id)initWithURL:(NSURL *)absoluteURL fileReadCallback:(SuccessCallback)successCallback errorCallback:(ErrorCallback)errorCallback;
- (void)cancel;

@end
