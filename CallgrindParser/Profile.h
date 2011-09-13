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

#ifndef Profile_h
#define Profile_h

#include <cassert>
#include <string>
#include <vector>

using namespace std;

#pragma GCC visibility push(default)

namespace CallgrindParser
{

class FunctionDescriptor;

class Profile
{
public:
    ~Profile();

    bool isValid() const;

    const string &command() const { return m_command; };
    void setCommand(const string &command) { m_command = command; }

    FunctionDescriptor *addFunction(const string &name, const string &object, const string &file);
    size_t functionDescriptorCount() const { return m_functionDescriptors.size(); }
    FunctionDescriptor *functionDescriptorAt(size_t index) { assert(index < functionDescriptorCount()); return m_functionDescriptors.at(index); }

private:
    string m_command;
    vector<FunctionDescriptor*> m_functionDescriptors;
};

}

#pragma GCC visibility pop

#endif /* Profile_h */
