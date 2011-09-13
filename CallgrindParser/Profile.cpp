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

#include "Profile.h"

#include "FunctionDescriptor.h"

namespace CallgrindParser
{

Profile::~Profile()
{
    const size_t vectorSize = functionDescriptorCount();
    for (size_t i = 0; i < vectorSize; ++i)
        delete functionDescriptorAt(i);
}

bool Profile::isValid() const
{
    return !!command().size();
}

FunctionDescriptor *Profile::addFunction(const string &name)
{
    FunctionDescriptor *newFunctionDescriptor = new FunctionDescriptor(name);
    m_functionDescriptors.push_back(newFunctionDescriptor);
    return newFunctionDescriptor;
}

}