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

#ifndef Parser_h
#define Parser_h

#include "Profile.h"

#include <memory>
#include <tr1/unordered_map>

/* The classes below are exported */
#pragma GCC visibility push(default)

namespace CallgrindParser
{

typedef tr1::unordered_map<size_t, string> IdToNameMapping;

class Parser
{
public:
    Parser();

    // Parse the line, and return true if parsing should continue.
    bool parseLine(const char *data, size_t size);

    auto_ptr<Profile>& profile();

private:
    bool processFormatVersionLine(const char *data, size_t size);
    bool processCreatorLine(const char *data, size_t size);
    bool processHeaderLine(const char *data, size_t size);
    bool processBodyLine(const char *data, size_t size);

    auto_ptr<Profile> m_profile;

    enum {
        FormatVersion,
        Creator,
        Header,
        Body,
    } m_readingStage;

    IdToNameMapping m_functionMapping;
    IdToNameMapping m_objectMapping;

    string m_objectContext;
};

}

#pragma GCC visibility pop

#endif /* Parser_h */
