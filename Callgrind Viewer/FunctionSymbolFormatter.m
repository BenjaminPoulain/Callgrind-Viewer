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

#import "FunctionSymbolFormatter.h"

@implementation FunctionSymbolFormatter

- (NSString *)stringForObjectValue:(id)anObject
{
    return anObject;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)anObject withDefaultAttributes:(NSDictionary *)attributes
{
    NSString *symbolString = (NSString *)anObject;
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:symbolString attributes:attributes];

    NSRange symbolRange = NSMakeRange(0, [symbolString length]);
    { // Find Objective-C [calls].
        NSCharacterSet *closingBracket = [NSCharacterSet characterSetWithCharactersInString:@"]"];
        NSRange endPosition = [symbolString rangeOfCharacterFromSet:closingBracket options:NSBackwardsSearch | NSLiteralSearch];
        if (!NSEqualRanges(endPosition, NSMakeRange(NSNotFound, 0))) {
            NSCharacterSet *openingBracket = [NSCharacterSet characterSetWithCharactersInString:@"["];
            NSRange startPosition = [symbolString rangeOfCharacterFromSet:openingBracket
                                                                  options:NSLiteralSearch
                                                                    range:NSMakeRange(0, endPosition.location)];
            if (!NSEqualRanges(startPosition, NSMakeRange(NSNotFound, 0))) {
                symbolRange.location = startPosition.location + 1;
                symbolRange.length = endPosition.location - symbolRange.location;
            }
        }
    }
    if (symbolRange.location == 0) { // Find last opening parenthesis and the delimitor before it.
        NSCharacterSet *charSet = [NSCharacterSet characterSetWithCharactersInString:@"("];
        NSRange endPosition = [symbolString rangeOfCharacterFromSet:charSet options:NSBackwardsSearch | NSLiteralSearch];

        if (!NSEqualRanges(endPosition, NSMakeRange(NSNotFound, 0))) {
            
            NSCharacterSet *separatorChar = [NSCharacterSet characterSetWithCharactersInString:@" :"];
            NSRange startPosition = [symbolString rangeOfCharacterFromSet:separatorChar
                                                                  options:NSBackwardsSearch | NSLiteralSearch
                                                                    range:NSMakeRange(0, endPosition.location)];
            if (!NSEqualRanges(startPosition, NSMakeRange(NSNotFound, 0))) {
                symbolRange.location = startPosition.location + 1;
                symbolRange.length = endPosition.location - symbolRange.location;
            }
        }
    }
    { // Make the symbol bold.
        NSFont *currentFont = [attributes objectForKey:NSFontAttributeName];
        assert(currentFont);
        NSFontManager *fontManager = [NSFontManager sharedFontManager];
        NSFont *boldFont = [fontManager convertFont:currentFont toHaveTrait:NSBoldFontMask];
        NSMutableDictionary *boldFontAttributes = [attributes mutableCopy];
        [boldFontAttributes setValue:boldFont forKey:NSFontAttributeName];
        
        [attributedString setAttributes:boldFontAttributes range:symbolRange];
        [boldFontAttributes release];
    }

    return [attributedString autorelease];
}

@end
