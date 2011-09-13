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

#include "Parser.h"

#include <cassert>

using namespace std;

namespace CallgrindParser
{

Parser::Parser()
    : m_readingStage(FormatVersion)
{
}

bool Parser::parseLine(const char *data, size_t size)
{
    switch (m_readingStage) {
        case FormatVersion:
            return processFormatVersionLine(data, size);
        case Creator:
            return processCreatorLine(data, size);
        case Header:
            return processHeaderLine(data, size);
        case Body:
            return processBodyLine(data, size);
    }
    assert(false);
    return false;
}

auto_ptr<Profile>& Parser::profile()
{
    return m_profile;
}

bool Parser::processFormatVersionLine(const char *data, size_t size)
{
    m_readingStage = Creator;
    if (size == 10
        && data[0] == 'v'
        && data[1] == 'e'
        && data[2] == 'r'
        && data[3] == 's'
        && data[4] == 'i'
        && data[5] == 'o'
        && data[6] == 'n'
        && data[7] == ':'
        && data[8] == ' '
        && data[9] == '1') {
        return true;
    }
    return processCreatorLine(data, size);
}

bool Parser::processCreatorLine(const char *data, size_t size)
{
    m_readingStage = Header;
    if (size > 8
        && data[0] == 'c'
        && data[1] == 'r'
        && data[2] == 'e'
        && data[3] == 'a'
        && data[4] == 't'
        && data[5] == 'o'
        && data[6] == 'r'
        && data[7] == ':') {
        return true;
    }
    return processHeaderLine(data, size);
}

bool Parser::processHeaderLine(const char *data, size_t size)
{
    if (!size)
        return true;

    if (data[0] == '#')
        return true;

    if (data[0] == 'c'
        && size > 5
        && data[1] == 'm'
        && data[2] == 'd'
        && data[3] == ':'
        && data[4] == ' ') {
        assert(!m_profile.get());
        m_profile = auto_ptr<Profile>(new Profile());

        const size_t commandStartIndex = 5;
        assert(size > commandStartIndex);
        m_profile->setCommand(string(data + commandStartIndex, size - commandStartIndex));

        return true;
    }

    // FIXME: implement parsing for all the headers.
    for (size_t i = 0; i < size; ++i) {
        if (data[i] == ':')
            return true;
    }

    m_readingStage = Body;
    return processBodyLine(data, size);
}

static inline size_t extractFunctionId(const char *data, size_t *currentIndex, size_t size, bool *success)
{
    // Preconditions that must be ensured by the caller. This is a shortcut thanks to the condition (size >= 5)
    assert(size > *currentIndex);
    assert(size > (*currentIndex + 1));

    *success = false;

    if (data[*currentIndex] == '(') {
        const size_t initialCharacterIndex = *currentIndex + 1;
        assert(initialCharacterIndex < size);
        size_t endParenthesis = initialCharacterIndex;

        // Find the index of the closing parenthesis enclosing only number characters.
        size_t totalValue = 0;
        do {
            char currentChar = data[endParenthesis];
            // Function success condition
            if (currentChar == ')') {
                if (endParenthesis > initialCharacterIndex) {
                    *success = true;
                    *currentIndex = endParenthesis + 1;
                    return totalValue;
                }
                break;
            }

            char integerValue = currentChar - '0';
            if (integerValue < 10) {
                totalValue *= 10;
                totalValue += integerValue;
            } else
                break;

            ++endParenthesis;
        } while (endParenthesis < size);
    }
    return -1;
}

static inline string extractFunctionName(const char *data, size_t size, size_t currentIndex)
{
    // First, skip whitespaces.
    while (currentIndex < size && data[currentIndex] == ' ')
        ++currentIndex;

    // Any character left behind in this line is part of the function name.
    if (currentIndex < size) {
        string result = string((data + currentIndex), (size - currentIndex));
        assert(result.size() > 0);
        return result;
    }
    return string();
}

static string processBodyLineFunctionSymbol(const char *data, size_t size, IdToNameMapping *functionMapping)
{
    if (size < 5) // 5 = len("fn= n") || len("fn=()")
        return string();

    if (!(data[0] == 'f' && data[1] == 'n' && data[2] == '='))
        return string();

    size_t functionStringStartIndex = 3;
    bool functionHasCompressedId = false;
    size_t functionId = extractFunctionId(data, &functionStringStartIndex, size, &functionHasCompressedId);
    string functionName = extractFunctionName(data, size, functionStringStartIndex);

    if (functionHasCompressedId) {
        if (functionName.size())
            (*functionMapping)[functionId] = functionName;
        else
            functionName = (*functionMapping)[functionId];
    }

    assert(!!functionName.size());
    return functionName;
}

static inline string processBodyLineCalledFunctionSymbol(const char *data, size_t size, IdToNameMapping *functionMapping)
{
    assert(size >= 1);
    if (data[0] == 'c')
        return processBodyLineFunctionSymbol(data + 1, size - 1, functionMapping);
    return string();
}

bool Parser::processBodyLine(const char *data, size_t size)
{
    if (!size)
        return true;

    string functionName = processBodyLineFunctionSymbol(data, size, &m_functionMapping);
    if (functionName.size()) {
        m_profile->addFunction(functionName);
        return true;
    }
    processBodyLineCalledFunctionSymbol(data, size, &m_functionMapping);
    // FIXME: fully implement body parsing.
    return true;
}

}