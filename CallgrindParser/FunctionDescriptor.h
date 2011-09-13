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

#ifndef FunctionDescriptor_h
#define FunctionDescriptor_h

#include <string>

using namespace std;

/* The classes below are exported */
#pragma GCC visibility push(default)

namespace CallgrindParser {

class FunctionDescriptor
{
public:
    FunctionDescriptor(const string &name, const string &object, const string &file);
    const string &name() const { return m_name; }
    const string &object() const { return m_object; }
    const string &file() const { return m_file; }

private:
    string m_name;
    string m_object;
    string m_file;
};

}

#pragma GCC visibility pop

#endif /* FunctionDescriptor_h */
